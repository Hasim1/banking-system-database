-- ============================================================================
-- File   : 04_triggers.sql
-- Purpose: Audit-logging triggers. Every INSERT/UPDATE/DELETE on the key
--          tables writes a row into AUDIT_LOGS automatically.
-- Engine : Oracle Database (Oracle XE 21c / SQL Developer)
-- Notes  : * Each trigger is row-level (FOR EACH ROW) and fires AFTER the DML
--            so the change is guaranteed to have happened.
--          * AUDIT_LOGS.changed_by and change_date default automatically, so
--            the triggers never have to set them.
--          * Every PL/SQL object ends with a slash ("/") so SQL Developer
--            compiles it correctly.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Trigger: audit CUSTOMERS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_customers_audit
AFTER INSERT OR UPDATE OR DELETE ON customers
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO audit_logs (table_name, operation, record_id, old_value, new_value)
        VALUES ('CUSTOMERS', 'INSERT', :NEW.customer_id,
                NULL,
                'name=' || :NEW.full_name || '; status=' || :NEW.status);
    ELSIF UPDATING THEN
        INSERT INTO audit_logs (table_name, operation, record_id, old_value, new_value)
        VALUES ('CUSTOMERS', 'UPDATE', :NEW.customer_id,
                'name=' || :OLD.full_name || '; status=' || :OLD.status,
                'name=' || :NEW.full_name || '; status=' || :NEW.status);
    ELSIF DELETING THEN
        INSERT INTO audit_logs (table_name, operation, record_id, old_value, new_value)
        VALUES ('CUSTOMERS', 'DELETE', :OLD.customer_id,
                'name=' || :OLD.full_name || '; status=' || :OLD.status,
                NULL);
    END IF;
END;
/

-- ----------------------------------------------------------------------------
-- Trigger: audit ACCOUNTS (captures balance and status changes)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_accounts_audit
AFTER INSERT OR UPDATE OR DELETE ON accounts
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO audit_logs (table_name, operation, record_id, old_value, new_value)
        VALUES ('ACCOUNTS', 'INSERT', :NEW.account_id,
                NULL,
                'balance=' || :NEW.balance || '; status=' || :NEW.status);
    ELSIF UPDATING THEN
        INSERT INTO audit_logs (table_name, operation, record_id, old_value, new_value)
        VALUES ('ACCOUNTS', 'UPDATE', :NEW.account_id,
                'balance=' || :OLD.balance || '; status=' || :OLD.status,
                'balance=' || :NEW.balance || '; status=' || :NEW.status);
    ELSIF DELETING THEN
        INSERT INTO audit_logs (table_name, operation, record_id, old_value, new_value)
        VALUES ('ACCOUNTS', 'DELETE', :OLD.account_id,
                'balance=' || :OLD.balance || '; status=' || :OLD.status,
                NULL);
    END IF;
END;
/

-- ----------------------------------------------------------------------------
-- Trigger: audit TRANSACTIONS (the ledger is append-only in practice, but we
--          handle every DML type for completeness)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_transactions_audit
AFTER INSERT OR UPDATE OR DELETE ON transactions
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO audit_logs (table_name, operation, record_id, old_value, new_value)
        VALUES ('TRANSACTIONS', 'INSERT', :NEW.transaction_id,
                NULL,
                :NEW.transaction_type || ' amount=' || :NEW.amount
                || ' on account ' || :NEW.account_id);
    ELSIF UPDATING THEN
        INSERT INTO audit_logs (table_name, operation, record_id, old_value, new_value)
        VALUES ('TRANSACTIONS', 'UPDATE', :NEW.transaction_id,
                :OLD.transaction_type || ' amount=' || :OLD.amount,
                :NEW.transaction_type || ' amount=' || :NEW.amount);
    ELSIF DELETING THEN
        INSERT INTO audit_logs (table_name, operation, record_id, old_value, new_value)
        VALUES ('TRANSACTIONS', 'DELETE', :OLD.transaction_id,
                :OLD.transaction_type || ' amount=' || :OLD.amount,
                NULL);
    END IF;
END;
/

PROMPT Audit triggers created on CUSTOMERS, ACCOUNTS, and TRANSACTIONS.
