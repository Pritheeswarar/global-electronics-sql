USE [Global_Electronics];
-- change if needed

/* Base inputs */
DECLARE @schema sysname = N'raw';
DECLARE @table  sysname = N'Customers';
-- <<< EDIT to the table you want to profile
DECLARE @full   nvarchar(400) = QUOTENAME(@schema) + N'.' + QUOTENAME(@table);

/* Resolve underlying object if @full is a synonym (so we can enumerate columns) */
DECLARE @base_db sysname, @base_schema sysname, @base_object sysname, @base_threepart nvarchar(400);

SELECT TOP 1
  @base_threepart = syn.base_object_name
FROM sys.synonyms syn
  JOIN sys.schemas s ON s.schema_id = syn.schema_id
WHERE s.name = @schema
  AND syn.name = @table;

IF @base_threepart IS NOT NULL
BEGIN
  /* Expect formats like [db].[schema].[object] or db.schema.object */
  DECLARE @work nvarchar(400) = REPLACE(REPLACE(@base_threepart, '[',''),']','');
  DECLARE @p1 int = CHARINDEX('.', @work);
  DECLARE @p2 int = CHARINDEX('.', @work, @p1 + 1);
  IF @p1 > 0 AND @p2 > 0
  BEGIN
    SET @base_db     = SUBSTRING(@work, 1, @p1 - 1);
    SET @base_schema = SUBSTRING(@work, @p1 + 1, @p2 - @p1 - 1);
    SET @base_object = SUBSTRING(@work, @p2 + 1, LEN(@work) - @p2);
  END
END

/* If not a synonym, treat the original reference as the base */
IF @base_object IS NULL
BEGIN
  SET @base_db = DB_NAME();
  SET @base_schema = @schema;
  SET @base_object = @table;
END

DECLARE @base_object_id int = OBJECT_ID(QUOTENAME(@base_db) + '.' + QUOTENAME(@base_schema) + '.' + QUOTENAME(@base_object));

IF OBJECT_ID('tempdb..#profile') IS NOT NULL DROP TABLE #profile;
CREATE TABLE #profile
(
  column_name sysname,
  data_type nvarchar(128),
  is_nullable bit,
  row_count bigint,
  nulls bigint,
  null_pct decimal(5,2),
  distinct_count bigint,
  min_value sql_variant NULL,
  max_value sql_variant NULL,
  avg_len decimal(10,2) NULL,
  max_len int NULL
);

/* iterate columns and compute null%, distincts, min/max (for numeric/date),
   and length stats for strings. Works for synonyms or real tables. */
DECLARE @col sysname, @dtype nvarchar(128), @nullable bit, @sql nvarchar(max);

DECLARE c CURSOR FAST_FORWARD FOR
SELECT c.name, t.name AS dtype, c.is_nullable
FROM sys.columns c
  JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = @base_object_id
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

CLOSE c;
DEALLOCATE c;

SELECT *
FROM #profile
ORDER BY column_name;