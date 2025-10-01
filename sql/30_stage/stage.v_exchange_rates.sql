/*
View: stage.v_exchange_rates
Grain: One row per (currency, rate_date)
Purpose: Standardize currency code case/whitespace; type dates/rates. No gap filling.
*/

USE [Global_Electronics];
GO

CREATE OR ALTER VIEW stage.v_exchange_rates
AS
  SELECT
    CAST(UPPER(LTRIM(RTRIM(Currency))) AS nvarchar(3)) AS currency, -- ISO code normalized
    CAST([Date] AS date)                               AS rate_date, -- calendar date
    CAST([Exchange] AS float)                          AS exchange_rate
  -- raw value (direction per source)
  FROM raw.Exchange_Rates;
GO

-- Sanity checks
SELECT TOP (5)
  *
FROM stage.v_exchange_rates;
SELECT COUNT_BIG(*) AS row_count,
  COUNT(DISTINCT currency) AS distinct_currencies,
  MIN(rate_date) AS min_date,
  MAX(rate_date) AS max_date
FROM stage.v_exchange_rates;
