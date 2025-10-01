USE [Global_Electronics];
GO

/*
View: marts.v_delivery_stats_geo_monthly
Purpose: Month-level delivery KPIs (delivered line count, average and 90th percentile delivery days) by geography.
Grain: one row per (order_month, country, state)
Notes:
  - delivery_days = DATEDIFF(DAY, order_date, delivery_date)
  - PERCENTILE_CONT(0.9) used for p90_delivery_days via window function.
  - DISTINCT applied only in final projection to deduplicate window-expanded rows.
*/

CREATE OR ALTER VIEW marts.v_delivery_stats_geo_monthly
AS
  WITH
    delivered
    AS
    (
      SELECT
        se.order_date,
        se.delivery_date,
        se.country,
        se.state,
        delivery_days = DATEDIFF(DAY, se.order_date, se.delivery_date)
      FROM marts.v_sales_enriched AS se
      WHERE se.delivery_date IS NOT NULL
    ),
    base
    AS
    (
      SELECT
        order_month = CAST(DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS date),
        country,
        state,
        delivery_days
      FROM delivered
    ),
    scored
    AS
    (
      SELECT
        order_month,
        country,
        state,
        delivery_days,
        avg_delivery_days = AVG(CAST(delivery_days AS decimal(10,2))) OVER (PARTITION BY order_month, country, state),
        p90_delivery_days = PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY delivery_days) OVER (PARTITION BY order_month, country, state)
      FROM base
    )
  SELECT DISTINCT
    order_month,
    country,
    state,
    delivered_lines = COUNT(*) OVER (PARTITION BY order_month, country, state),
    avg_delivery_days,
    p90_delivery_days
  FROM scored;
GO

-- Post-create sanity checks
SELECT TOP (5)
  *
FROM marts.v_delivery_stats_geo_monthly
ORDER BY order_month DESC, country, state;

;WITH
  m
  AS
  (
    SELECT TOP 1
      CAST(DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS date) AS order_month
    FROM marts.v_sales_enriched
    WHERE delivery_date IS NOT NULL
    ORDER BY NEWID()
  )
SELECT
  picked_month = m.order_month,
  delivered_src = (
		SELECT COUNT(*)
  FROM marts.v_sales_enriched se
		CROSS APPLY m
  WHERE se.delivery_date IS NOT NULL
    AND DATEFROMPARTS(YEAR(se.order_date), MONTH(se.order_date), 1) = m.order_month
	),
  delivered_rollup = (
		SELECT SUM(delivered_lines)
  FROM marts.v_delivery_stats_geo_monthly v
		CROSS APPLY m
  WHERE v.order_month = m.order_month
	)
FROM m;

