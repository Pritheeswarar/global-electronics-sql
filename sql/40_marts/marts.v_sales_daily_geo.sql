USE [Global_Electronics];
GO

/*
View: marts.v_sales_daily_geo
Purpose: Daily rollup for orders, units, revenue, and active SKU counts by order_date, country, state, category.
Grain: one row per (order_date, country, state, category)
Derivations:
	- orders: COUNT(DISTINCT order_number)
	- units_sold: SUM(quantity)
	- revenue_usd: SUM(line_revenue_usd)
	- active_skus: COUNT(DISTINCT product_key)
Rules:
	- No filters; preserve all dates/categories present in enriched lines.
	- No DISTINCT outside aggregate functions.
*/

CREATE OR ALTER VIEW marts.v_sales_daily_geo
AS
  SELECT
    se.order_date,
    se.country,
    se.state,
    se.category,
    orders      = COUNT(DISTINCT se.order_number),
    units_sold  = SUM(se.quantity),
    revenue_usd = SUM(se.line_revenue_usd),
    active_skus = COUNT(DISTINCT se.product_key)
  FROM marts.v_sales_enriched AS se
  GROUP BY se.order_date, se.country, se.state, se.category;
GO

-- Post-create sanity checks
SELECT TOP (5)
  *
FROM marts.v_sales_daily_geo
ORDER BY order_date DESC, country, state, category;

;WITH
  d
  AS
  (
    SELECT TOP 1
      order_date
    FROM marts.v_sales_enriched
    ORDER BY NEWID()
  )
SELECT
  orders_src = (
			SELECT COUNT(DISTINCT se.order_number)
  FROM marts.v_sales_enriched se
			CROSS APPLY d
  WHERE se.order_date = d.order_date
	),
  orders_rollup = (
			SELECT SUM(g.orders)
  FROM marts.v_sales_daily_geo g
			CROSS APPLY d
  WHERE g.order_date = d.order_date
	);

-- Row count for documentation
SELECT COUNT(*) AS rows_daily_geo
FROM marts.v_sales_daily_geo;
