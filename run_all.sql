-- ============================================================================
-- File   : run_all.sql
-- Purpose: One-click build of the entire Banking System database.
-- Engine : Oracle Database (Oracle XE 21c / SQL Developer / SQLcl)
--
-- HOW TO RUN
--   Option A - SQL Developer:
--       1. Connect to your database.
--       2. Open this file, then click "Run Script" (F5) -- NOT "Run Statement".
--          (F5 understands the "/" terminators and "@@" includes.)
--   Option B - SQLcl / SQL*Plus command line:
--       sql  username/password@//localhost:1521/XEPDB1  @run_all.sql
--
-- This script builds the schema and loads the seed data. After it finishes,
-- run sql/06_test_procedures.sql and sql/07_advanced_queries.sql separately
-- to see the operations and reports in action.
-- ============================================================================

SET SERVEROUTPUT ON
SET DEFINE OFF
SET TIMING ON

PROMPT ############################################################
PROMPT # 1/5  Dropping any existing objects ...
PROMPT ############################################################
@@sql/01_drop_tables.sql

PROMPT ############################################################
PROMPT # 2/5  Creating tables, sequence and indexes ...
PROMPT ############################################################
@@sql/02_create_tables.sql

PROMPT ############################################################
PROMPT # 3/5  Inserting sample data ...
PROMPT ############################################################
@@sql/03_insert_sample_data.sql

PROMPT ############################################################
PROMPT # 4/5  Creating audit triggers ...
PROMPT ############################################################
@@sql/04_triggers.sql

PROMPT ############################################################
PROMPT # 5/5  Creating procedures and functions ...
PROMPT ############################################################
@@sql/05_procedures.sql

PROMPT ############################################################
PROMPT # BUILD COMPLETE.
PROMPT #   Next: run sql/06_test_procedures.sql  (live operations + ACID demos)
PROMPT #   Then: run sql/07_advanced_queries.sql (reports and analytics)
PROMPT ############################################################
