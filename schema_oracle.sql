-- =========================================================
-- Sitanagri Mart - Oracle Database Schema & Seed Data Script
-- =========================================================

-- 1. Table: employees
CREATE TABLE employees (
    empid VARCHAR2(50) PRIMARY KEY,
    empname VARCHAR2(100) NOT NULL,
    job VARCHAR2(50) NOT NULL,
    salary NUMBER(10,2) NOT NULL
);

-- 2. Table: users
CREATE TABLE users (
    userid VARCHAR2(50) PRIMARY KEY,
    empid VARCHAR2(50) NOT NULL,
    password VARCHAR2(255) NOT NULL, -- stores a PBKDF2 hash (see PasswordUtil.java), not plain text
    usertype VARCHAR2(50) NOT NULL,
    username VARCHAR2(100) NOT NULL,
    CONSTRAINT fk_users_emp FOREIGN KEY (empid) REFERENCES employees(empid) ON DELETE CASCADE
);

-- 3. Table: products
CREATE TABLE products (
    p_id VARCHAR2(50) PRIMARY KEY,
    p_name VARCHAR2(100) NOT NULL,
    p_companyname VARCHAR2(100) NOT NULL,
    p_price NUMBER(10,2) NOT NULL,
    our_price NUMBER(10,2) NOT NULL,
    p_tax NUMBER(3) NOT NULL,
    quantity NUMBER(6) NOT NULL,
    status CHAR(1) DEFAULT 'Y'
);

-- 4. Table: orders
CREATE TABLE orders (
    order_id VARCHAR2(50) NOT NULL,
    p_id VARCHAR2(50) NOT NULL,
    quantity NUMBER(6) NOT NULL,
    userid VARCHAR2(50) NOT NULL,
    CONSTRAINT pk_orders PRIMARY KEY (order_id, p_id),
    CONSTRAINT fk_orders_prod FOREIGN KEY (p_id) REFERENCES products(p_id),
    CONSTRAINT fk_orders_user FOREIGN KEY (userid) REFERENCES users(userid)
);

-- Sample Data
INSERT INTO employees VALUES ('E101', 'Admin Manager', 'Manager', 65000.00);
INSERT INTO employees VALUES ('E102', 'John Doe', 'Receptionist', 35000.00);

INSERT INTO users VALUES ('M101', 'E101', 'admin', 'Manager', 'Admin Manager');
INSERT INTO users VALUES ('R101', 'E102', 'receptionist', 'Receptionist', 'John Doe');

INSERT INTO products VALUES ('P101', 'Amul Milk 1L', 'Amul', 66.00, 62.00, 0, 100, 'Y');
INSERT INTO products VALUES ('P102', 'Fortune Rice 5kg', 'Fortune', 450.00, 399.00, 5, 50, 'Y');
INSERT INTO products VALUES ('P103', 'Tata Salt 1kg', 'Tata', 28.00, 25.00, 0, 200, 'Y');

COMMIT;

-- =========================================================
-- NEWLY ADDED: Payment & Billing System (Order Header + Payments)
-- =========================================================

-- 5. Table: order_master (NEW)
CREATE TABLE order_master (
    order_id       VARCHAR2(50) PRIMARY KEY,
    userid         VARCHAR2(50) NOT NULL,
    subtotal       NUMBER(12,2) NOT NULL,
    tax            NUMBER(12,2) NOT NULL,
    discount       NUMBER(12,2) DEFAULT 0 NOT NULL,
    grand_total    NUMBER(12,2) NOT NULL,
    order_date     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_status VARCHAR2(30) DEFAULT 'PENDING' NOT NULL,
    CONSTRAINT fk_order_master_user FOREIGN KEY (userid) REFERENCES users(userid)
);

-- 6. Table: payments (NEW)
CREATE TABLE payments (
    payment_id      VARCHAR2(50) PRIMARY KEY,
    order_id        VARCHAR2(50) NOT NULL,
    payment_method  VARCHAR2(30) NOT NULL,
    amount          NUMBER(12,2) NOT NULL,
    transaction_ref VARCHAR2(100),
    payment_status  VARCHAR2(30) NOT NULL,
    payment_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES order_master(order_id)
);

-- 6b. Table: returns (NEW) - returns/refunds against a previous order
CREATE TABLE returns (
    return_id      VARCHAR2(50) PRIMARY KEY,
    order_id       VARCHAR2(50) NOT NULL,
    p_id           VARCHAR2(50) NOT NULL,
    quantity       NUMBER(6) NOT NULL,
    reason         VARCHAR2(255),
    refund_amount  NUMBER(12,2) NOT NULL,
    return_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_by   VARCHAR2(50) NOT NULL,
    CONSTRAINT fk_returns_order FOREIGN KEY (order_id) REFERENCES order_master(order_id),
    CONSTRAINT fk_returns_prod FOREIGN KEY (p_id) REFERENCES products(p_id),
    CONSTRAINT fk_returns_user FOREIGN KEY (processed_by) REFERENCES users(userid)
);

-- 7. Backfill order_master rows for any pre-existing orders so the new
--    FK relationship between orders.order_id and order_master.order_id
--    remains valid for historical data.
INSERT INTO order_master (order_id, userid, subtotal, tax, discount, grand_total, payment_status)
SELECT o.order_id,
       MIN(o.userid),
       NVL(SUM(p.our_price * o.quantity), 0),
       NVL(SUM(p.our_price * o.quantity * p.p_tax / 100), 0),
       0,
       NVL(SUM(p.our_price * o.quantity * (1 + p.p_tax / 100)), 0),
       'LEGACY'
FROM orders o
JOIN products p ON p.p_id = o.p_id
WHERE o.order_id NOT IN (SELECT order_id FROM order_master)
GROUP BY o.order_id;

-- 8. Enforce referential integrity going forward (run after backfill):
-- ALTER TABLE orders ADD CONSTRAINT fk_orders_order_master
--     FOREIGN KEY (order_id) REFERENCES order_master(order_id);

COMMIT;
