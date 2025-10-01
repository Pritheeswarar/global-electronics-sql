/*
View: stage.v_products
Grain: One row per product (product_key)
Source: raw.Products synonym
Purpose: Standardize naming, apply trimming, explicit typing. No filtering or derivations.
*/

USE [Global_Electronics];
GO

CREATE OR ALTER VIEW stage.v_products
AS
  SELECT
    CAST(ProductKey AS smallint)                              AS product_key, -- natural key
    CAST(LTRIM(RTRIM(Product_Name)) AS nvarchar(255))         AS product_name, -- trimmed name
    CAST(LTRIM(RTRIM(Brand)) AS nvarchar(100))                AS brand, -- trimmed brand
    CAST(LTRIM(RTRIM(Category)) AS nvarchar(100))             AS category, -- trimmed category
    CAST(LTRIM(RTRIM(Subcategory)) AS nvarchar(100))          AS subcategory, -- trimmed subcategory
    CAST(Unit_Price_USD AS money)                             AS unit_price_usd, -- price USD
    CAST(Unit_Cost_USD AS money)                              AS unit_cost_usd
  -- nullable cost
  FROM raw.Products;
GO

-- Sanity checks
SELECT TOP (5)
  *
FROM stage.v_products;
SELECT COUNT_BIG(*) AS row_count,
  COUNT(DISTINCT product_key) AS distinct_product_keys
FROM stage.v_products;
