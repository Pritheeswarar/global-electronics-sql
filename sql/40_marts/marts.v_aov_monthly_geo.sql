USE [Global_Electronics];
GO

/*
View: marts.v_aov_monthly_geo
Purpose: Average order value by month and geography.
Grain: one row per (order_month, country, state)
Metrics:
  - orders: count of distinct orders
  - revenue_usd: sum of line_revenue_usd
  - aov_usd: revenue_usd / NULLIF(orders, 0)
*/

CREATE OR ALTER VIEW marts.v_aov_monthly_geo
AS
  WITH line_level AS (
    SELECT
      order_month = CAST(DATEFROMPARTS(YEAR(se.order_date), MONTH(se.order_date), 1) AS date),
      se.country,
      se.state,
      se.order_number,
      se.line_revenue_usd
    FROM marts.v_sales_enriched AS se
  ), order_dedupe AS (
    SELECT DISTINCT order_month, country, state, order_number
    FROM line_level
  ), revenue_rollup AS (
    SELECT
      order_month,
      country,
      state,
      revenue_usd = SUM(line_revenue_usd)
    FROM line_level
    GROUP BY order_month, country, state
  )
  SELECT
    r.order_month,
    r.country,
    r.state,
    orders      = o.orders,
    r.revenue_usd,
    aov_usd     = CAST(r.revenue_usd / NULLIF(o.orders, 0) AS decimal(18, 2))
  FROM revenue_rollup AS r
    LEFT JOIN (
      SELECT order_month, country, state, orders = COUNT(*)
      FROM order_dedupe
      GROUP BY order_month, country, state
    ) AS o ON  o.order_month = r.order_month
          AND o.country     = r.country
          AND o.state       = r.state;
GO
