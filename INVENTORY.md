# Inventory

## Row counts (raw schema)

| object_name | row_count |
|---|---|
| raw.Customers | 15,266 |
| raw.Exchange_Rates | 11,215 |
| raw.Products | 2,517 |
| raw.Sales | 62,884 |
| raw.Stores | 67 |

## Column profile — raw.Sales

| column_name | data_type | is_nullable | row_count | nulls | null_pct | distinct_count | min_value | max_value | avg_len | max_len |
|-------------|-----------|-------------|-----------|-------|----------|----------------|-----------|-----------|---------|---------|
| Currency_Code | nvarchar | 0 | 62,884 | 0 | 0.00 | 5 |  |  | 3.00 | 3 |
| CustomerKey | int | 0 | 62,884 | 0 | 0.00 | 11,887 | 301.0000000000 | 2,099,937.0000000000 |  |  |
| Delivery_Date | date | 1 | 62,884 | 49,719 | 79.06 | 1,492 | 2016-01-06 00:00:00 | 2021-02-27 00:00:00 |  |  |
| Line_Item | tinyint | 0 | 62,884 | 0 | 0.00 | 7 | 1.0000000000 | 7.0000000000 |  |  |
| Order_Date | date | 0 | 62,884 | 0 | 0.00 | 1,641 | 2016-01-01 00:00:00 | 2021-02-20 00:00:00 |  |  |
| Order_Number | int | 0 | 62,884 | 0 | 0.00 | 26,326 | 366,000.0000000000 | 2,243,032.0000000000 |  |  |
| ProductKey | smallint | 0 | 62,884 | 0 | 0.00 | 2,492 | 1.0000000000 | 2,517.0000000000 |  |  |
| Quantity | tinyint | 0 | 62,884 | 0 | 0.00 | 10 | 1.0000000000 | 10.0000000000 |  |  |
| StoreKey | tinyint | 0 | 62,884 | 0 | 0.00 | 58 | 0.0000000000 | 66.0000000000 |  |  |

## Column profile — raw.Customers

| column_name | data_type | is_nullable | row_count | nulls | null_pct | distinct_count | min_value | max_value | avg_len | max_len |
|-------------|-----------|-------------|-----------|-------|----------|----------------|-----------|-----------|---------|---------|
| Birthday | date | 0 | 15,266 | 0 | 0.00 | 11,270 | 1935-02-03 00:00:00 | 2002-02-18 00:00:00 |  |  |
| City | nvarchar | 0 | 15,266 | 0 | 0.00 | 8,258 |  |  | 9.23 | 36 |
| Continent | nvarchar | 0 | 15,266 | 0 | 0.00 | 3 |  |  | 10.12 | 13 |
| Country | nvarchar | 0 | 15,266 | 0 | 0.00 | 8 |  |  | 10.72 | 14 |
| CustomerKey | int | 0 | 15,266 | 0 | 0.00 | 15,266 | 301.0000000000 | 2,099,937.0000000000 |  |  |
| Gender | nvarchar | 0 | 15,266 | 0 | 0.00 | 2 |  |  | 4.98 | 6 |
| Name | nvarchar | 0 | 15,266 | 0 | 0.00 | 15,118 |  |  | 13.37 | 27 |
| State | nvarchar | 0 | 15,266 | 0 | 0.00 | 512 |  |  | 10.08 | 28 |
| State_Code | nvarchar | 0 | 15,266 | 0 | 0.00 | 468 |  |  | 3.18 | 28 |
| Zip_Code | nvarchar | 1 | 15,266 | 0 | 0.00 | 9,505 |  |  | 5.48 | 8 |
