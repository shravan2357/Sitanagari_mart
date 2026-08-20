# Sitanagri Mart — Desktop POS & Management System

A Java Swing desktop application for managing grocery store operations including inventory, employees, receptionists, and billing.

---

##  Quick Start

### 1. Prerequisites

| Requirement | Version |
|---|---|
| Java JDK | 17+ |
| MySQL Server | 8.0+ |
| MySQL Connector | included in `lib/` |

### 2. Set Up the Database

1. Open MySQL and run the schema:
   ```sql
   SOURCE schema_mysql.sql;
   ```

2. Default credentials created:
   - **Manager:** `M101` / `admin`
   - **Receptionist:** `R101` / `receptionist`

### 3. Configure Database Connection

Edit `config.properties` (or `.env`) with your MySQL credentials:

```properties
DB_TYPE=mysql
DB_HOST=localhost
DB_PORT=3306
DB_NAME=sitanagri_mart
DB_USER=root
DB_PASSWORD=root
```

### 4. Build & Run

```bat
build.bat    # Compile all Java sources → out/
run.bat      # Launch the application
```

---

## 📁 Project Structure

```
Sitanagri_mart/
├── src/
│   └── jmart/
│       ├── gui/               # All Swing GUI frames
│       │   ├── UIStyleHelper.java    ← Design system (Sitanagri theme)
│       │   ├── SplashScreenFrame.java
│       │   ├── LoginFrame.java
│       │   ├── ManagerOptionsFrame.java
│       │   ├── ReceptionistOptionsFrame.java
│       │   ├── BillingFrame.java
│       │   ├── AddStocksFrame.java
│       │   ├── UpdateStockFrame.java
│       │   ├── DeleteStockFrame.java
│       │   ├── ViewStockFrame.java
│       │   ├── ManageStockFrame.java
│       │   ├── AddEmployeeFrame.java
│       │   ├── UpdateEmployeeFrame.java
│       │   ├── RemoveEmployeeFrame.java
│       │   ├── ViewEmployeeFrame.java
│       │   ├── ManageEmployeeFrame.java
│       │   ├── AddReceptionistFrame.java
│       │   ├── UpdateReceptionistFrame.java
│       │   ├── RemoveReceptionistFrame.java
│       │   ├── ViewReceptionistFrame.java
│       │   ├── ManageReceptionistFrame.java
│       │   ├── ViewOrderFrame.java
│       │   ├── ViewOrderReceptionistFrame.java
│       │   ├── PaymentFrame.java      ← NEW: Cash / UPI / Card payment screen
│       │   └── InvoiceFrame.java      ← NEW: printable / PDF invoice viewer
│       ├── dao/               # Data Access Objects
│       ├── pojo/              # Plain Old Java Objects
│       └── dbutil/
│           └── DBConnection.java  ← Dynamic DB config loader
├── lib/
│   ├── mysql-connector-j-8.3.0.jar
│   ├── barcode4j-2.1.jar
│   └── sqlite-jdbc-3.45.1.0.jar
├── schema_mysql.sql           # MySQL database schema + seed data
├── schema_oracle.sql          # Oracle database schema + seed data
├── config.properties          # Database configuration
├── .env                       # Alternative environment config
├── build.bat                  # Build script
└── run.bat                    # Run script
```

---

## 🎨 UI Theme (Sitanagri Mart)

All frames use the unified `UIStyleHelper` design system:

| Token | Color | Usage |
|---|---|---|
| Primary | `#059669` Emerald Green | Buttons, accents |
| Background | `#0F172A` Deep Slate | Main panels |
| Surface | `#1E293B` Slate | Card panels |
| Text | `#F8FAFC` Light | Labels, headings |
| Danger | `#DC2626` Red | Logout, delete |

---

## 👥 User Roles

| Role | Login | Capabilities |
|---|---|---|
| Manager | `M101` / `admin` | Full access: employees, stock, receptionists, orders |
| Receptionist | `R101` / `receptionist` | Billing, view stock, view own orders |

---

## 🆙 Reliability & Feature Upgrades (Round 2)

On top of the payment system above, this round adds:

| Area | What changed |
|---|---|
| **Money math** | New `MoneyUtil` (BigDecimal-based) replaces plain `double` for all billing/payment/return calculations — eliminates floating-point rounding drift on multi-item bills. `order_master`, `payments`, `returns`, and `products` price columns are now `DECIMAL`/`NUMBER`, not `DOUBLE`. |
| **Connection pooling** | New dependency-free `ConnectionPool` (`jmart.dbutil`) replaces the old single shared `Connection`. Every DAO method now borrows/releases a pooled connection (`DBConnection.getConnection()` / `releaseConnection()`), so concurrent billing, reporting, and returns no longer fight over one connection. |
| **Password security** | New `PasswordUtil` hashes passwords with PBKDF2WithHmacSHA256 (120k iterations, per-user salt) instead of storing plain text. Existing plain-text accounts (seed data: `M101`/`admin`, `R101`/`receptionist`) log in exactly as before and are **transparently upgraded** to a proper hash the first time they log in successfully — nothing to migrate by hand. |
| **Returns / Refunds** | New `ReturnFrame` (Manager + Receptionist dashboards → "Returns / Refunds") lets you look up an order, pick a line item, and process a return. `ReturnDao#processReturn` runs one atomic transaction: insert the return record, restock the product, and mark the order/payment `PARTIALLY_REFUNDED` or `REFUNDED`. Over-returning is rejected. New `returns` table in the schema. |
| **Low-stock alerts** | The Manager dashboard now checks stock on open and pops up a warning listing every product at or below `ProductDao.DEFAULT_LOW_STOCK_THRESHOLD` (10 units). |
| **Barcode scanner support** | `BillingFrame`'s Product Id field already worked with any USB/keyboard-emulating barcode scanner (scan → types code → Enter). It now also accepts `QTY*PRODUCTID` (e.g. `3*P101`) to add several units in a single scan. |
| **Sales reports** | New `ReportsFrame` (Manager dashboard → "Sales Reports") shows a daily orders/subtotal/tax/discount/grand-total summary for any date, plus an all-time top-10 selling products table, backed by `ReportDao`. |

> **Note:** `ManagerOptionsFrame.form` and `ReceptionistOptionsFrame.form` were removed (same reason as the frames listed in the payment-system note below — new buttons were added by hand). `ReturnFrame` and `ReportsFrame` are new plain-Swing frames with no `.form` file.

**Known, documented simplification:** a return's refund amount is calculated as `unit price × qty × (1 + tax%)` and does not re-prorate any order-level discount across the returned item — acceptable for this project's scope, called out in `ReturnFrame`'s code comments if you want to refine it further.

---

## 🗄️ Database Tables

| Table | Description |
|---|---|
| `employees` | Staff records (ID, name, job, salary) |
| `users` | Login credentials (manager + receptionists) — `password` now stores a PBKDF2 hash |
| `products` | Inventory (ID, name, company, price, tax, qty) |
| `orders` | Per-product line items for an order (order_id, p_id, quantity, userid) |
| `order_master` | One row per order: subtotal, tax, discount, grand total, date, payment status |
| `payments` | One row per order: payment method, amount, transaction reference, payment status |
| `returns` **(NEW)** | One row per returned line item: quantity, reason, refund amount, who processed it |

---

## 💳 Payment & Billing System (NEW)

`BillingFrame` no longer finalizes an order directly. Clicking **Generate
Bill** validates the cart + discount and opens **`PaymentFrame`**, where the
cashier picks **Cash / UPI / Credit Card / Debit Card** and confirms the
amount. Only once payment is confirmed does `OrderMasterDao.processPayment(...)`
run a **single JDBC transaction** (`conn.setAutoCommit(false)` ... `commit()` /
`rollback()`) that:

1. Re-validates stock (protects against a race between adding to the cart and paying)
2. Inserts the `order_master` header row
3. Inserts the `orders` line items (existing table, unchanged)
4. Reduces `products.quantity` (guarded so it can never go negative)
5. Inserts the `payments` row

If any step fails, everything is rolled back — there is never a payment
without an order, an order without a stock update, or a stock update
without a payment. After a successful payment, **`InvoiceFrame`** displays
the formatted ₹ invoice with **Print Bill** (via `java.awt.print`) and
**Save Bill as PDF** (a small dependency-free, hand-written single-page PDF
writer in `InvoiceGenerator` — no PDF library was added since this project
ships only `mysql-connector`, `sqlite-jdbc` and `barcode4j`, and this build
environment has no Maven Central access to fetch a new one).

`ViewOrderFrame` (Manager) and `ViewOrderReceptionistFrame` (Receptionist)
now list every order's full summary (date, cashier, subtotal, tax,
discount, grand total, payment method/status, transaction ID) and let you
re-open any past invoice with **View Bill** / **Print Bill**.

> **Note:** `BillingFrame.form`, `ViewOrderFrame.form` and
> `ViewOrderReceptionistFrame.form` were removed because these frames'
> UIs were substantially extended (discount field, running totals,
> order-summary table, etc.) beyond what a quick NetBeans GUI-Builder edit
> could keep in sync — the `.java` files are now maintained by hand as
> plain Swing code. `PaymentFrame` and `InvoiceFrame` are new plain-Swing
> frames with no `.form` file. All other existing frames/forms are
> untouched.

---

## 🔧 Build & Run Commands (Manual)

```bat
:: Compile
javac -cp "lib/*;src" -d out src/jmart/pojo/*.java src/jmart/dbutil/*.java src/jmart/dao/*.java src/jmart/gui/*.java

:: Run
java -cp "out;lib/*" jmart.gui.SplashScreenFrame
```

---

## 📦 Dependencies

| Library | Purpose | Source |
|---|---|---|
| `mysql-connector-j-8.3.0.jar` | MySQL JDBC driver | Maven Central |
| `barcode4j-2.1.jar` | Barcode generation for billing | SourceForge |
| `sqlite-jdbc-3.45.1.0.jar` | SQLite fallback | GitHub |

---

*Sitanagri Mart — Grocery Management System*
