# Modeling Notes — Global Electronics

## Source Summary (raw schema via synonyms)

- Sales: 62,884 rows; columns observed → Order_Number, Line_Item, Order_Date, Delivery_Date (nullable), CustomerKey, ProductKey, StoreKey, Quantity, Currency_Code
- Products: 2,517 rows; → ProductKey, Product_Name, Brand, Category, Subcategory, Unit_Price_USD, Unit_Cost_USD (nullable)
- Customers: 15,266 rows; → CustomerKey (other attrs omitted here)
- Stores: 67 rows; → StoreKey, State, Country, Open_Date, Square_Meters (nullable)
- Exchange_Rates: 11,215 rows; → Currency, Date, Exchange

## Grains (row meaning)

- **Fact: Sales lines** — grain = one product line per order  
	Key = (Order_Number, Line_Item).  
	Time columns = Order_Date (required), Delivery_Date (nullable).
- **Dims**  
	- dim_product: ProductKey  
	- dim_customer: CustomerKey  
	- dim_store: StoreKey (geo via State/Country)  
	- dim_calendar: derived from dates in facts (later, as helper view)

## Status & Scope Rules (v1)

- Include **all rows** in raw.Sales (no returns/cancellations table present in v1).
- Delivery analyses only consider rows where **Delivery_Date IS NOT NULL**.
- Currency: Unit prices are provided in **USD** in Products; v1 revenue is in USD without conversion. Exchange_Rates retained for validation and optional v2 local-currency analysis.

## Conformed Dimensions (join rules)

- Sales.ProductKey → Products.ProductKey (inner join for product-enriched views)
- Sales.StoreKey → Stores.StoreKey (left join allowed for inventory; inner join for marts)
- Sales.CustomerKey → Customers.CustomerKey (left join allowed for customer-enriched views)

## KPI Glossary (precise)

- **Orders**  
	Definition: `COUNT(DISTINCT Sales.Order_Number)` across the filtered row set.  
	Grain: order header implied from line-level fact.

- **Units Sold**  
	Definition: `SUM(Sales.Quantity)`.

- **Revenue_USD (gross)**  
	Definition: `SUM(Sales.Quantity * Products.Unit_Price_USD)` using inner join to Products.  
	Notes: excludes taxes/discounts (not present in raw).

- **COGS_USD (if needed)**  
	Definition: `SUM(Sales.Quantity * Products.Unit_Cost_USD)` ignoring NULL costs (treat as 0).  
	Notes: v1 optional.

- **AOV_USD (Average Order Value)**  
	Definition: `Revenue_USD / COUNT(DISTINCT Sales.Order_Number)` over the same filter context.  
	Scope: completed orders only is **not** enforced in v1 (no status field).

- **Delivery_Days**  
	Definition: `DATEDIFF(DAY, Sales.Order_Date, Sales.Delivery_Date)` for rows with Delivery_Date NOT NULL.  
	Aggregates: AVG_Delivery_Days, P90_Delivery_Days to be computed in marts.

- **Active SKUs**  
	Definition: `COUNT(DISTINCT Sales.ProductKey)` in a period.

## Segmentations (used across marts)

- **Geo**: Store → (State, Country).  
- **Time**: Order_Date calendar rollups (day/week/month/YOY).  
- **Product**: Category, Subcategory, Brand.

## Exclusions / Edge Cases

- Delivery_Days only when Delivery_Date >= Order_Date (already tested).  
- Square_Meters is nullable; do not filter Stores based on it.  
- Currency_Code remains validated but not used in v1 revenue math.

## Naming Conventions (computed columns)

- Use lower_snake_case in views.
- Examples:
	- `line_revenue_usd = Quantity * Unit_Price_USD`
	- `delivery_days = DATEDIFF(day, Order_Date, Delivery_Date)`
	- `order_month = CAST(DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1) AS date)`

## Open Questions (parked for v2)

- Channel segmentation: none in raw; if an Online “store” exists (e.g., StoreKey=0), confirm before deriving a channel dim.
- Discounts/taxes not modeled; add if additional fields are provided.
