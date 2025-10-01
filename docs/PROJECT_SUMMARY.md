# Project Summary — Global Electronics SQL Analytics (Maven Analytics)

**TL;DR**

- Production-style **raw → stage → marts** semantic layer in SQL Server, fully documented.

- Data quality suite: **uniqueness**, **FK/coverage**, **value & temporal checks** — all **PASS**.
- Reusable marts published for daily trends, AOV, delivery KPIs, top products, plus a **one-stop monthly KPI view**.
- Scale (entire period): **26,326 orders • 197,757 units • $55,755,479.59 revenue • AOV $2,117.89** (USD).
- Delivery performance (most geos): **avg ~3–4 days**, **p90 ~6–7 days**.

---

## Dataset & Coverage

- Source: Maven Analytics “Global Electronics”.
- Date span (orders): **2016-01-01 → 2021-02-20**.
- Currency: mixed at source; marts report in **USD** (per catalog price).

---

## Architecture & Conventions

- **raw**: `raw.*` **synonyms** point to already-loaded tables in `dbo` (no data movement).
- **stage**: thin, idempotent **views** (naming, typing, harmless fixes).
- **marts**: business-ready **views** for analysis & reporting.
- Naming: `snake_case` columns; schemas: `raw`, `stage`, `marts`.
- Source control: VS Code workspace with `/sql` modules and `/docs` markdown.

```
/sql
/00_init          -- schemas, synonyms
/10_inventory     -- profiling & tests
/30_stage         -- stage views
/40_marts         -- marts views (+ deploy script)
/docs
INSIGHTS.md       -- analysis findings (tables from live queries)
PROJECT_SUMMARY.md -- this file
SEMANTIC_LAYER.md -- per-object build logs

````

---

## Semantic Layer Objects (row counts from your SQL Server)

| Schema | Object | Rows | Notes |
|---|---|---:|---|
| stage | v_sales_lines | **62,884** | Sales lines normalized (dates/currency kept as-is) |
| stage | v_products | **2,517** | Catalog (price & cost in USD) |
| stage | v_stores | **67** | Store geo, size, open_date |
| stage | v_customers | **15,266** | Basic demographics/geo |
| stage | v_exchange_rates | **11,215** | 2015-01-01 → 2021-02-20 |
| marts | v_sales_enriched | **62,884** | Sales + product + geo + line_revenue_usd |
| marts | v_sales_daily_geo | **45,807** | Daily by (country, state, category) |
| marts | v_delivery_stats_geo_monthly | **62** | Monthly delivered_lines, avg, p90 |
| marts | v_top_products_monthly | **39,212** | Top products per month (rank_in_month) |
| marts | v_aov_monthly_geo | **2,944** | Orders, revenue, **AOV** by month/geo |
| marts | v_kpi_overview_monthly | **2,944** | Consolidated KPIs (orders, revenue, AOV, delivery rates & speed) |

---

## Data Quality Summary (all PASS)

- **Uniqueness:**  
  - Customers(CustomerKey), Products(ProductKey), Stores(StoreKey),  
    Sales(Order_Number, Line_Item), Exchange_Rates(Currency, Date).
- **FK / Coverage:**  
  - Sales → Customers/Products/Stores;  
  - (Currency_Code, Order_Date) → Exchange_Rates(Currency, Date).
- **Values & Temporal:**  
  - Quantity ∈ [1,10]; non-negative prices; Delivery_Date ≥ Order_Date (where present).  
  - Note: `Delivery_Date` is intentionally sparse in source (many orders unfulfilled in-period).

---

## Key Business Results

- **Scale:** 26,326 orders • 197,757 units • **$55.76M** revenue • **AOV $2,117.89**.
- **Top geos (lifetime revenue):** US (~$23.76M), **Online** (~$11.40M), UK, DE, CA.
- **Categories (share of revenue):** Computers **34.6%**, Home Appliances **19.4%**, Cameras **11.7%**.
- **Delivery:** weighted **avg 3–4 days**, **p90 ~6–7 days**; partial final month explains some NULLs.

---

## How to Use the Marts (SSMS)

- Daily geo trend:
```sql
SELECT order_date, country, state, category, orders, units_sold, revenue_usd
FROM marts.v_sales_daily_geo
WHERE order_date >= DATEADD(MONTH,-3,CAST(GETDATE() AS date))
ORDER BY order_date DESC, revenue_usd DESC;
````

* Monthly KPI (latest):

```sql
DECLARE @m date = (SELECT MAX(order_month) FROM marts.v_kpi_overview_monthly);
SELECT *
FROM marts.v_kpi_overview_monthly
WHERE order_month = @m
ORDER BY revenue_usd DESC;
```

* Top products (latest month):

```sql
SELECT *
FROM marts.v_top_products_monthly
WHERE order_month = (SELECT MAX(order_month) FROM marts.v_top_products_monthly)
ORDER BY rank_in_month;
```

---

## What’s Next (Backlog)

* Currency-normalized revenue using `v_exchange_rates` for historical FX.
* Channel split (Online vs. Store) if/when provided.
* Lightweight CI: lint + compile + row-count checks on PR.
* Optional indexing on base tables to accelerate heavy joins.

---

## Credits & Tools

* Dataset: **Maven Analytics — Global Electronics**.
* Stack: **SQL Server**, VS Code, Git/GitHub.
* Authoring principle: small, idempotent steps; test-first data quality; documented marts.
