/*
View: stage.v_stores
Grain: One row per store (store_key)
Source: raw.Stores synonym
Purpose: Standardize naming, trimming, typing. No filtering.
*/

USE [Global_Electronics];
GO

CREATE OR ALTER VIEW stage.v_stores
AS
  SELECT
    CAST(StoreKey AS tinyint)                         AS store_key, -- natural key
    CAST(LTRIM(RTRIM(State)) AS nvarchar(100))        AS state, -- state/region
    CAST(LTRIM(RTRIM(Country)) AS nvarchar(100))      AS country, -- country
    CAST(Open_Date AS date)                           AS open_date, -- store open date
    CAST(Square_Meters AS smallint)                   AS square_meters
  -- nullable size
  FROM raw.Stores;
GO

-- Sanity checks
SELECT TOP (5)
  *
FROM stage.v_stores;
SELECT COUNT_BIG(*) AS row_count,
  COUNT(DISTINCT store_key) AS distinct_store_keys
FROM stage.v_stores;
