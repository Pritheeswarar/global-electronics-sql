/*
View: stage.v_sales_lines
Grain: One row per sales line (order_number, line_item)
Source: raw.Sales synonym
Purpose: Type / rename raw columns; no filtering, no business logic beyond light trimming + upper on currency.
Non-goals: No surrogate keys, no joins, no row exclusion.
*/

USE [Global_Electronics];
GO

CREATE OR ALTER VIEW stage.v_sales_lines
AS
  SELECT
    CAST(Order_Number AS int)                          AS order_number, -- PK part 1
    CAST(Line_Item AS tinyint)                         AS line_item, -- PK part 2
    CAST(Order_Date AS date)                           AS order_date, -- required order date
    CAST(Delivery_Date AS date)                        AS delivery_date, -- nullable delivery date
    CAST(CustomerKey AS int)                           AS customer_key, -- FK to customers
    CAST(ProductKey AS smallint)                       AS product_key, -- FK to products
    CAST(StoreKey AS tinyint)                          AS store_key, -- FK to stores
    CAST(Quantity AS tinyint)                          AS quantity, -- ordered quantity
    CAST(UPPER(LTRIM(RTRIM(Currency_Code))) AS nvarchar(3)) AS currency_code
  -- normalized currency code
  FROM raw.Sales;
GO

-- Sanity checks
SELECT TOP (5)
  *
FROM stage.v_sales_lines;
SELECT COUNT_BIG(*) AS row_count
FROM stage.v_sales_lines;
