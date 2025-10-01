USE [Global_Electronics];
GO

/*
View: marts.v_top_products_monthly
Purpose: Summarize product performance by month with revenue-based rank.
Grain: one row per (order_month, product_key)
Metrics:
  - units_sold: sum of quantity
  - revenue_usd: sum of line_revenue_usd
  - rank_in_month: dense rank by revenue_usd descending within each month
*/

CREATE OR ALTER VIEW marts.v_top_products_monthly
AS
  WITH line_level AS (
    SELECT
      order_month = CAST(DATEFROMPARTS(YEAR(se.order_date), MONTH(se.order_date), 1) AS date),
      se.product_key,
      se.product_name,
      se.brand,
      se.category,
      se.subcategory,
      se.quantity,
      se.line_revenue_usd
    FROM marts.v_sales_enriched AS se
  ), rollup AS (
    SELECT
      order_month,
      product_key,
      product_name,
      brand,
      category,
      subcategory,
      units_sold  = SUM(quantity),
      revenue_usd = SUM(line_revenue_usd)
    FROM line_level
    GROUP BY order_month, product_key, product_name, brand, category, subcategory
  )
  SELECT
    order_month,
    product_key,
    product_name,
    brand,
    category,
    subcategory,
    units_sold,
    revenue_usd,
    rank_in_month = DENSE_RANK() OVER (PARTITION BY order_month ORDER BY revenue_usd DESC)
  FROM rollup;
GO
