-- ============================================================================
-- File   : 05_procedures.sql
-- Purpose: PL/SQL stored procedures and a function implementing the core
--          banking operations with full ACID handling and error handling.
-- Engine : Oracle Database (Oracle XE 21c / SQL Developer)
-- Objects:
--   sp_create_customer        - register a new customer
--   sp_open_account           - open an account (auto-generates account_number)
--   fn_get_balance            - return an account's current balance
--   sp_deposit                - deposit money (COMMIT on success)
--   sp_withdraw               - withdraw money (insufficient-funds check)
--   sp_transfer               - transfer between accounts (SAVEPOINT + COMMIT)
--   sp_view_transaction_history - print a statement via DBMS_OUTPUT
--
-- Custom application errors (RAISE_APPLICATION_ERROR):
--   -20001 same source/target account
--   -20002 insufficient funds
--   -20003 account not found
--   -20004 account not active
--   -20005 invalid amount (<= 0)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- sp_create_customer : insert a customer and return the new customer_id.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_create_customer (
    p_full_name     IN  VARCHAR2,
    p_national_id   IN  VARCHAR2,
    p_phone_number  IN  VARCHAR2 DEFAULT NULL,
    p_email         IN  VARCHAR2 DEFAULT NULL,
    p_branch_id     IN  NUMBER   DEFAULT NULL,
    p_customer_id   OUT NUMBER
) AS
BEGIN
    INSERT INTO customers (full_name, national_id, phone_number, email, branch_id)
    VALUES (p_full_name, p_national_id, p_phone_number, p_email, p_branch_id)
    RETURNING customer_id INTO p_customer_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Customer created with ID = ' || p_customer_id);
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010,
            'A customer with that national ID or email already exists.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_create_customer;
/

-- ----------------------------------------------------------------------------
-- sp_open_account : open an account for a customer. The account number is
--                   generated as 'ACC' + a 10-digit sequence value.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_open_account (
    p_customer_id      IN  NUMBER,
    p_account_type     IN  VARCHAR2,
    p_initial_deposit  IN  NUMBER   DEFAULT 0,
    p_currency         IN  VARCHAR2 DEFAULT 'USD',
    p_account_id       OUT NUMBER
) AS
    v_exists         NUMBER;
    v_account_number VARCHAR2(20);
BEGIN
    IF p_initial_deposit < 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Initial deposit cannot be negative.');
    END IF;

    -- Make sure the customer exists before opening an account.
    SELECT COUNT(*) INTO v_exists
    FROM customers
    WHERE customer_id = p_customer_id;

    IF v_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Customer ' || p_customer_id || ' does not exist.');
    END IF;

    v_account_number := 'ACC' || LPAD(seq_account_no.NEXTVAL, 10, '0');

    INSERT INTO accounts (account_number, customer_id, account_type, balance, currency)
    VALUES (v_account_number, p_customer_id, p_account_type, p_initial_deposit, p_currency)
    RETURNING account_id INTO p_account_id;

    -- Record the opening deposit as the first transaction, if any.
    IF p_initial_deposit > 0 THEN
        INSERT INTO transactions (account_id, transaction_type, amount, balance_after, description)
        VALUES (p_account_id, 'DEPOSIT', p_initial_deposit, p_initial_deposit, 'Opening deposit');
    END IF;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Account opened: ' || v_account_number
        || ' (ID = ' || p_account_id || ')');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_open_account;
/

-- ----------------------------------------------------------------------------
-- fn_get_balance : return the current balance of an account.
--                  Raises -20003 if the account does not exist.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_get_balance (
    p_account_id IN NUMBER
) RETURN NUMBER AS
    v_balance NUMBER(15,2);
BEGIN
    SELECT balance INTO v_balance
    FROM accounts
    WHERE account_id = p_account_id;

    RETURN v_balance;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003,
            'Account ' || p_account_id || ' does not exist.');
END fn_get_balance;
/

-- ----------------------------------------------------------------------------
-- sp_deposit : add money to an account inside one atomic transaction.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_deposit (
    p_account_id IN NUMBER,
    p_amount     IN NUMBER,
    p_description IN VARCHAR2 DEFAULT 'Cash deposit'
) AS
    v_balance NUMBER(15,2);
    v_status  VARCHAR2(10);
BEGIN
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Deposit amount must be greater than zero.');
    END IF;

    -- Lock the account row so concurrent transactions serialise correctly.
    SELECT balance, status INTO v_balance, v_status
    FROM accounts
    WHERE account_id = p_account_id
    FOR UPDATE;

    IF v_status <> 'ACTIVE' THEN
        RAISE_APPLICATION_ERROR(-20004,
            'Account ' || p_account_id || ' is not ACTIVE (status=' || v_status || ').');
    END IF;

    v_balance := v_balance + p_amount;

    UPDATE accounts
    SET balance = v_balance
    WHERE account_id = p_account_id;

    INSERT INTO transactions (account_id, transaction_type, amount, balance_after, description)
    VALUES (p_account_id, 'DEPOSIT', p_amount, v_balance, p_description);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Deposited ' || p_amount || '. New balance = ' || v_balance);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20003,
            'Account ' || p_account_id || ' does not exist.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_deposit;
/

-- ----------------------------------------------------------------------------
-- sp_withdraw : remove money from an account, enforcing sufficient funds.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_withdraw (
    p_account_id IN NUMBER,
    p_amount     IN NUMBER,
    p_description IN VARCHAR2 DEFAULT 'Cash withdrawal'
) AS
    v_balance NUMBER(15,2);
    v_status  VARCHAR2(10);
BEGIN
    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Withdrawal amount must be greater than zero.');
    END IF;

    SELECT balance, status INTO v_balance, v_status
    FROM accounts
    WHERE account_id = p_account_id
    FOR UPDATE;

    IF v_status <> 'ACTIVE' THEN
        RAISE_APPLICATION_ERROR(-20004,
            'Account ' || p_account_id || ' is not ACTIVE (status=' || v_status || ').');
    END IF;

    IF v_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Insufficient funds. Balance = ' || v_balance || ', requested = ' || p_amount);
    END IF;

    v_balance := v_balance - p_amount;

    UPDATE accounts
    SET balance = v_balance
    WHERE account_id = p_account_id;

    INSERT INTO transactions (account_id, transaction_type, amount, balance_after, description)
    VALUES (p_account_id, 'WITHDRAWAL', p_amount, v_balance, p_description);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Withdrew ' || p_amount || '. New balance = ' || v_balance);
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20003,
            'Account ' || p_account_id || ' does not exist.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_withdraw;
/

-- ----------------------------------------------------------------------------
-- sp_transfer : move money between two accounts atomically.
--   Demonstrates SAVEPOINT, COMMIT, ROLLBACK and row locking (FOR UPDATE).
--   Either BOTH legs succeed or NEITHER does.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_transfer (
    p_from_account IN NUMBER,
    p_to_account   IN NUMBER,
    p_amount       IN NUMBER
) AS
    v_from_balance NUMBER(15,2);
    v_to_balance   NUMBER(15,2);
    v_from_status  VARCHAR2(10);
    v_to_status    VARCHAR2(10);
BEGIN
    -- Establish the savepoint FIRST, before any validation can raise, so the
    -- exception handlers can always safely roll back to it. (If it were set
    -- after the checks below, an early error would hit a non-existent
    -- savepoint and raise ORA-01086, masking the real error.)
    SAVEPOINT sp_before_transfer;

    IF p_amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Transfer amount must be greater than zero.');
    END IF;

    IF p_from_account = p_to_account THEN
        RAISE_APPLICATION_ERROR(-20001, 'Source and target accounts must differ.');
    END IF;

    -- Lock both rows. Always lock the lower account_id first to avoid deadlocks.
    IF p_from_account < p_to_account THEN
        SELECT balance, status INTO v_from_balance, v_from_status
        FROM accounts WHERE account_id = p_from_account FOR UPDATE;
        SELECT balance, status INTO v_to_balance, v_to_status
        FROM accounts WHERE account_id = p_to_account FOR UPDATE;
    ELSE
        SELECT balance, status INTO v_to_balance, v_to_status
        FROM accounts WHERE account_id = p_to_account FOR UPDATE;
        SELECT balance, status INTO v_from_balance, v_from_status
        FROM accounts WHERE account_id = p_from_account FOR UPDATE;
    END IF;

    IF v_from_status <> 'ACTIVE' THEN
        RAISE_APPLICATION_ERROR(-20004,
            'Source account ' || p_from_account || ' is not ACTIVE.');
    END IF;

    IF v_to_status <> 'ACTIVE' THEN
        RAISE_APPLICATION_ERROR(-20004,
            'Target account ' || p_to_account || ' is not ACTIVE.');
    END IF;

    IF v_from_balance < p_amount THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Insufficient funds in account ' || p_from_account
            || '. Balance = ' || v_from_balance || ', requested = ' || p_amount);
    END IF;

    -- Debit the source.
    v_from_balance := v_from_balance - p_amount;
    UPDATE accounts SET balance = v_from_balance WHERE account_id = p_from_account;
    INSERT INTO transactions (account_id, transaction_type, amount, balance_after,
                              related_account_id, description)
    VALUES (p_from_account, 'TRANSFER_OUT', p_amount, v_from_balance,
            p_to_account, 'Transfer to account ' || p_to_account);

    -- Credit the target.
    v_to_balance := v_to_balance + p_amount;
    UPDATE accounts SET balance = v_to_balance WHERE account_id = p_to_account;
    INSERT INTO transactions (account_id, transaction_type, amount, balance_after,
                              related_account_id, description)
    VALUES (p_to_account, 'TRANSFER_IN', p_amount, v_to_balance,
            p_from_account, 'Transfer from account ' || p_from_account);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Transferred ' || p_amount
        || ' from account ' || p_from_account || ' to account ' || p_to_account || '.');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- One of the accounts was not found during the locking SELECTs.
        ROLLBACK TO sp_before_transfer;
        RAISE_APPLICATION_ERROR(-20003,
            'One of the accounts does not exist.');
    WHEN OTHERS THEN
        -- Undo BOTH legs of the transfer atomically (the savepoint sits at the
        -- very top of the block), then re-raise the original error.
        ROLLBACK TO sp_before_transfer;
        RAISE;
END sp_transfer;
/

-- ----------------------------------------------------------------------------
-- sp_view_transaction_history : print an account statement via DBMS_OUTPUT.
--   Tip: run "SET SERVEROUTPUT ON" in SQL Developer to see the output.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_view_transaction_history (
    p_account_id IN NUMBER
) AS
    v_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- Statement for account ' || p_account_id
        || ' | Current balance = ' || fn_get_balance(p_account_id) || ' ---');

    FOR r IN (
        SELECT transaction_id, transaction_type, amount, balance_after,
               TO_CHAR(transaction_date, 'YYYY-MM-DD HH24:MI') AS txn_time,
               description
        FROM transactions
        WHERE account_id = p_account_id
        ORDER BY transaction_date, transaction_id
    ) LOOP
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE(
            r.txn_time || ' | ' || RPAD(r.transaction_type, 12)
            || ' | amount=' || r.amount
            || ' | balance=' || r.balance_after
            || ' | ' || r.description);
    END LOOP;

    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('  (no transactions found)');
    END IF;
END sp_view_transaction_history;
/

PROMPT Procedures and functions compiled.
PROMPT   sp_create_customer, sp_open_account, fn_get_balance,
PROMPT   sp_deposit, sp_withdraw, sp_transfer, sp_view_transaction_history
