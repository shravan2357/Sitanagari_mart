-- =========================================================
-- Sitanagri Mart - MySQL Database Schema & Seed Data Script
-- =========================================================

CREATE DATABASE IF NOT EXISTS sitanagri_mart;
USE sitanagri_mart;

-- 1. Table: employees
CREATE TABLE IF NOT EXISTS employees (
    empid VARCHAR(50) PRIMARY KEY,
    empname VARCHAR(100) NOT NULL,
    job VARCHAR(50) NOT NULL,
    salary DOUBLE PRECISION NOT NULL
);

-- 2. Table: users
CREATE TABLE IF NOT EXISTS users (
    userid VARCHAR(50) PRIMARY KEY,
    empid VARCHAR(50) NOT NULL,
    password VARCHAR(255) NOT NULL, -- stores a PBKDF2 hash (see PasswordUtil.java), not plain text
    usertype VARCHAR(50) NOT NULL,
    username VARCHAR(100) NOT NULL,
    FOREIGN KEY (empid) REFERENCES employees(empid) ON DELETE CASCADE
);

-- 3. Table: products
CREATE TABLE IF NOT EXISTS products (
    p_id VARCHAR(50) PRIMARY KEY,
    p_name VARCHAR(100) NOT NULL,
    p_companyname VARCHAR(100) NOT NULL,
    p_price DECIMAL(10,2) NOT NULL,
    our_price DECIMAL(10,2) NOT NULL,
    p_tax INT NOT NULL,
    quantity INT NOT NULL,
    status CHAR(1) DEFAULT 'Y'
);

-- 4. Table: orders
CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(50) NOT NULL,
    p_id VARCHAR(50) NOT NULL,
    quantity INT NOT NULL,
    userid VARCHAR(50) NOT NULL,
    PRIMARY KEY (order_id, p_id),
    FOREIGN KEY (p_id) REFERENCES products(p_id),
    FOREIGN KEY (userid) REFERENCES users(userid)
);

-- =========================================================
-- Initial Seed Data
-- =========================================================

-- Sample Employees
INSERT INTO employees (empid, empname, job, salary) VALUES
('E101', 'Admin Manager', 'Manager', 65000.00),
('E102', 'John Doe', 'Receptionist', 35000.00),
('E103', 'Jane Smith', 'Receptionist', 32000.00)
ON DUPLICATE KEY UPDATE empname=VALUES(empname);

-- Sample Users (Login Credentials)
-- Manager: User ID = M101, Password = admin
-- Receptionist: User ID = R101, Password = receptionist
-- NOTE: these seed passwords are intentionally stored in plain text so
-- you can log in immediately. UserDao automatically re-hashes each
-- account's password (PBKDF2, see PasswordUtil.java) the first time it
-- logs in successfully - nothing to do manually.
INSERT INTO users (userid, empid, password, usertype, username) VALUES
('M101', 'E101', 'admin', 'Manager', 'Admin Manager'),
('R101', 'E102', 'receptionist', 'Receptionist', 'John Doe')
ON DUPLICATE KEY UPDATE username=VALUES(username);

-- Sample Products (Grocery Items)
INSERT INTO products (p_id, p_name, p_companyname, p_price, our_price, p_tax, quantity, status) VALUES
('P101', 'Amul Milk 1L', 'Amul', 66.00, 62.00, 0, 100, 'Y'),
('P102', 'Fortune Basmati Rice 5kg', 'Fortune', 450.00, 399.00, 5, 50, 'Y'),
('P103', 'Tata Salt 1kg', 'Tata', 28.00, 25.00, 0, 200, 'Y'),
('P104', 'Aashirvaad Atta 10kg', 'ITC', 420.00, 385.00, 5, 80, 'Y'),
('P105', 'Cadbury Dairy Milk 100g', 'Mondelez', 100.00, 90.00, 18, 150, 'Y')
ON DUPLICATE KEY UPDATE p_name=VALUES(p_name);

COMMIT;

-- =========================================================
-- NEWLY ADDED: Payment & Billing System (Order Header + Payments)
-- =========================================================

-- 5. Table: order_master  (NEW)
-- Header/summary row for every order: one row per order_id holding
-- subtotal / tax / discount / grand total / payment status.
-- The existing `orders` table continues to hold the per-product line
-- items (order_id, p_id, quantity, userid) exactly as before.
CREATE TABLE IF NOT EXISTS order_master (
    order_id       VARCHAR(50) PRIMARY KEY,
    userid         VARCHAR(50) NOT NULL,
    subtotal       DECIMAL(12,2) NOT NULL,
    tax            DECIMAL(12,2) NOT NULL,
    discount       DECIMAL(12,2) NOT NULL DEFAULT 0,
    grand_total    DECIMAL(12,2) NOT NULL,
    order_date     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    FOREIGN KEY (userid) REFERENCES users(userid)
);

-- 6. Table: payments  (NEW)
CREATE TABLE IF NOT EXISTS payments (
    payment_id      VARCHAR(50) PRIMARY KEY,
    order_id        VARCHAR(50) NOT NULL,
    payment_method  VARCHAR(30) NOT NULL,
    amount          DECIMAL(12,2) NOT NULL,
    transaction_ref VARCHAR(100),
    payment_status  VARCHAR(30) NOT NULL,
    payment_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES order_master(order_id)
);

-- 6b. Table: returns  (NEW) - returns/refunds against a previous order
CREATE TABLE IF NOT EXISTS returns (
    return_id      VARCHAR(50) PRIMARY KEY,
    order_id       VARCHAR(50) NOT NULL,
    p_id           VARCHAR(50) NOT NULL,
    quantity       INT NOT NULL,
    reason         VARCHAR(255),
    refund_amount  DECIMAL(12,2) NOT NULL,
    return_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_by   VARCHAR(50) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES order_master(order_id),
    FOREIGN KEY (p_id) REFERENCES products(p_id),
    FOREIGN KEY (processed_by) REFERENCES users(userid)
);

-- 7. Backfill: create an order_master row for any order that was placed
--    by the OLD billing flow (direct insert into `orders`, no payment
--    record) BEFORE this upgrade, so the new foreign key relationship
--    between `orders.order_id` and `order_master.order_id` stays valid.
--    Subtotal/tax/discount are approximated from the existing product
--    prices since no historical breakdown was stored previously.
INSERT INTO order_master (order_id, userid, subtotal, tax, discount, grand_total, payment_status)
SELECT o.order_id,
       MIN(o.userid) AS userid,
       COALESCE(SUM(p.our_price * o.quantity), 0) AS subtotal,
       COALESCE(SUM(p.our_price * o.quantity * p.p_tax / 100), 0) AS tax,
       0 AS discount,
       COALESCE(SUM(p.our_price * o.quantity * (1 + p.p_tax / 100.0)), 0) AS grand_total,
       'LEGACY' AS payment_status
FROM orders o
JOIN products p ON p.p_id = o.p_id
WHERE o.order_id NOT IN (SELECT order_id FROM order_master)
GROUP BY o.order_id;

-- 8. Now that every existing order_id has a matching order_master row,
--    it is safe to enforce referential integrity going forward.
--    (Run manually if your MySQL version does not support
--     "ADD CONSTRAINT IF NOT EXISTS" — guard with a check first.)
-- ALTER TABLE orders
--     ADD CONSTRAINT fk_orders_order_master FOREIGN KEY (order_id) REFERENCES order_master(order_id);

COMMIT;
