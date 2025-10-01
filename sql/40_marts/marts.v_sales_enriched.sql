USE [Global_Electronics];
GO

/*
View: marts.v_sales_enriched
Purpose: Enrich line-level sales with product & store attributes and compute line_revenue_usd.
Contract Columns (exact order):
	order_number, line_item, order_date, delivery_date,
	customer_key, product_key, store_key, quantity, currency_code,
	product_name, brand, category, subcategory,
	state, country,
	line_revenue_usd
Rules:
	- Inner joins (stage.v_products, stage.v_stores) must not drop rows (validated by row count check)
	- No DISTINCT or filters.
*/

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
    INNER JOIN stage.v_products AS p ON p.product_key = sl.product_key
    INNER JOIN stage.v_stores   AS st ON st.store_key   = sl.store_key;
GO

-- Post-create sanity checks
SELECT TOP (5)
  *
FROM marts.v_sales_enriched;
SELECT COUNT_BIG(*) AS rows_enriched
FROM marts.v_sales_enriched;
SELECT COUNT_BIG(*) AS rows_stage_sales
FROM stage.v_sales_lines; -- Expect match
