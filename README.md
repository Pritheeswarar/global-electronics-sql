# Global Electronics — SQL Analytics (Maven dataset)

Goal: reproducible SQL project answering questions on product mix, seasonality, delivery speed, and AOV by channel/region.
Architecture: one database global_electronics with schemas raw (source), stage (cleaned views), marts (analysis views).
Repo map: /sql/00_init (setup), /sql/10_inventory (profiling), /sql/20_tests (later), docs listed below.
How to run (later): we'll add exact steps after setup.

## Highlights

- **Data model:** raw ➜ stage ➜ marts with idempotent views and a documented semantic layer.
- **Data quality:** uniqueness, FK/coverage, value/temporal checks — all PASS in raw layer.
- **Scale:** 26,326 orders • 197,757 units • $55.76M revenue • AOV $2,117.89 (USD).
- **Top geos:** US leads ($23.76M), Online channel strong ($11.40M).
- **Categories:** Computers (34.6%) and Home Appliances (19.4%) drive most revenue.
- **Delivery:** Weighted avg 3–4 days; p90 ~6–7 days; partial final month explains some NULLs.
- **One-stop KPIs:** `marts.v_kpi_overview_monthly` for orders, revenue, AOV, and delivery quality by month & geography.
