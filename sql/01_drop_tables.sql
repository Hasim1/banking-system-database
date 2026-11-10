-- ============================================================================
-- File   : 01_drop_tables.sql
-- Purpose: Safely drop all objects so the script set can be re-run from scratch.
-- Engine : Oracle Database (tested against Oracle XE 21c / SQL Developer)
-- Notes  : Run this FIRST. It will NOT error if the objects do not yet exist.
--          The PL/SQL block below ignores ORA-00942 (table does not exist)
--          and ORA-02289 (sequence does not exist).
-- ============================================================================

SET SERVEROUTPUT ON

-- Drop tables in child-to-parent order. CASCADE CONSTRAINTS also removes the
-- foreign keys that point at each table, so re-running is always clean.
BEGIN
  FOR t IN (
    SELECT 'AUDIT_LOGS'   AS tname FROM dual UNION ALL
    SELECT 'TRANSACTIONS'           FROM dual UNION ALL
    SELECT 'CARDS'                  FROM dual UNION ALL
    SELECT 'LOANS'                  FROM dual UNION ALL
    SELECT 'ACCOUNTS'               FROM dual UNION ALL
    SELECT 'CUSTOMERS'              FROM dual UNION ALL
    SELECT 'EMPLOYEES'              FROM dual UNION ALL
    SELECT 'BRANCHES'               FROM dual
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE ' || t.tname || ' CASCADE CONSTRAINTS';
      DBMS_OUTPUT.PUT_LINE('Dropped table: ' || t.tname);
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -942 THEN          -- -942 = table does not exist
          RAISE;
        END IF;
    END;
  END LOOP;
END;
/

-- Drop the standalone sequence used to generate account numbers.
BEGIN
  EXECUTE IMMEDIATE 'DROP SEQUENCE seq_account_no';
  DBMS_OUTPUT.PUT_LINE('Dropped sequence: SEQ_ACCOUNT_NO');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -2289 THEN              -- -2289 = sequence does not exist
      RAISE;
    END IF;
END;
/

-- Drop the reporting view if it exists (created in 07_advanced_queries.sql).
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW vw_account_summary';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN               -- -942 = view does not exist
      RAISE;
    END IF;
END;
/

PROMPT All existing banking objects dropped (if any). Ready for a clean build.
