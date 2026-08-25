CREATE WAREHOUSE CUSTOMER_HISTORY_WH
WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;
USE WAREHOUSE CUSTOMER_HISTORY_WH;

/* ============================================================
   TASK 1 — CREATE DATABASE AND SCHEMA
   ============================================================ */

CREATE DATABASE IF NOT EXISTS CUSTOMER_SCD_DB;

USE DATABASE CUSTOMER_SCD_DB;

CREATE SCHEMA IF NOT EXISTS CUSTOMER_SCHEMA;

USE SCHEMA CUSTOMER_SCHEMA;

CREATE OR REPLACE FILE FORMAT CSV_FORMAT
TYPE = CSV
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
SKIP_HEADER = 1;

CREATE OR REPLACE STAGE CUSTOMER_STAGE
FILE_FORMAT = CSV_FORMAT;
/* ============================================================
   TASK 2 — CREATE SCD TYPE 3 DIMENSION
   ============================================================ */

CREATE OR REPLACE TABLE DIM_CUSTOMER_SCD3 (
    CUSTOMER_KEY INT AUTOINCREMENT,
    CUSTOMER_ID INT,
    CUSTOMER_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    CURRENT_MEMBERSHIP VARCHAR(30),
    PREVIOUS_MEMBERSHIP VARCHAR(30),
    SEGMENT VARCHAR(30)
);


/* ============================================================
   TASK 3 — LOAD INITIAL TYPE 3 DATA
   ============================================================ */

CREATE OR REPLACE TABLE CUSTOMER_INITIAL (
    CUSTOMER_ID INT,
    CUSTOMER_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    MEMBERSHIP VARCHAR(30),
    SEGMENT VARCHAR(30)
);

COPY INTO CUSTOMER_INITIAL
FROM @CUSTOMER_STAGE/customers_initial.csv
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT');

INSERT INTO DIM_CUSTOMER_SCD3 (
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    CURRENT_MEMBERSHIP,
    PREVIOUS_MEMBERSHIP,
    SEGMENT
)
SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    NULL,
    SEGMENT
FROM CUSTOMER_INITIAL;


/* ============================================================
   TASK 4 — DISPLAY INITIAL TYPE 3 DATA
   ============================================================ */

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    CURRENT_MEMBERSHIP,
    PREVIOUS_MEMBERSHIP
FROM DIM_CUSTOMER_SCD3
ORDER BY CUSTOMER_ID;


/* ============================================================
   TASK 5 / 6 — LOAD CUSTOMER UPDATES
   ============================================================ */

CREATE OR REPLACE TABLE CUSTOMER_UPDATES (
    CUSTOMER_ID INT,
    CUSTOMER_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    MEMBERSHIP VARCHAR(30),
    SEGMENT VARCHAR(30),
    EFFECTIVE_DATE DATE
);

COPY INTO CUSTOMER_UPDATES
FROM @CUSTOMER_STAGE/customer_updates.csv
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT');


/* ============================================================
   APPLY SCD TYPE 3 CHANGES
   ============================================================ */

UPDATE DIM_CUSTOMER_SCD3 t
SET
    PREVIOUS_MEMBERSHIP = t.CURRENT_MEMBERSHIP,
    CURRENT_MEMBERSHIP = u.MEMBERSHIP,
    CUSTOMER_NAME = u.CUSTOMER_NAME,
    CITY = u.CITY,
    STATE = u.STATE,
    SEGMENT = u.SEGMENT
FROM CUSTOMER_UPDATES u
WHERE t.CUSTOMER_ID = u.CUSTOMER_ID
  AND t.CURRENT_MEMBERSHIP <> u.MEMBERSHIP;


/* ============================================================
   TASK 7 — TYPE 3 FINAL REPORT
   ============================================================ */

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    CURRENT_MEMBERSHIP,
    PREVIOUS_MEMBERSHIP
FROM DIM_CUSTOMER_SCD3
ORDER BY CUSTOMER_ID;


/* ============================================================
   TASK 8 — DEMONSTRATE TYPE 3
   ============================================================ */

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CURRENT_MEMBERSHIP,
    PREVIOUS_MEMBERSHIP
FROM DIM_CUSTOMER_SCD3
WHERE CUSTOMER_ID = 101;


/* ============================================================
   TYPE 3 RECORD COUNT
   ============================================================ */

SELECT COUNT(*) AS SCD_TYPE_3_RECORD_COUNT
FROM DIM_CUSTOMER_SCD3;


/* ============================================================
   TASK 9 — CREATE SCD TYPE 6 DIMENSION
   ============================================================ */

CREATE OR REPLACE TABLE DIM_CUSTOMER_SCD6 (
    CUSTOMER_KEY INT AUTOINCREMENT,
    CUSTOMER_ID INT,
    CUSTOMER_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    CURRENT_MEMBERSHIP VARCHAR(30),
    PREVIOUS_MEMBERSHIP VARCHAR(30),
    HISTORICAL_MEMBERSHIP VARCHAR(30),
    SEGMENT VARCHAR(30),
    EFFECTIVE_DATE DATE,
    EXPIRY_DATE DATE,
    IS_CURRENT BOOLEAN
);


/* ============================================================
   TASK 10 — LOAD INITIAL TYPE 6 DATA
   ============================================================ */

INSERT INTO DIM_CUSTOMER_SCD6 (
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    CURRENT_MEMBERSHIP,
    PREVIOUS_MEMBERSHIP,
    HISTORICAL_MEMBERSHIP,
    SEGMENT,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
)
SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    NULL,
    MEMBERSHIP,
    SEGMENT,
    '2026-01-01'::DATE,
    '9999-12-31'::DATE,
    TRUE
FROM CUSTOMER_INITIAL;


/* ============================================================
   VERIFY INITIAL TYPE 6 DATA
   ============================================================ */

SELECT
    COUNT(*) AS TOTAL_RECORDS,
    COUNT_IF(IS_CURRENT = TRUE) AS CURRENT_RECORDS
FROM DIM_CUSTOMER_SCD6;


/* ============================================================
   TASK 11 — TYPE 6 CHANGE FOR CUSTOMER 101
   ============================================================ */


UPDATE DIM_CUSTOMER_SCD6
SET
    EXPIRY_DATE = '2026-03-31',
    IS_CURRENT = FALSE
WHERE CUSTOMER_ID = 101
  AND IS_CURRENT = TRUE;

INSERT INTO DIM_CUSTOMER_SCD6 (
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    CURRENT_MEMBERSHIP,
    PREVIOUS_MEMBERSHIP,
    HISTORICAL_MEMBERSHIP,
    SEGMENT,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
)
SELECT
    u.CUSTOMER_ID,
    u.CUSTOMER_NAME,
    u.CITY,
    u.STATE,
    u.MEMBERSHIP,
    'Silver',
    'Silver',
    u.SEGMENT,
    u.EFFECTIVE_DATE,
    '9999-12-31'::DATE,
    TRUE
FROM CUSTOMER_UPDATES u
WHERE u.CUSTOMER_ID = 101;


/* ============================================================
   TASK 12 — TYPE 6 CHANGES FOR CUSTOMER 103 AND 104
   ============================================================ */

UPDATE DIM_CUSTOMER_SCD6
SET
    EXPIRY_DATE = '2026-04-04',
    IS_CURRENT = FALSE
WHERE CUSTOMER_ID = 103
  AND IS_CURRENT = TRUE;

INSERT INTO DIM_CUSTOMER_SCD6 (
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    CURRENT_MEMBERSHIP,
    PREVIOUS_MEMBERSHIP,
    HISTORICAL_MEMBERSHIP,
    SEGMENT,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
)
SELECT
    u.CUSTOMER_ID,
    u.CUSTOMER_NAME,
    u.CITY,
    u.STATE,
    u.MEMBERSHIP,
    'Silver',
    'Silver',
    u.SEGMENT,
    u.EFFECTIVE_DATE,
    '9999-12-31'::DATE,
    TRUE
FROM CUSTOMER_UPDATES u
WHERE u.CUSTOMER_ID = 103;


UPDATE DIM_CUSTOMER_SCD6
SET
    EXPIRY_DATE = '2026-04-09',
    IS_CURRENT = FALSE
WHERE CUSTOMER_ID = 104
  AND IS_CURRENT = TRUE;


INSERT INTO DIM_CUSTOMER_SCD6 (
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    CURRENT_MEMBERSHIP,
    PREVIOUS_MEMBERSHIP,
    HISTORICAL_MEMBERSHIP,
    SEGMENT,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
)
SELECT
    u.CUSTOMER_ID,
    u.CUSTOMER_NAME,
    u.CITY,
    u.STATE,
    u.MEMBERSHIP,
    'Gold',
    'Gold',
    u.SEGMENT,
    u.EFFECTIVE_DATE,
    '9999-12-31'::DATE,
    TRUE
FROM CUSTOMER_UPDATES u
WHERE u.CUSTOMER_ID = 104;


/* ============================================================
   TASK 13 — COMPLETE TYPE 6 HISTORY
   ============================================================ */

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CURRENT_MEMBERSHIP,
    PREVIOUS_MEMBERSHIP,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
FROM DIM_CUSTOMER_SCD6
ORDER BY CUSTOMER_ID, EFFECTIVE_DATE;


/* ============================================================
   TASK 14 — CURRENT CUSTOMER REPORT
   ============================================================ */

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    CURRENT_MEMBERSHIP,
    PREVIOUS_MEMBERSHIP
FROM DIM_CUSTOMER_SCD6
WHERE IS_CURRENT = TRUE
ORDER BY CUSTOMER_ID;


/* ============================================================
   TASK 15 — POINT-IN-TIME HISTORICAL QUERY
   ============================================================ */

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CURRENT_MEMBERSHIP,
    EFFECTIVE_DATE,
    EXPIRY_DATE
FROM DIM_CUSTOMER_SCD6
WHERE CUSTOMER_ID = 101
  AND '2026-03-15'::DATE BETWEEN EFFECTIVE_DATE AND EXPIRY_DATE;


/* ============================================================
   TASK 16 — TYPE 3 VS TYPE 6 COMPARISON
   ============================================================ */

SELECT
    'SCD TYPE 3' AS SCD_TYPE,
    'YES' AS CURRENT_VALUE,
    'YES' AS PREVIOUS_VALUE,
    'NO' AS HISTORICAL_ROWS,
    'NO' AS EFFECTIVE_DATE,
    'NO' AS EXPIRY_DATE,
    'NO' AS IS_CURRENT

UNION ALL

SELECT
    'SCD TYPE 6',
    'YES',
    'YES',
    'YES',
    'YES',
    'YES',
    'YES';


/* ============================================================
   TASK 17 — FINAL RECORD COUNT VALIDATION
   ============================================================ */

SELECT
    (SELECT COUNT(*)
     FROM DIM_CUSTOMER_SCD3) AS SCD_TYPE_3_RECORD_COUNT,

    (SELECT COUNT(*)
     FROM DIM_CUSTOMER_SCD6) AS SCD_TYPE_6_RECORD_COUNT,

    (SELECT COUNT(*)
     FROM DIM_CUSTOMER_SCD6
     WHERE IS_CURRENT = TRUE) AS SCD_TYPE_6_CURRENT_RECORD_COUNT,

    (SELECT COUNT(*)
     FROM DIM_CUSTOMER_SCD6
     WHERE IS_CURRENT = FALSE) AS SCD_TYPE_6_HISTORICAL_RECORD_COUNT;

