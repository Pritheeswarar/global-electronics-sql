USE [Global_Electronics];
GO

/*
View: marts.v_delivery_stats_geo_monthly
Purpose: Delivery-time KPIs by month and geography.
Grain: one row per (order_month, country, state)
Metrics:
  - delivered_lines: count of delivered order lines
  - avg_delivery_days: average days between order and delivery
  - p90_delivery_days: 90th percentile of delivery time
Filters:
  - delivery_date is not null
*/

CREATE OR ALTER VIEW marts.v_delivery_stats_geo_monthly
AS
  WITH delivered AS (
    SELECT
      order_month   = CAST(DATEFROMPARTS(YEAR(se.order_date), MONTH(se.order_date), 1) AS date),
      se.country,
      se.state,
      delivery_days = DATEDIFF(DAY, se.order_date, se.delivery_date)
    FROM marts.v_sales_enriched AS se
    WHERE se.delivery_date IS NOT NULL
  ), metrics AS (
    SELECT
      order_month,
      country,
      state,
      delivered_lines   = COUNT(*) OVER (PARTITION BY order_month, country, state),
      avg_delivery_days = AVG(CAST(delivery_days AS decimal(10, 2))) OVER (PARTITION BY order_month, country, state),
      p90_delivery_days = PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY delivery_days)
                          OVER (PARTITION BY order_month, country, state)
    FROM delivered
  )
  SELECT DISTINCT
    order_month,
    country,
    state,
    delivered_lines,
    avg_delivery_days,
    p90_delivery_days
  FROM metrics;
GO
