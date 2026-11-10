# 🏦 Banking System Database (Oracle SQL / PL/SQL)

A relational database project that simulates a retail
bank, built with **Oracle Database** and **Oracle SQL Developer**. It goes well
beyond basic CRUD to demonstrate real database engineering: ACID transactions,
audit triggers, stored procedures, concurrency control, and advanced reporting
queries.

> **Note:** This is a **personal / academic, simulated project** built for
> learning and portfolio purposes. It is not real company work and uses no real
> customer data.

---

## ✨ Features

- **8-table normalized schema** — branches, employees, customers, accounts,
  cards, loans, transactions, audit logs.
- **Full integrity constraints** — primary/foreign keys, `NOT NULL`, `UNIQUE`,
  `CHECK`, `DEFAULT`.
- **PL/SQL stored procedures** for the core banking operations (create customer,
  open account, deposit, withdraw, transfer, view balance/history).
- **ACID transactions** — `COMMIT`, `ROLLBACK`, and `SAVEPOINT` used correctly,
  with row-level locking (`FOR UPDATE`) and deadlock-safe lock ordering.
- **Audit logging via triggers** — every insert/update/delete on the key tables
  is recorded automatically in an append-only audit trail.
- **Robust error handling** — PL/SQL exceptions and custom application errors.
- **Advanced SQL** — joins, sub-queries, `GROUP BY ... HAVING`, aggregation,
  and window functions (`RANK`, running totals), plus a reusable view.

---

## 🗂️ Project structure

```
banking-system-database/
├── README.md                     ← you are here
├── run_all.sql                   ← one-click build (drops, creates, seeds)
├── .gitignore
├── sql/
│   ├── 01_drop_tables.sql        ← safe re-runnable teardown
│   ├── 02_create_tables.sql      ← schema: tables, sequence, indexes
│   ├── 03_insert_sample_data.sql ← realistic seed data + COMMIT
│   ├── 04_triggers.sql           ← audit-logging triggers
│   ├── 05_procedures.sql         ← PL/SQL procedures & function
│   ├── 06_test_procedures.sql    ← tests + ACID / exception demos
│   └── 07_advanced_queries.sql   ← reporting & analytics queries + a view
├── livesql/                      ← the same build split into 3 scripts for Oracle Live SQL
│   ├── 1_setup.sql
│   ├── 2_tests.sql
│   └── 3_reports.sql
├── advanced/
│   └── banking_pkg_live_sql.sql  ← separate self-contained script (see below)
└── docs/
    ├── ERD.md                    ← entity-relationship diagram & explanation
    ├── erd.png
    └── erd.svg
```

---

## 🚀 How to run it

You need an Oracle database to connect to. Pick **one** of these:

### Option A — Oracle Database XE (local, recommended)
1. Install **Oracle Database 21c Express Edition (XE)** — it's free.
2. Install **Oracle SQL Developer**.
3. Create a connection (default service name is usually `XEPDB1`):
   - Host `localhost`, Port `1521`, Service name `XEPDB1`,
     user `system` (or a user you create) and your password.

### Option B — Oracle Live SQL (browser, no install)
1. Go to **https://livesql.oracle.com** and sign in with a free Oracle account.
2. Paste the contents of each `sql/0X_*.sql` file into the SQL worksheet **in
   numeric order** and run them. *(Live SQL ignores `SET SERVEROUTPUT`/`PROMPT`
   lines and runs one session, so just run files 01 → 07 in order. The
   `@@`-based `run_all.sql` only works in SQL Developer / SQLcl, not Live SQL.)*

### Then build the database

**In SQL Developer:** open `run_all.sql` and click **Run Script (F5)** — not
"Run Statement (Ctrl+Enter)", because F5 understands the `/` terminators and
`@@` includes. This drops, creates, seeds, and compiles everything.

Then, to see it in action:
1. Run `sql/06_test_procedures.sql` with **`SET SERVEROUTPUT ON`** (it's already
   in the file) to watch deposits, withdrawals, transfers, and the ACID demos.
2. Run `sql/07_advanced_queries.sql` to see the reports and analytics.

**From the command line (SQLcl / SQL*Plus):**
```bash
sql username/password@//localhost:1521/XEPDB1 @run_all.sql
```

---

## 🧠 What makes this more than CRUD

| Concept | Where to look |
|---------|---------------|
| Atomic money transfer (debit + credit or nothing) | `sp_transfer` in `05_procedures.sql` |
| `SAVEPOINT` + partial rollback | `sp_transfer`, and Test 7 in `06_test_procedures.sql` |
| Concurrency / deadlock-safe locking | `SELECT ... FOR UPDATE` with ordered locking in `sp_transfer` |
| Audit trail you can't bypass | triggers in `04_triggers.sql` → `AUDIT_LOGS` |
| Defence in depth on integrity | `CHECK (balance >= 0)` **and** procedural checks |
| Analytics | window functions in `07_advanced_queries.sql` |

---

## 📦 Separate script: `advanced/banking_pkg_live_sql.sql`

A second, **self-contained** script written for Oracle Live SQL. It builds its
own smaller schema (customers, accounts, transactions, audit log, error log) —
it does **not** extend the 8-table schema above — and demonstrates:

- business logic packaged in a PL/SQL package (`BANKING_PKG`)
- error logging with `PRAGMA AUTONOMOUS_TRANSACTION`, so errors are kept even
  when the main transaction rolls back
- an optimistic `VERSION_NUMBER` column maintained by a trigger

Paste the whole file into a Live SQL worksheet and run it.

---

## 🗺️ Data model

See **[docs/ERD.md](docs/ERD.md)** for the full entity-relationship diagram,
cardinalities, and foreign-key map. In short:

- A **branch** has many **employees** and many **customers**.
- A **customer** owns many **accounts** and may hold many **loans**.
- An **account** has many **cards** and many **transactions**.
- **Transactions** reference accounts twice (owner + transfer counterparty).
- **Audit logs** are written automatically by triggers.

---

## 🛠️ Tech stack

- **Oracle Database 21c Express Edition (XE)**
- **Oracle SQL Developer**
- **SQL** and **PL/SQL**

---

## 📄 License & disclaimer

Personal/academic project for educational and portfolio use. All data is
fictional. Free to reuse and learn from.
