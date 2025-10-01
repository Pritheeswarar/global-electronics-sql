/*
Purpose: Accepted values & reasonableness checks across Sales, Products, Stores.
Result shape: scope, test_name, status, fail_count, sample_offenders
Severity encoded in test_name (Major/Minor) for now.
*/

USE [Global_Electronics];
GO

IF OBJECT_ID('tempdb..#results') IS NOT NULL DROP TABLE #results;
CREATE TABLE #results
(
  scope sysname,
  test_name nvarchar(200),
  status nvarchar(10),
  fail_count int,
  sample_offenders nvarchar(max)
);

/* Helper inline pattern: Insert a result row */
-- status = PASS when fail_count = 0 else FAIL

/* 1) Sales.Currency_Code format (Major) */
WITH
  bad
  AS
  (
    SELECT Currency_Code
    FROM raw.Sales
    WHERE Currency_Code IS NULL OR LEN(Currency_Code) <> 3
  )
INSERT #results
  (scope, test_name, status, fail_count, sample_offenders)
SELECT 'raw.Sales' AS scope,
  'Format (Major): Sales.Currency_Code LEN=3 & NOT NULL' AS test_name,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
  COUNT(*) AS fail_count,
  CASE WHEN COUNT(*) = 0 THEN NULL ELSE (
            SELECT STRING_AGG(x.sample, ', ')
  FROM (
                SELECT TOP (5)
      COALESCE(NULLIF(Currency_Code,''), 'NULL') AS sample
    FROM bad
    GROUP BY Currency_Code
    ORDER BY sample
            ) x
       ) END AS sample_offenders
FROM bad;

/* 2) Sales.Currency_Code in Exchange_Rates (Major) */
WITH
  missing
  AS
  (
    SELECT DISTINCT s.Currency_Code
    FROM raw.Sales s
    WHERE s.Currency_Code IS NOT NULL
      AND NOT EXISTS (
            SELECT 1
      FROM raw.Exchange_Rates r
      WHERE r.Currency = s.Currency_Code)
  )
INSERT #results
  (scope, test_name, status, fail_count, sample_offenders)
SELECT 'raw.Sales',
  'Accepted Values (Major): Sales.Currency_Code in Exchange_Rates',
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
  COUNT(*),
  CASE WHEN COUNT(*) = 0 THEN NULL ELSE (
            SELECT STRING_AGG(x.Currency_Code, ', ')
  FROM (
                SELECT TOP (5)
      Currency_Code
    FROM missing
    ORDER BY Currency_Code
            ) x
       ) END
FROM missing;

/* 3) Sales.Quantity bounds (Major) */
WITH
  bad
  AS
  (
    SELECT Order_Number, Quantity
    FROM raw.Sales
    WHERE Quantity < 1 OR Quantity > 10
  )
INSERT #results
  (scope, test_name, status, fail_count, sample_offenders)
SELECT 'raw.Sales',
  'Bounds (Major): Sales.Quantity BETWEEN 1 AND 10',
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
  COUNT(*),
  CASE WHEN COUNT(*) = 0 THEN NULL ELSE (
            SELECT STRING_AGG(x.sample, ', ')
  FROM (
                SELECT TOP (5)
      CONCAT(CAST(Order_Number AS nvarchar(50)),'|Q=',CAST(Quantity AS nvarchar(20))) AS sample
    FROM bad
    ORDER BY sample
            ) x
       ) END
FROM bad;

/* 4) Sales.Delivery_Date >= Order_Date when Delivery_Date IS NOT NULL (Major) */
WITH
  bad
  AS
  (
    SELECT Order_Number, Order_Date, Delivery_Date
    FROM raw.Sales
    WHERE Delivery_Date IS NOT NULL
      AND Delivery_Date < Order_Date
  )
INSERT #results
  (scope, test_name, status, fail_count, sample_offenders)
SELECT 'raw.Sales',
  'Temporal (Major): Delivery_Date >= Order_Date',
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
  COUNT(*),
  CASE WHEN COUNT(*) = 0 THEN NULL ELSE (
            SELECT STRING_AGG(x.sample, ', ')
  FROM (
                SELECT TOP (5)
      CONCAT(CAST(Order_Number AS nvarchar(50)),'|',CONVERT(char(10), Order_Date, 23),'|',CONVERT(char(10), Delivery_Date,23)) AS sample
    FROM bad
    ORDER BY sample
            ) x
       ) END
FROM bad;

/* 5) Products.Unit_Price_USD non-negative (Major) */
WITH
  bad
  AS
  (
    SELECT ProductKey
    FROM raw.Products
    WHERE Unit_Price_USD < 0
  )
INSERT #results
  (scope, test_name, status, fail_count, sample_offenders)
SELECT 'raw.Products',
  'Non-Negative (Major): Products.Unit_Price_USD >= 0',
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
  COUNT(*),
  CASE WHEN COUNT(*) = 0 THEN NULL ELSE (
            SELECT STRING_AGG(x.ProductKey, ', ')
  FROM (
                SELECT TOP (5)
      CAST(ProductKey AS nvarchar(20)) AS ProductKey
    FROM bad
    ORDER BY ProductKey
            ) x
       ) END
FROM bad;

/* 6) Products.Unit_Cost_USD non-negative when not NULL (Major) */
WITH
  bad
  AS
  (
    SELECT ProductKey
    FROM raw.Products
    WHERE Unit_Cost_USD IS NOT NULL AND Unit_Cost_USD < 0
  )
INSERT #results
  (scope, test_name, status, fail_count, sample_offenders)
SELECT 'raw.Products',
  'Non-Negative (Major): Products.Unit_Cost_USD >= 0 OR NULL',
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
  COUNT(*),
  CASE WHEN COUNT(*) = 0 THEN NULL ELSE (
            SELECT STRING_AGG(x.ProductKey, ', ')
  FROM (
                SELECT TOP (5)
      CAST(ProductKey AS nvarchar(20)) AS ProductKey
    FROM bad
    ORDER BY ProductKey
            ) x
       ) END
FROM bad;

/* 7) Price vs Cost sanity (Minor) */
WITH
  bad
  AS
  (
    SELECT ProductKey, Unit_Price_USD, Unit_Cost_USD
    FROM raw.Products
    WHERE Unit_Price_USD IS NOT NULL
      AND Unit_Cost_USD IS NOT NULL
      AND Unit_Price_USD < Unit_Cost_USD
  )
INSERT #results
  (scope, test_name, status, fail_count, sample_offenders)
SELECT 'raw.Products',
  'Relation (Minor): Unit_Price_USD >= Unit_Cost_USD',
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
  COUNT(*),
  CASE WHEN COUNT(*) = 0 THEN NULL ELSE (
            SELECT STRING_AGG(x.sample, ', ')
  FROM (
                SELECT TOP (5)
      CONCAT(CAST(ProductKey AS nvarchar(20)),'|P=',CAST(Unit_Price_USD AS nvarchar(20)),'|C=',CAST(Unit_Cost_USD AS nvarchar(20))) AS sample
    FROM bad
    ORDER BY sample
            ) x
       ) END
FROM bad;

/* 8) Stores.Square_Meters positive when not NULL (Major) */
WITH
  bad
  AS
  (
    SELECT StoreKey
    FROM raw.Stores
    WHERE Square_Meters IS NOT NULL AND Square_Meters <= 0
  )
INSERT #results
  (scope, test_name, status, fail_count, sample_offenders)
SELECT 'raw.Stores',
  'Positive (Major): Stores.Square_Meters > 0 OR NULL',
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
  COUNT(*),
  CASE WHEN COUNT(*) = 0 THEN NULL ELSE (
            SELECT STRING_AGG(x.StoreKey, ', ')
  FROM (
                SELECT TOP (5)
      CAST(StoreKey AS nvarchar(20)) AS StoreKey
    FROM bad
    ORDER BY StoreKey
            ) x
       ) END
FROM bad;

SELECT *
FROM #results
ORDER BY status DESC, fail_count DESC, test_name;
