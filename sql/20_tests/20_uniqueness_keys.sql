USE [Global_Electronics];
GO

/*
  Purpose: Consolidated uniqueness checks for raw schema key candidates.
  Tables & Keys:
    1) raw.Sales            -> (Order_Number, Line_Item)
    2) raw.Customers        -> (CustomerKey)
    3) raw.Products         -> (ProductKey)
    4) raw.Stores           -> (StoreKey)
    5) raw.Exchange_Rates   -> (Currency, Date)
  Output: One row per test with PASS/FAIL and sample duplicate key values.
*/

IF OBJECT_ID('tempdb..#results') IS NOT NULL DROP TABLE #results;
CREATE TABLE #results
(
  scope sysname NOT NULL,
  test_name nvarchar(200) NOT NULL,
  status nvarchar(10) NOT NULL,
  fail_count int NULL,
  sample_offenders nvarchar(max) NULL
);

/* Working table for duplicates */
IF OBJECT_ID('tempdb..#dup') IS NOT NULL DROP TABLE #dup;
CREATE TABLE #dup
(
  key1 sql_variant NULL,
  key2 sql_variant NULL,
  cnt int NOT NULL
);

/* Helper variables */
DECLARE @scope sysname, @test_name nvarchar(200), @status nvarchar(10), @fail_count int, @sample nvarchar(max);

/* Test 1: raw.Sales (Order_Number, Line_Item) */
TRUNCATE TABLE #dup;
INSERT INTO #dup
  (key1, key2, cnt)
SELECT Order_Number, Line_Item, COUNT(*)
FROM raw.Sales
GROUP BY Order_Number, Line_Item
HAVING COUNT(*) > 1;

SELECT @fail_count = COUNT(*)
FROM #dup;
SELECT @sample = STRING_AGG(CASE WHEN key2 IS NULL THEN CONVERT(nvarchar(100), key1) ELSE CONVERT(nvarchar(100), key1)+N':' + CONVERT(nvarchar(100), key2) END, ', ')
FROM (
  SELECT TOP (5)
    *
  FROM #dup
  ORDER BY cnt DESC, key1, key2
) s;

SET @scope = N'raw.Sales';
SET @test_name = N'Uniqueness: (Order_Number, Line_Item)';
SET @status = CASE WHEN @fail_count = 0 THEN N'PASS' ELSE N'FAIL' END;
INSERT INTO #results
VALUES
  (@scope, @test_name, @status, @fail_count, @sample);

/* Reset vars */
SET @fail_count = NULL;
SET @sample = NULL;

/* Test 2: raw.Customers (CustomerKey) */
TRUNCATE TABLE #dup;
INSERT INTO #dup
  (key1, key2, cnt)
SELECT CustomerKey, NULL, COUNT(*)
FROM raw.Customers
GROUP BY CustomerKey
HAVING COUNT(*) > 1;

SELECT @fail_count = COUNT(*)
FROM #dup;
SELECT @sample = STRING_AGG(CONVERT(nvarchar(100), key1), ', ')
FROM (
  SELECT TOP (5)
    *
  FROM #dup
  ORDER BY cnt DESC, key1
) s;

SET @scope = N'raw.Customers';
SET @test_name = N'Uniqueness: (CustomerKey)';
SET @status = CASE WHEN @fail_count = 0 THEN N'PASS' ELSE N'FAIL' END;
INSERT INTO #results
VALUES
  (@scope, @test_name, @status, @fail_count, @sample);

SET @fail_count = NULL;
SET @sample = NULL;

/* Test 3: raw.Products (ProductKey) */
TRUNCATE TABLE #dup;
INSERT INTO #dup
  (key1, key2, cnt)
SELECT ProductKey, NULL, COUNT(*)
FROM raw.Products
GROUP BY ProductKey
HAVING COUNT(*) > 1;

SELECT @fail_count = COUNT(*)
FROM #dup;
SELECT @sample = STRING_AGG(CONVERT(nvarchar(100), key1), ', ')
FROM (
  SELECT TOP (5)
    *
  FROM #dup
  ORDER BY cnt DESC, key1
) s;

SET @scope = N'raw.Products';
SET @test_name = N'Uniqueness: (ProductKey)';
SET @status = CASE WHEN @fail_count = 0 THEN N'PASS' ELSE N'FAIL' END;
INSERT INTO #results
VALUES
  (@scope, @test_name, @status, @fail_count, @sample);

SET @fail_count = NULL;
SET @sample = NULL;

/* Test 4: raw.Stores (StoreKey) */
TRUNCATE TABLE #dup;
INSERT INTO #dup
  (key1, key2, cnt)
SELECT StoreKey, NULL, COUNT(*)
FROM raw.Stores
GROUP BY StoreKey
HAVING COUNT(*) > 1;

SELECT @fail_count = COUNT(*)
FROM #dup;
SELECT @sample = STRING_AGG(CONVERT(nvarchar(100), key1), ', ')
FROM (
  SELECT TOP (5)
    *
  FROM #dup
  ORDER BY cnt DESC, key1
) s;

SET @scope = N'raw.Stores';
SET @test_name = N'Uniqueness: (StoreKey)';
SET @status = CASE WHEN @fail_count = 0 THEN N'PASS' ELSE N'FAIL' END;
INSERT INTO #results
VALUES
  (@scope, @test_name, @status, @fail_count, @sample);

SET @fail_count = NULL;
SET @sample = NULL;

/* Test 5: raw.Exchange_Rates (Currency, Date) */
TRUNCATE TABLE #dup;
INSERT INTO #dup
  (key1, key2, cnt)
SELECT Currency, [Date], COUNT(*)
FROM raw.Exchange_Rates
GROUP BY Currency, [Date]
HAVING COUNT(*) > 1;

SELECT @fail_count = COUNT(*)
FROM #dup;
SELECT @sample = STRING_AGG(CASE WHEN key2 IS NULL THEN CONVERT(nvarchar(100), key1) ELSE CONVERT(nvarchar(100), key1)+N':' + CONVERT(nvarchar(100), key2) END, ', ')
FROM (
  SELECT TOP (5)
    *
  FROM #dup
  ORDER BY cnt DESC, key1, key2
) s;

SET @scope = N'raw.Exchange_Rates';
SET @test_name = N'Uniqueness: (Currency, Date)';
SET @status = CASE WHEN @fail_count = 0 THEN N'PASS' ELSE N'FAIL' END;
INSERT INTO #results
VALUES
  (@scope, @test_name, @status, @fail_count, @sample);

/* Final output */
SELECT *
FROM #results
ORDER BY status DESC, fail_count DESC, scope;
