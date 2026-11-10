-- ============================================================================
-- File   : 07_advanced_queries.sql
-- Purpose: Reporting and analytics queries that demonstrate advanced Oracle
--          SQL: JOIN, GROUP BY, HAVING, sub-queries, aggregation, ORDER BY,
--          analytic/window functions, and a reusable VIEW.
-- Engine : Oracle Database (Oracle XE 21c / SQL Developer)
-- Tip    : Run each query individually, or run the whole file as a script.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Q1. Every account with its owner and branch (multi-table INNER JOIN).
-- ----------------------------------------------------------------------------
PROMPT === Q1: accounts with customer and branch ===
SELECT a.account_number,
       c.full_name        AS customer,
       b.branch_name,
       a.account_type,
       a.balance
FROM   accounts a
JOIN   customers c ON c.customer_id = a.customer_id
JOIN   branches  b ON b.branch_id   = c.branch_id
ORDER  BY a.balance DESC;

-- ----------------------------------------------------------------------------
-- Q2. Total balance held per customer (GROUP BY + aggregation + ORDER BY).
-- ----------------------------------------------------------------------------
PROMPT === Q2: total balance per customer ===
SELECT c.customer_id,
       c.full_name,
       COUNT(a.account_id)        AS num_accounts,
       NVL(SUM(a.balance), 0)     AS total_balance
FROM   customers c
LEFT   JOIN accounts a ON a.customer_id = c.customer_id
GROUP  BY c.customer_id, c.full_name
ORDER  BY total_balance DESC;

-- ----------------------------------------------------------------------------
-- Q3. Customers whose combined balance exceeds 10,000 (GROUP BY + HAVING).
-- ----------------------------------------------------------------------------
PROMPT === Q3: high-value customers (combined balance > 10000) ===
SELECT c.full_name,
       SUM(a.balance) AS total_balance
FROM   customers c
JOIN   accounts a ON a.customer_id = c.customer_id
GROUP  BY c.full_name
HAVING SUM(a.balance) > 10000
ORDER  BY total_balance DESC;

-- ----------------------------------------------------------------------------
-- Q4. Accounts whose balance is above the overall average (scalar sub-query).
-- ----------------------------------------------------------------------------
PROMPT === Q4: accounts above the average balance ===
SELECT account_number, account_type, balance
FROM   accounts
WHERE  balance > (SELECT AVG(balance) FROM accounts)
ORDER  BY balance DESC;

-- ----------------------------------------------------------------------------
-- Q5. Deposit/withdrawal/transfer totals per transaction type
--     (aggregation with COUNT, SUM, MIN, MAX, AVG).
-- ----------------------------------------------------------------------------
PROMPT === Q5: transaction summary by type ===
SELECT transaction_type,
       COUNT(*)        AS txn_count,
       SUM(amount)     AS total_amount,
       MIN(amount)     AS min_amount,
       MAX(amount)     AS max_amount,
       ROUND(AVG(amount), 2) AS avg_amount
FROM   transactions
GROUP  BY transaction_type
ORDER  BY total_amount DESC;

-- ----------------------------------------------------------------------------
-- Q6. Customers who have NEVER made a withdrawal (NOT IN sub-query).
-- ----------------------------------------------------------------------------
PROMPT === Q6: customers with no withdrawals ===
SELECT c.customer_id, c.full_name
FROM   customers c
WHERE  c.customer_id NOT IN (
           SELECT a.customer_id
           FROM   accounts a
           JOIN   transactions t ON t.account_id = a.account_id
           WHERE  t.transaction_type = 'WITHDRAWAL'
       )
ORDER  BY c.customer_id;

-- ----------------------------------------------------------------------------
-- Q7. Customers who hold a loan (EXISTS correlated sub-query).
-- ----------------------------------------------------------------------------
PROMPT === Q7: customers who currently hold a loan ===
SELECT c.full_name, l.loan_type, l.outstanding_balance
FROM   customers c
JOIN   loans l ON l.customer_id = c.customer_id
WHERE  EXISTS (
           SELECT 1 FROM loans x
           WHERE  x.customer_id = c.customer_id
           AND    x.status = 'ACTIVE'
       )
ORDER  BY l.outstanding_balance DESC;

-- ----------------------------------------------------------------------------
-- Q8. Rank accounts by balance WITHIN each branch (analytic window function).
-- ----------------------------------------------------------------------------
PROMPT === Q8: rank of accounts by balance within each branch ===
SELECT b.branch_name,
       c.full_name,
       a.account_number,
       a.balance,
       RANK() OVER (PARTITION BY b.branch_id ORDER BY a.balance DESC) AS balance_rank
FROM   accounts a
JOIN   customers c ON c.customer_id = a.customer_id
JOIN   branches  b ON b.branch_id   = c.branch_id
ORDER  BY b.branch_name, balance_rank;

-- ----------------------------------------------------------------------------
-- Q9. Running balance per account using a window SUM (ledger view).
-- ----------------------------------------------------------------------------
PROMPT === Q9: running totals of transaction amounts per account ===
SELECT account_id,
       TO_CHAR(transaction_date, 'YYYY-MM-DD HH24:MI') AS txn_time,
       transaction_type,
       amount,
       SUM(CASE WHEN transaction_type IN ('DEPOSIT','TRANSFER_IN')
                THEN amount ELSE -amount END)
           OVER (PARTITION BY account_id ORDER BY transaction_date, transaction_id) AS running_net
FROM   transactions
ORDER  BY account_id, transaction_date, transaction_id;

-- ----------------------------------------------------------------------------
-- Q10. Branch performance: number of customers, accounts, and total deposits
--      (multi-level JOIN + aggregation + HAVING).
-- ----------------------------------------------------------------------------
PROMPT === Q10: branch performance summary ===
SELECT b.branch_name,
       COUNT(DISTINCT c.customer_id) AS customers,
       COUNT(DISTINCT a.account_id)  AS accounts,
       NVL(SUM(a.balance), 0)        AS total_deposits
FROM   branches  b
LEFT   JOIN customers c ON c.branch_id   = b.branch_id
LEFT   JOIN accounts  a ON a.customer_id = c.customer_id
GROUP  BY b.branch_name
ORDER  BY total_deposits DESC;

-- ----------------------------------------------------------------------------
-- A reusable VIEW that joins accounts to their owner and branch. Handy for
-- dashboards and for simplifying the queries above.
-- ----------------------------------------------------------------------------
PROMPT === Creating reporting view vw_account_summary ===
CREATE OR REPLACE VIEW vw_account_summary AS
SELECT a.account_id,
       a.account_number,
       a.account_type,
       a.balance,
       a.currency,
       a.status,
       c.customer_id,
       c.full_name AS customer_name,
       b.branch_id,
       b.branch_name
FROM   accounts a
JOIN   customers c ON c.customer_id = a.customer_id
LEFT   JOIN branches b ON b.branch_id = c.branch_id;

PROMPT === Sample of vw_account_summary ===
SELECT * FROM vw_account_summary ORDER BY balance DESC;
