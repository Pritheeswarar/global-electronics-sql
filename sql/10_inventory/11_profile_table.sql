USE [Global_Electronics];  -- change if needed

DECLARE @schema sysname = N'raw';
DECLARE @table  sysname = N'Sales';   -- <<< EDIT to the table you want to profile
DECLARE @full   nvarchar(400) = QUOTENAME(@schema) + N'.' + QUOTENAME(@table);

IF OBJECT_ID('tempdb..#profile') IS NOT NULL DROP TABLE #profile;
CREATE TABLE #profile (
  column_name   sysname,
  data_type     nvarchar(128),
  is_nullable   bit,
  row_count     bigint,
  nulls         bigint,
  null_pct      decimal(5,2),
  distinct_count bigint,
  min_value     sql_variant NULL,
  max_value     sql_variant NULL,
  avg_len       decimal(10,2) NULL,
  max_len       int NULL
);

/* iterate columns and compute null%, distincts, min/max (for numeric/date),
   and length stats for strings. Works for synonyms or real tables. */
DECLARE @col sysname, @dtype nvarchar(128), @nullable bit, @sql nvarchar(max);

DECLARE c CURSOR FAST_FORWARD FOR
SELECT c.name, t.name AS dtype, c.is_nullable
FROM sys.columns c
JOIN sys.types   t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(@full)
ORDER BY c.column_id;

OPEN c;
FETCH NEXT FROM c INTO @col, @dtype, @nullable;

WHILE @@FETCH_STATUS = 0
BEGIN
  DECLARE @agg nvarchar(max) = N'NULL AS min_value, NULL AS max_value, NULL AS avg_len, NULL AS max_len';

  IF @dtype IN ('int','bigint','smallint','tinyint','decimal','numeric','float','real','money','smallmoney')
    SET @agg = N'
      MIN(CAST(' + QUOTENAME(@col) + N' AS decimal(38,10))) AS min_value,
      MAX(CAST(' + QUOTENAME(@col) + N' AS decimal(38,10))) AS max_value,
      NULL AS avg_len, NULL AS max_len';

  IF @dtype IN ('date','datetime','datetime2','smalldatetime','datetimeoffset','time')
    SET @agg = N'
      MIN(CAST(' + QUOTENAME(@col) + N' AS datetime2)) AS min_value,
      MAX(CAST(' + QUOTENAME(@col) + N' AS datetime2)) AS max_value,
      NULL AS avg_len, NULL AS max_len';

  IF @dtype IN ('varchar','nvarchar','char','nchar','text','ntext')
    SET @agg = N'
      NULL AS min_value, NULL AS max_value,
      AVG(CASE WHEN ' + QUOTENAME(@col) + N' IS NULL THEN NULL ELSE LEN(' + QUOTENAME(@col) + N') * 1.0 END) AS avg_len,
      MAX(LEN(' + QUOTENAME(@col) + N')) AS max_len';

  SET @sql = N'
    SELECT
      N''' + @col + N''' AS column_name,
      N''' + @dtype + N''' AS data_type,
      ' + CAST(@nullable AS nvarchar(1)) + N' AS is_nullable,
      COUNT_BIG(*) AS row_count,
      SUM(CASE WHEN ' + QUOTENAME(@col) + N' IS NULL THEN 1 ELSE 0 END) AS nulls,
      CAST(100.0 * SUM(CASE WHEN ' + QUOTENAME(@col) + N' IS NULL THEN 1 ELSE 0 END) / NULLIF(COUNT_BIG(*),0) AS decimal(5,2)) AS null_pct,
      COUNT(DISTINCT ' + QUOTENAME(@col) + N') AS distinct_count,
      ' + @agg + N'
    FROM ' + @full + N';';

  INSERT INTO #profile
  EXEC sp_executesql @sql;

  FETCH NEXT FROM c INTO @col, @dtype, @nullable;
END

CLOSE c; DEALLOCATE c;

SELECT *
FROM #profile
ORDER BY column_name;