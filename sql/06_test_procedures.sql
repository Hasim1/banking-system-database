-- ============================================================================
-- File   : 06_test_procedures.sql
-- Purpose: Exercise every procedure and demonstrate ACID behaviour
--          (COMMIT / ROLLBACK / SAVEPOINT) plus PL/SQL exception handling.
-- Engine : Oracle Database (Oracle XE 21c / SQL Developer)
-- HOW TO RUN: Run "SET SERVEROUTPUT ON" first (already included below) so the
--             DBMS_OUTPUT messages appear in the SQL Developer "Script Output".
-- ============================================================================

SET SERVEROUTPUT ON

-- ----------------------------------------------------------------------------
-- TEST 1: Create a new customer (OUT parameter captured in a local variable).
-- ----------------------------------------------------------------------------
PROMPT === TEST 1: sp_create_customer ===
DECLARE
    v_new_customer NUMBER;
BEGIN
    sp_create_customer(
        p_full_name    => 'Robert King',
        p_national_id  => 'NID2001',
        p_phone_number => '+1-212-555-2001',
        p_email        => 'robert.king@email.com',
        p_branch_id    => 1,
        p_customer_id  => v_new_customer);
END;
/

-- ----------------------------------------------------------------------------
-- TEST 2: Open an account for the new customer with an opening deposit.
-- ----------------------------------------------------------------------------
PROMPT === TEST 2: sp_open_account ===
DECLARE
    v_customer_id NUMBER;
    v_new_account NUMBER;
BEGIN
    -- Look up the customer created in TEST 1 (subqueries can't be passed
    -- directly as PL/SQL arguments, so we SELECT INTO a variable first).
    SELECT customer_id INTO v_customer_id
    FROM customers WHERE national_id = 'NID2001';

    sp_open_account(
        p_customer_id     => v_customer_id,
        p_account_type    => 'SAVINGS',
        p_initial_deposit => 1000,
        p_currency        => 'USD',
        p_account_id      => v_new_account);
END;
/

-- ----------------------------------------------------------------------------
-- TEST 3: Deposit and withdraw on an existing account (account_id = 1).
-- ----------------------------------------------------------------------------
PROMPT === TEST 3: sp_deposit / sp_withdraw on account 1 ===
BEGIN
    DBMS_OUTPUT.PUT_LINE('Balance before: ' || fn_get_balance(1));
    sp_deposit(p_account_id => 1, p_amount => 750, p_description => 'Test deposit');
    sp_withdraw(p_account_id => 1, p_amount => 250, p_description => 'Test withdrawal');
    DBMS_OUTPUT.PUT_LINE('Balance after : ' || fn_get_balance(1));
END;
/

-- ----------------------------------------------------------------------------
-- TEST 4: Transfer money between two accounts (atomic, SAVEPOINT + COMMIT).
-- ----------------------------------------------------------------------------
PROMPT === TEST 4: sp_transfer 500 from account 5 to account 6 ===
BEGIN
    DBMS_OUTPUT.PUT_LINE('Acct 5 before: ' || fn_get_balance(5)
        || ' | Acct 6 before: ' || fn_get_balance(6));
    sp_transfer(p_from_account => 5, p_to_account => 6, p_amount => 500);
    DBMS_OUTPUT.PUT_LINE('Acct 5 after : ' || fn_get_balance(5)
        || ' | Acct 6 after : ' || fn_get_balance(6));
END;
/

-- ----------------------------------------------------------------------------
-- TEST 5: Exception handling - withdraw more than the balance.
--         The procedure raises ORA-20002 and rolls back; nothing is lost.
-- ----------------------------------------------------------------------------
PROMPT === TEST 5: insufficient-funds is rejected ===
BEGIN
    sp_withdraw(p_account_id => 6, p_amount => 999999);
    DBMS_OUTPUT.PUT_LINE('ERROR: withdrawal should have failed!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught expected error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Balance unchanged: ' || fn_get_balance(6));
END;
/

-- ----------------------------------------------------------------------------
-- TEST 6: Exception handling - transfer to the same account is rejected.
-- ----------------------------------------------------------------------------
PROMPT === TEST 6: same-account transfer is rejected ===
BEGIN
    sp_transfer(p_from_account => 3, p_to_account => 3, p_amount => 100);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Caught expected error: ' || SQLERRM);
END;
/

-- ----------------------------------------------------------------------------
-- TEST 7: Manual ACID demo - SAVEPOINT, partial ROLLBACK, then COMMIT.
--   We make two deposits, undo the second with ROLLBACK TO, and keep the first.
-- ----------------------------------------------------------------------------
PROMPT === TEST 7: manual SAVEPOINT / ROLLBACK demo on account 2 ===
DECLARE
    v_start NUMBER := fn_get_balance(2);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Start balance: ' || v_start);

    UPDATE accounts SET balance = balance + 100 WHERE account_id = 2;  -- first change
    SAVEPOINT after_first_change;

    UPDATE accounts SET balance = balance + 9999 WHERE account_id = 2; -- second change
    DBMS_OUTPUT.PUT_LINE('After both (uncommitted): ' || fn_get_balance(2));

    ROLLBACK TO after_first_change;   -- undo only the second change
    COMMIT;                           -- keep the first change permanently

    DBMS_OUTPUT.PUT_LINE('Final balance (start + 100): ' || fn_get_balance(2));
END;
/

-- ----------------------------------------------------------------------------
-- TEST 8: Print a full statement for account 1.
-- ----------------------------------------------------------------------------
PROMPT === TEST 8: sp_view_transaction_history for account 1 ===
BEGIN
    sp_view_transaction_history(1);
END;
/

-- ----------------------------------------------------------------------------
-- TEST 9: Show that the audit trail captured the live changes above.
-- ----------------------------------------------------------------------------
PROMPT === TEST 9: most recent audit-log entries ===
SELECT log_id, table_name, operation, record_id, new_value,
       TO_CHAR(change_date, 'YYYY-MM-DD HH24:MI:SS') AS change_date
FROM   audit_logs
ORDER  BY log_id DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT === All procedure tests complete ===
