/*
View: stage.v_customers
Grain: One row per customer (customer_key)
Source: raw.Customers synonym (underlying dbo.Customers)
Included Columns: CustomerKey, Gender, Name, City, State_Code, State, Country, Birthday (Zip_Code, Continent excluded v1)
Purpose: Standardize naming, trimming, typing. No filters or derivations.
*/

USE [Global_Electronics];
GO

CREATE OR ALTER VIEW stage.v_customers
AS
  SELECT
    CAST(CustomerKey AS int)                              AS customer_key, -- natural key
    CAST(LTRIM(RTRIM(Name)) AS nvarchar(200))             AS name, -- trimmed name
    CAST(LTRIM(RTRIM(Gender)) AS nvarchar(20))            AS gender, -- trimmed gender
    CAST(LTRIM(RTRIM(City)) AS nvarchar(100))             AS city, -- city
    CAST(LTRIM(RTRIM(State_Code)) AS nvarchar(10))        AS state_code, -- state code
    CAST(LTRIM(RTRIM(State)) AS nvarchar(100))            AS state, -- state name
    CAST(LTRIM(RTRIM(Country)) AS nvarchar(100))          AS country, -- country
    CAST(Birthday AS date)                                AS birthdate
  -- date of birth
  FROM raw.Customers;
GO

-- Sanity checks
SELECT TOP (5)
  *
FROM stage.v_customers;
SELECT COUNT_BIG(*) AS row_count,
  COUNT(DISTINCT customer_key) AS distinct_customer_keys
FROM stage.v_customers;
