/* ===== Deploy all marts (create or alter) ===== */
USE [Global_Electronics];
GO

IF NOT EXISTS (SELECT 1
FROM sys.schemas
WHERE name = 'marts') EXEC('CREATE SCHEMA marts;');
GO

/* 1) Enriched lines: sales + product + store */
CREATE OR ALTER VIEW marts.v_sales_enriched
AS
  SELECT
    sl.order_number,
    sl.line_item,
    sl.order_date,
    sl.delivery_date,
    sl.customer_key,
    sl.product_key,
    sl.store_key,
    sl.quantity,
    sl.currency_code,
    p.product_name,
    p.brand,
    p.category,
    p.subcategory,
    st.state,
    st.country,
    line_revenue_usd = CAST(sl.quantity * p.unit_price_usd AS decimal(18, 2))
  FROM stage.v_sales_lines AS sl
    JOIN stage.v_products     AS p ON p.product_key = sl.product_key
    JOIN stage.v_stores       AS st ON st.store_key  = sl.store_key;
GO

/* 2) Daily geo rollup */
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

/* 3) Monthly delivery KPIs by geo (avg & p90 days) */
CREATE OR ALTER VIEW marts.v_delivery_stats_geo_monthly
AS
  WITH
    delivered
    AS
    (
      SELECT
        order_month   = CAST(DATEFROMPARTS(YEAR(se.order_date), MONTH(se.order_date), 1) AS date),
        se.country,
        se.state,
        delivery_days = DATEDIFF(DAY, se.order_date, se.delivery_date)
      FROM marts.v_sales_enriched se
      WHERE se.delivery_date IS NOT NULL
    ),
    win
    AS
    (
      SELECT
        order_month, country, state, delivery_days,
        delivered_lines   = COUNT(*) OVER (PARTITION BY order_month, country, state),
        avg_delivery_days = AVG(CAST(delivery_days AS decimal(10,2))) OVER (PARTITION BY order_month, country, state),
        p90_delivery_days = PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY delivery_days)
                          OVER (PARTITION BY order_month, country, state)
      FROM delivered
    )
  SELECT DISTINCT order_month, country, state, delivered_lines, avg_delivery_days, p90_delivery_days
  FROM win;
GO

/* 4) Top products per month */
CREATE OR ALTER VIEW marts.v_top_products_monthly
AS
  WITH
    base
    AS
    (
      SELECT
        order_month = CAST(DATEFROMPARTS(YEAR(se.order_date), MONTH(se.order_date), 1) AS date),
        se.product_key,
        se.product_name,
        se.brand,
        se.category,
        se.subcategory,
        se.quantity,
        se.line_revenue_usd
      FROM marts.v_sales_enriched se
    ),
    agg
    AS
    (
      SELECT
        order_month,
        product_key,
        product_name,
        brand,
        category,
        subcategory,
        units_sold  = SUM(quantity),
        revenue_usd = SUM(line_revenue_usd)
      FROM base
      GROUP BY order_month, product_key, product_name, brand, category, subcategory
    )
  SELECT
    order_month, product_key, product_name, brand, category, subcategory,
    units_sold, revenue_usd,
    rank_in_month = DENSE_RANK() OVER (PARTITION BY order_month ORDER BY revenue_usd DESC)
  FROM agg;
GO

/* 5) AOV by month & geo */
CREATE OR ALTER VIEW marts.v_aov_monthly_geo
AS
  WITH line_level AS (
    SELECT
      order_month = CAST(DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS date),
      country,
      state,
      order_number,
      line_revenue_usd
    FROM marts.v_sales_enriched
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

/* 6) KPI overview */
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

/* ===== Verification outputs ===== */

/* List marts views */
SELECT name AS view_name
FROM sys.views
WHERE schema_id = SCHEMA_ID('marts')
ORDER BY name;

/* Row counts */
  SELECT 'marts.v_sales_enriched' AS view_name, COUNT_BIG(*) AS row_count
  FROM marts.v_sales_enriched
UNION ALL
  SELECT 'marts.v_sales_daily_geo', COUNT_BIG(*)
  FROM marts.v_sales_daily_geo
UNION ALL
  SELECT 'marts.v_delivery_stats_geo_monthly', COUNT_BIG(*)
  FROM marts.v_delivery_stats_geo_monthly
UNION ALL
  SELECT 'marts.v_top_products_monthly', COUNT_BIG(*)
  FROM marts.v_top_products_monthly
UNION ALL
  SELECT 'marts.v_aov_monthly_geo', COUNT_BIG(*)
  FROM marts.v_aov_monthly_geo
UNION ALL
  SELECT 'marts.v_kpi_overview_monthly', COUNT_BIG(*)
  FROM marts.v_kpi_overview_monthly;

/* Spot check #1 (daily orders preserved in daily_geo) */
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
  picked_date = d.order_date,
  orders_src = (
    SELECT COUNT(DISTINCT se.order_number)
  FROM marts.v_sales_enriched se CROSS APPLY d
  WHERE se.order_date = d.order_date
  ),
  orders_rollup = (
    SELECT SUM(g.orders)
  FROM marts.v_sales_daily_geo g CROSS APPLY d
  WHERE g.order_date = d.order_date
  )
FROM d;

/* Spot check #2 (delivered line counts preserved in monthly delivery view) */
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
  FROM marts.v_sales_enriched se CROSS APPLY m
  WHERE se.delivery_date IS NOT NULL
    AND DATEFROMPARTS(YEAR(se.order_date), MONTH(se.order_date), 1) = m.order_month
  ),
  delivered_rollup = (
    SELECT SUM(delivered_lines)
  FROM marts.v_delivery_stats_geo_monthly v CROSS APPLY m
  WHERE v.order_month = m.order_month
  )
FROM m;
GO
