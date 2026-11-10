# Entity-Relationship Diagram (ERD)

This document explains the data model for the Banking System Database Project.

## 1. Tables at a glance

| Table | Purpose | Primary Key |
|-------|---------|-------------|
| `BRANCHES` | Physical bank locations | `branch_id` |
| `EMPLOYEES` | Staff who work at a branch | `employee_id` |
| `CUSTOMERS` | People who bank with us | `customer_id` |
| `ACCOUNTS` | Accounts owned by customers | `account_id` |
| `CARDS` | Debit/credit cards tied to an account | `card_id` |
| `LOANS` | Loans granted to customers | `loan_id` |
| `TRANSACTIONS` | Money-movement ledger | `transaction_id` |
| `AUDIT_LOGS` | Immutable audit trail (written by triggers) | `log_id` |

## 2. Relationships (cardinality)

```
BRANCHES (1) ───< (M) EMPLOYEES        a branch employs many staff
BRANCHES (1) ───< (M) CUSTOMERS        a branch serves many customers
CUSTOMERS (1) ───< (M) ACCOUNTS        a customer can own many accounts
CUSTOMERS (1) ───< (M) LOANS           a customer can hold many loans
ACCOUNTS (1) ───< (M) CARDS            an account can have many cards
ACCOUNTS (1) ───< (M) TRANSACTIONS     an account has many transactions
ACCOUNTS (1) ───< (M) TRANSACTIONS     (related_account_id, for transfers)
```

- `<` means "one-to-many" (the crow's-foot side is the *many* side).
- `TRANSACTIONS` references `ACCOUNTS` twice: once for the owning account
  (`account_id`) and once for the other side of a transfer
  (`related_account_id`, which is nullable for plain deposits/withdrawals).
- `AUDIT_LOGS` has no foreign keys on purpose — it is a write-once trail that
  must survive even if the referenced row is later deleted.

## 3. Text ERD

```
              +------------+
              |  BRANCHES  |
              +------------+
              | branch_id  |PK
              +------------+
                 ^      ^
                 |      |
        +--------+      +---------+
        |                         |
+---------------+          +--------------+
|  EMPLOYEES    |          |  CUSTOMERS   |
+---------------+          +--------------+
| employee_id PK|          | customer_id PK|
| branch_id   FK|          | national_id U |
+---------------+          | branch_id   FK|
                           +--------------+
                              ^        ^
                              |        |
                   +----------+        +-----------+
                   |                               |
            +--------------+                 +-----------+
            |   ACCOUNTS   |                 |   LOANS   |
            +--------------+                 +-----------+
            | account_id PK|                 | loan_id PK|
            | customer_id FK|                | customer_id FK|
            | account_no  U|                 +-----------+
            +--------------+
               ^        ^
               |        |
       +-------+        +--------+
       |                         |
+--------------+        +------------------+
|    CARDS     |        |  TRANSACTIONS    |
+--------------+        +------------------+
| card_id    PK|        | transaction_id PK|
| account_id FK|        | account_id     FK|
| card_no     U|        | related_acct   FK|
+--------------+        +------------------+

+----------------+
|   AUDIT_LOGS   |  (no FK; populated by triggers on
+----------------+   CUSTOMERS, ACCOUNTS, TRANSACTIONS)
| log_id       PK|
+----------------+

PK = primary key   FK = foreign key   U = unique
```

## 4. Foreign-key summary

| Child table | Column | References |
|-------------|--------|------------|
| `EMPLOYEES` | `branch_id` | `BRANCHES(branch_id)` |
| `CUSTOMERS` | `branch_id` | `BRANCHES(branch_id)` |
| `ACCOUNTS` | `customer_id` | `CUSTOMERS(customer_id)` |
| `CARDS` | `account_id` | `ACCOUNTS(account_id)` |
| `LOANS` | `customer_id` | `CUSTOMERS(customer_id)` |
| `TRANSACTIONS` | `account_id` | `ACCOUNTS(account_id)` |
| `TRANSACTIONS` | `related_account_id` | `ACCOUNTS(account_id)` |

## 5. Key constraints that enforce business rules

- `accounts.balance >= 0` — the database itself refuses to let an account go
  negative, a second line of defence behind the withdrawal procedure.
- `transactions.amount > 0` — every ledger entry is a positive amount; the
  `transaction_type` column records the direction.
- `CHECK (... IN (...))` lists keep `account_type`, `status`, `card_type`,
  `loan_type` and `transaction_type` to a controlled vocabulary.
- `UNIQUE` on `national_id`, `email`, `account_number`, `card_number` prevents
  duplicates.

## 6. How to generate a visual ERD in SQL Developer

1. Connect to the schema after running `run_all.sql`.
2. Menu: **File → Data Modeler → Import → Data Dictionary**.
3. Pick your connection, select the 8 tables, and finish.
4. SQL Developer draws the diagram automatically; export it as PNG and add it
   to this folder as `erd.png` for your GitHub README.
