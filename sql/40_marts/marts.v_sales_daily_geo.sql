USE [Global_Electronics];
GO

/*
View: marts.v_sales_daily_geo
Purpose: Daily rollup for orders, units, revenue, and active SKU counts by order_date, country, state, category.
Grain: one row per (order_date, country, state, category)
Derivations:
	- orders: COUNT DISTINCT orders at the group grain
	- units_sold: SUM(quantity)
	- revenue_usd: SUM(line_revenue_usd)
	- active_skus: COUNT DISTINCT product_key
Rules:
	- No filters; preserve all dates/categories present in enriched lines.
	- Work from marts.v_sales_enriched only.
*/

CREATE OR ALTER VIEW marts.v_sales_daily_geo
AS
  WITH base AS (
    SELECT
      se.order_date,
      se.country,
      se.state,
      se.category,
      se.order_number,
      se.product_key,
      se.quantity,
      se.line_revenue_usd
    FROM marts.v_sales_enriched AS se
  ), order_dedupe AS (
    SELECT DISTINCT order_date, country, state, category, order_number
    FROM base
  ), sku_dedupe AS (
    SELECT DISTINCT order_date, country, state, category, product_key
    FROM base
  ), agg_lines AS (
    SELECT
      order_date,
      country,
      state,
      category,
      units_sold  = SUM(quantity),
      revenue_usd = SUM(line_revenue_usd)
    FROM base
    GROUP BY order_date, country, state, category
  )
  SELECT
    a.order_date,
    a.country,
    a.state,
    a.category,
    orders      = o.orders,
    units_sold  = a.units_sold,
    revenue_usd = a.revenue_usd,
    active_skus = s.active_skus
  FROM agg_lines AS a
    LEFT JOIN (
      SELECT order_date, country, state, category, orders = COUNT(*)
      FROM order_dedupe
      GROUP BY order_date, country, state, category
    ) AS o ON  o.order_date = a.order_date
          AND o.country    = a.country
          AND o.state      = a.state
          AND o.category   = a.category
    LEFT JOIN (
      SELECT order_date, country, state, category, active_skus = COUNT(*)
      FROM sku_dedupe
      GROUP BY order_date, country, state, category
    ) AS s ON  s.order_date = a.order_date
          AND s.country    = a.country
          AND s.state      = a.state
          AND s.category   = a.category;
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
