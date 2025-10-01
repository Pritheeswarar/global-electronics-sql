# Semantic Layer — View Contracts (v1)

## Principles

- One database: Global_Electronics. Schemas: raw (source), stage (cleaned/typed), marts (analysis).
- Naming: lower_snake_case for view columns. No business logic in raw; minimal cleanup in stage; metrics/rollups in marts.
- Keys respected from MODEL_NOTES. All joins to products/stores/customers must use inner joins unless specified.


---

## STAGE VIEWS (row-level, near-raw)

### stage.v_sales_lines

**Grain:** one product line per order (Order_Number, Line_Item)  
**Depends on:** raw.Sales  
**Columns (exact names):**

- order_number (int)
- line_item (tinyint)
- order_date (date)
- delivery_date (date, nullable)
- customer_key (int)
- product_key (smallint)
- store_key (tinyint)
- quantity (tinyint)
- currency_code (nvarchar(3))
**Rules:**
- Cast/rename raw columns to the above names.
- Keep all rows; no filters here.
- Validate delivery_date >= order_date where not null (already tested) but do not drop rows.

### Build log — stage.v_sales_lines

- Compiled: ✅
- Sample columns: order_number, line_item, order_date, delivery_date, customer_key, product_key, store_key, quantity, currency_code
- Row count: 62884


### stage.v_products

**Grain:** one row per product  
**Depends on:** raw.Products  
**Columns:**

- product_key (smallint)
- product_name (nvarchar)
- brand (nvarchar)
- category (nvarchar)
- subcategory (nvarchar)
- unit_price_usd (money)
- unit_cost_usd (money, nullable)
**Rules:** direct rename/cast only.

### Build log — stage.v_products

- Compiled: ✅
- Columns: product_key, product_name, brand, category, subcategory, unit_price_usd, unit_cost_usd
- Row count: 2517 | Distinct product_key: 2517


### stage.v_customers

**Grain:** one row per customer  
**Depends on:** raw.Customers  
**Columns (include what exists; do not invent):**

- customer_key (int)
- name (nvarchar, if present)
- gender (nvarchar, if present)
- city (nvarchar, if present)
- state_code (nvarchar, if present)
- country (nvarchar, if present)
**Rules:** pass-through/rename only; optional columns allowed.

### Build log — stage.v_customers

- Compiled: ✅
- Columns: customer_key, name, gender, city, state_code, state, country, birthdate
- Row count: 15266 | Distinct customer_key: 15266


### stage.v_stores

**Grain:** one row per store  
**Depends on:** raw.Stores  
**Columns:**

- store_key (tinyint)
- state (nvarchar)
- country (nvarchar)
- open_date (date)
- square_meters (smallint, nullable)

### Build log — stage.v_stores

- Compiled: ✅
- Columns: store_key, state, country, open_date, square_meters
- Row count: 67 | Distinct store_key: 67


### stage.v_exchange_rates

**Grain:** one row per (currency, date)  
**Depends on:** raw.Exchange_Rates  
**Columns:**

- currency (nvarchar(3))
- rate_date (date)   -- normalized name for raw "Date"
- exchange_rate (float)  -- raw "Exchange" as-is (direction left as dataset-defined)
**Rules:** rename/cast only. No filling gaps.

### Build log — stage.v_exchange_rates

- Compiled: ✅
- Columns: currency, rate_date, exchange_rate
- Row count: 11215 | Distinct currencies: 5 | Date span: 2015-01-01 → 2021-02-20


---

## MARTS (analysis-ready; joins + derived columns)

 
### marts.v_sales_enriched

**Purpose:** Enrich line-level sales with product & store attributes and simple derived fields.  
**Grain:** one line per order (same as stage.v_sales_lines)  
**Depends on:** stage.v_sales_lines, stage.v_products, stage.v_stores  
**Columns:**

- order_number, line_item, order_date, delivery_date
- customer_key, product_key, store_key, quantity, currency_code
- product_name, brand, category, subcategory
- state, country
- line_revenue_usd (computed: quantity * unit_price_usd)
**Join Rules:** inner join to products and stores (drop unmatched).

 
### marts.v_sales_daily_geo

**Purpose:** Daily rollup for sales by geography & product category.  
**Grain:** one row per (order_date, country, state, category)  
**Depends on:** marts.v_sales_enriched  
**Columns:**

- order_date
- country, state
- category
- orders (count distinct order_number)
- units_sold (sum quantity)
- revenue_usd (sum line_revenue_usd)
- active_skus (count distinct product_key)

 
### marts.v_delivery_stats_geo_monthly

**Purpose:** Delivery-time KPIs for delivered lines.  
**Grain:** one row per (order_month, country, state)  
**Depends on:** marts.v_sales_enriched  
**Columns:**

- order_month (date = first day of month from order_date)
- country, state
- delivered_lines (count where delivery_date is not null)
- avg_delivery_days (avg of datediff day)
- p90_delivery_days (approx_percentile or window method; if not available, use PERCENTILE_CONT)
**Filters:** delivery_date is not null.

 
### marts.v_top_products_monthly

**Purpose:** Product performance per month.  
**Grain:** one row per (order_month, product_key)  
**Depends on:** marts.v_sales_enriched  
**Columns:**

- order_month
- product_key, product_name, brand, category, subcategory
- units_sold (sum)
- revenue_usd (sum)
- rank_in_month (dense_rank by revenue_usd desc partition by order_month)

 
### marts.v_aov_monthly_geo

**Purpose:** AOV by month and geography.  
**Grain:** one row per (order_month, country, state)  
**Depends on:** marts.v_sales_enriched  
**Columns:**

- order_month
- country, state
- orders (count distinct order_number)
- revenue_usd (sum line_revenue_usd)
- aov_usd (revenue_usd / NULLIF(orders,0))

---

 
## Acceptance Criteria

- All stage views compile and return rows (no filters that drop data).
- All marts compile; joins to products/stores are inner to enforce conformance.
- Column names/types exactly as specified.
- No business logic beyond stated derivations (e.g., line_revenue_usd, order_month).
- Query times reasonable on provided dataset (< 3s per view on a typical laptop).

 
## Implementation Order (next tasks)

1) Build stage.v_sales_lines
2) Build stage.v_products
3) Build stage.v_stores
4) Build stage.v_customers
5) Build stage.v_exchange_rates
6) Build marts.v_sales_enriched
7) Build marts.v_sales_daily_geo
8) Build marts.v_delivery_stats_geo_monthly
9) Build marts.v_top_products_monthly
10) Build marts.v_aov_monthly_geo

---
