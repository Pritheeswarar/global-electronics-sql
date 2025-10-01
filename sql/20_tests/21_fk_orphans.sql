USE [Global_Electronics];
GO

/*
  Script: 21_fk_orphans.sql
  Purpose: Consolidated foreign key orphan + currency/date coverage checks for raw.Sales.
  Output: One row per test with pass/fail metadata.
  Tests Implemented:
    1) FK: Sales.CustomerKey -> Customers.CustomerKey
    2) FK: Sales.ProductKey  -> Products.ProductKey
    3) FK: Sales.StoreKey    -> Stores.StoreKey
    4) Coverage: Sales (Currency_Code, Order_Date) -> Exchange_Rates (Currency, Date)
*/

IF OBJECT_ID('tempdb..#results') IS NOT NULL DROP TABLE #results;
CREATE TABLE #results
(
  scope sysname NOT NULL,
  test_name nvarchar(200) NOT NULL,
  status nvarchar(10) NOT NULL,
  fail_count int NOT NULL,
  sample_offenders nvarchar(max) NULL
);

DECLARE @fail_count int, @sample nvarchar(max), @status nvarchar(10);

/* Working offenders table (reused) */
IF OBJECT_ID('tempdb..#offenders') IS NOT NULL DROP TABLE #offenders;
CREATE TABLE #offenders
(
  key1 sql_variant NULL,
  key2 sql_variant NULL
);

/* Test 1: FK Sales -> Customers */
TRUNCATE TABLE #offenders;
INSERT INTO #offenders
  (key1)
SELECT DISTINCT s.CustomerKey
FROM raw.Sales s
WHERE NOT EXISTS (
  SELECT 1
FROM raw.Customers c
WHERE c.CustomerKey = s.CustomerKey
);
SELECT @fail_count = COUNT(*)
FROM #offenders;
SELECT @sample = STRING_AGG(CONVERT(nvarchar(100), key1), ', ')
FROM (SELECT TOP (5)
    key1
  FROM #offenders
  ORDER BY key1) d;

SET @status = CASE WHEN @fail_count = 0 THEN N'PASS' ELSE N'FAIL' END;
INSERT INTO #results
  (scope, test_name, status, fail_count, sample_offenders)
VALUES(N'raw.Sales', N'FK: Sales.CustomerKey -> Customers.CustomerKey', @status, @fail_count, @sample);

/* Test 2: FK Sales -> Products */
SET @fail_count = 0;
SET @sample = NULL;
SET @status = NULL;
TRUNCATE TABLE #offenders;
INSERT INTO #offenders
  (key1)
SELECT DISTINCT s.ProductKey
FROM raw.Sales s
WHERE NOT EXISTS (
  SELECT 1
FROM raw.Products p
WHERE p.ProductKey = s.ProductKey
);
SELECT @fail_count = COUNT(*)
FROM #offenders;
SELECT @sample = STRING_AGG(CONVERT(nvarchar(100), key1), ', ')
FROM (SELECT TOP (5)
    key1
  FROM #offenders
  ORDER BY key1) d;

SET @status = CASE WHEN @fail_count = 0 THEN N'PASS' ELSE N'FAIL' END;
INSERT INTO #results
  (scope, test_name, status, fail_count, sample_offenders)
VALUES(N'raw.Sales', N'FK: Sales.ProductKey -> Products.ProductKey', @status, @fail_count, @sample);

/* Test 3: FK Sales -> Stores */
SET @fail_count = 0;
SET @sample = NULL;
SET @status = NULL;
TRUNCATE TABLE #offenders;
INSERT INTO #offenders
  (key1)
SELECT DISTINCT s.StoreKey
FROM raw.Sales s
WHERE NOT EXISTS (
  SELECT 1
FROM raw.Stores st
WHERE st.StoreKey = s.StoreKey
);
SELECT @fail_count = COUNT(*)
FROM #offenders;
SELECT @sample = STRING_AGG(CONVERT(nvarchar(100), key1), ', ')
FROM (SELECT TOP (5)
    key1
  FROM #offenders
  ORDER BY key1) d;

SET @status = CASE WHEN @fail_count = 0 THEN N'PASS' ELSE N'FAIL' END;
INSERT INTO #results
  (scope, test_name, status, fail_count, sample_offenders)
VALUES(N'raw.Sales', N'FK: Sales.StoreKey -> Stores.StoreKey', @status, @fail_count, @sample);

/* Test 4: Coverage Sales (Currency_Code, Order_Date) -> Exchange_Rates (Currency, Date) */
SET @fail_count = 0;
SET @sample = NULL;
SET @status = NULL;
TRUNCATE TABLE #offenders;
INSERT INTO #offenders
  (key1, key2)
SELECT DISTINCT s.Currency_Code, CAST(s.Order_Date AS date) AS Order_Date
FROM raw.Sales s
WHERE NOT EXISTS (
  SELECT 1
FROM raw.Exchange_Rates r
WHERE r.Currency = s.Currency_Code
  AND r.[Date] = CAST(s.Order_Date AS date)
);
SELECT @fail_count = COUNT(*)
FROM #offenders;
SELECT @sample = STRING_AGG(
  CASE WHEN key2 IS NULL THEN CONVERT(nvarchar(100), key1)
       ELSE CONVERT(nvarchar(100), key1) + N'|' + CONVERT(varchar(10), CONVERT(date, key2), 120) END, ', ')
FROM (SELECT TOP (5)
    *
  FROM #offenders
  ORDER BY key1, key2) d;

SET @status = CASE WHEN @fail_count = 0 THEN N'PASS' ELSE N'FAIL' END;
INSERT INTO #results
  (scope, test_name, status, fail_count, sample_offenders)
VALUES(N'raw.Sales', N'Coverage: Sales.(Currency_Code, Order_Date) -> Exchange_Rates.(Currency, Date)', @status, @fail_count, @sample);

/* Final Output */
SELECT *
FROM #results
ORDER BY status DESC, fail_count DESC, test_name;
