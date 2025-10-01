USE [Global_Electronics];
GO

/*
View: marts.v_kpi_overview_monthly
Grain: (order_month, country, state)
Purpose: Consolidated KPI table drawing from existing marts and recomputed delivery coverage metrics.
KPIs:
  orders, revenue_usd, aov_usd,
  total_lines, delivered_lines, delivered_orders,
  delivery_line_rate, delivery_order_rate,
  avg_delivery_days, p90_delivery_days
*/

CREATE OR ALTER VIEW marts.v_kpi_overview_monthly
AS
  WITH line_level AS (
    SELECT
      order_month = CAST(DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS date),
      country,
      state,
      order_number,
      delivery_date
    FROM marts.v_sales_enriched
  ), line_rollup AS (
    SELECT
      order_month,
      country,
      state,
      total_lines     = COUNT(*),
      delivered_lines = SUM(CASE WHEN delivery_date IS NOT NULL THEN 1 ELSE 0 END)
    FROM line_level
    GROUP BY order_month, country, state
  ), delivered_order_rollup AS (
    SELECT
      order_month,
      country,
      state,
      delivered_orders = COUNT(*)
    FROM (
      SELECT DISTINCT order_month, country, state, order_number
      FROM line_level
      WHERE delivery_date IS NOT NULL
    ) AS dedup
    GROUP BY order_month, country, state
  )
  SELECT
    a.order_month,
    a.country,
    a.state,
    a.orders,
    a.revenue_usd,
    a.aov_usd,
    l.total_lines,
    l.delivered_lines,
    o.delivered_orders,
    delivery_line_rate  = CAST(1.0 * l.delivered_lines / NULLIF(l.total_lines, 0) AS decimal(6, 4)),
    delivery_order_rate = CAST(1.0 * o.delivered_orders / NULLIF(a.orders, 0)    AS decimal(6, 4)),
    d.avg_delivery_days,
    d.p90_delivery_days
  FROM marts.v_aov_monthly_geo AS a
    LEFT JOIN line_rollup            AS l ON l.order_month = a.order_month AND l.country = a.country AND l.state = a.state
    LEFT JOIN delivered_order_rollup AS o ON o.order_month = a.order_month AND o.country = a.country AND o.state = a.state
    LEFT JOIN marts.v_delivery_stats_geo_monthly AS d
      ON d.order_month = a.order_month AND d.country = a.country AND d.state = a.state;
GO
