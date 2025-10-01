# Data Quality Test Plan — Global Electronics (SQL Server)

## Purpose

Codify the minimum quality bar for analyses built from the Maven Global Electronics dataset. These rules guide our stage/marts views and will be automated later.

## Severity Rubric

- **Blocker**: Fail stops the pipeline; fix before proceeding.
- **Major**: Allowed temporarily; must be tracked and remediated before release.
- **Minor**: Informational; does not block.

## Global Assumptions

- Source tables are accessed via `raw.*` synonyms.
- Dates are local to the dataset (no timezone conversion in v1).
- Currency codes follow ISO-4217 (3 letters). Exchange rates exist by day per currency.

---

## Table: raw.Sales

Profile recap: 62,884 rows; 5 currency codes; `Delivery_Date` ~79% NULL.

### Sales Tests

1) **Uniqueness (Blocker)**  
   - Candidate key: `(Order_Number, Line_Item)` is unique.

2) **Not Null (Blocker)**  
   - `Order_Number`, `Order_Date`, `CustomerKey`, `ProductKey`, `StoreKey`, `Quantity`, `Currency_Code` are NOT NULL.

3) **Foreign Keys (Blocker)**  
   - `CustomerKey` exists in `raw.Customers(CustomerKey)`.  
   - `ProductKey` exists in `raw.Products(ProductKey)`.  
   - `StoreKey` exists in `raw.Stores(StoreKey)`.

4) **Accepted Values (Major)**  
   - `Currency_Code` ∈ {distinct 3-letter codes from `raw.Exchange_Rates.Currency`}.

5) **Reasonableness (Major)**  
   - `Quantity` BETWEEN 1 AND 10 (based on profile mins/max).  
   - If `Delivery_Date` IS NOT NULL, then `Delivery_Date >= Order_Date`.

6) **Coverage (Major)**  
   - For every `Sales` row, there exists an exchange rate for (`Currency_Code`, `Order_Date`) in `raw.Exchange_Rates`.

---

## Table: raw.Customers

### Customer Tests

1) **Uniqueness (Blocker)**: `CustomerKey` unique.  
2) **Not Null (Blocker)**: `CustomerKey` NOT NULL.  
3) **Basic Completeness (Major)**: Key attributes (e.g., name/city/state columns if present) have NULL% < 20%.  
4) **Cardinality sanity (Minor)**: Distinct `CustomerKey` ~= row_count.

---

## Table: raw.Products

Profile recap: No high-null columns; prices/costs plausible.

### Product Tests

1) **Uniqueness (Blocker)**: `ProductKey` unique.  
2) **Not Null (Blocker)**: `ProductKey`, `Product_Name`, `Category`, `Subcategory` NOT NULL.  
3) **Reasonableness (Major)**:  
   - `Unit_Price_USD >= 0`.  
   - `Unit_Cost_USD >= 0` (NULLs allowed per profile).  
4) **Hierarchy Integrity (Minor)**: `CategoryKey` and `SubcategoryKey` present; (FKs to lookup tables deferred if not provided).

---

## Table: raw.Stores

Profile recap: 67 rows; `StoreKey` looks like a primary key.

### Exchange Rate Tests

1) **Uniqueness (Blocker)**: `StoreKey` unique.  
2) **Not Null (Blocker)**: `StoreKey`, `State`, `Country`, `Open_Date` NOT NULL.  
3) **Reasonableness (Major)**: `Square_Meters > 0` (NULL allowed per profile).  
4) **Temporal Logic (Minor)**: For joined sales, `Open_Date <= Order_Date` (informational).

---

## Table: raw.Exchange_Rates

Profile recap: 5 distinct currencies; dates 2015-01-01 → 2021-02-20; exchange > 0.

### Tests

1) **Composite Uniqueness (Blocker)**: `(Currency, Date)` is unique.  
2) **Not Null (Blocker)**: `Currency`, `Date`, `Exchange` NOT NULL.  
3) **Format & Range (Major)**:  
   - `LEN(Currency) = 3`.  
   - `Exchange > 0`.  
4) **Coverage (Major)**: For date span of `raw.Sales.Order_Date`, each `Currency` has rates for every day present in Sales (allow weekends/holidays only if Sales has no rows those days).

---

## Cross-Table Consistency

1) **Sales ↔ Exchange Rates (Blocker)**:  
   - Every `raw.Sales (Currency_Code, Order_Date)` pair exists in `raw.Exchange_Rates (Currency, Date)`.

2) **Sales ↔ Dimension Keys (Blocker)**:  
   - No orphan `CustomerKey`, `ProductKey`, `StoreKey`.

---

## Reporting & Remediation

- Log test results with counts of failures and sample offenders (top 10).  
- Blocker failures stop downstream view creation.  
- Track Major issues in a backlog; add fixes or exclusions to staging views with rationale comments.

---

## Notes / Open Questions

- Confirm if `Delivery_Date` nulls indicate in-store pickup or missing shipments; adjust reasonableness rules accordingly.  
- Confirm any additional status fields (if present) to refine inclusions/exclusions for KPI calculations.

---

## Run log — Uniqueness tests

| scope | test_name | status | fail_count | sample_offenders |
|-------|-----------|--------|------------|------------------|
| raw.Customers | Uniqueness: (CustomerKey) | PASS | 0 |  |
| raw.Exchange_Rates | Uniqueness: (Currency, Date) | PASS | 0 |  |
| raw.Products | Uniqueness: (ProductKey) | PASS | 0 |  |
| raw.Sales | Uniqueness: (Order_Number, Line_Item) | PASS | 0 |  |
| raw.Stores | Uniqueness: (StoreKey) | PASS | 0 |  |

## Run log — FK orphan checks

| scope | test_name | status | fail_count | sample_offenders |
|-------|-----------|--------|------------|------------------|
| raw.Sales | Coverage: Sales.(Currency_Code, Order_Date) -> Exchange_Rates.(Currency, Date) | PASS | 0 |  |
| raw.Sales | FK: Sales.CustomerKey -> Customers.CustomerKey | PASS | 0 |  |
| raw.Sales | FK: Sales.ProductKey -> Products.ProductKey | PASS | 0 |  |
| raw.Sales | FK: Sales.StoreKey -> Stores.StoreKey | PASS | 0 |  |

## Run log — Values & reasonableness checks

| scope | test_name | status | fail_count | sample_offenders |
|-------|-----------|--------|------------|------------------|
| raw.Sales | Accepted Values (Major): Sales.Currency_Code in Exchange_Rates | PASS | 0 |  |
| raw.Sales | Bounds (Major): Sales.Quantity BETWEEN 1 AND 10 | PASS | 0 |  |
| raw.Sales | Format (Major): Sales.Currency_Code LEN=3 & NOT NULL | PASS | 0 |  |
| raw.Products | Non-Negative (Major): Products.Unit_Cost_USD >= 0 OR NULL | PASS | 0 |  |
| raw.Products | Non-Negative (Major): Products.Unit_Price_USD >= 0 | PASS | 0 |  |
| raw.Stores | Positive (Major): Stores.Square_Meters > 0 OR NULL | PASS | 0 |  |
| raw.Products | Relation (Minor): Unit_Price_USD >= Unit_Cost_USD | PASS | 0 |  |
| raw.Sales | Temporal (Major): Delivery_Date >= Order_Date | PASS | 0 |  |

