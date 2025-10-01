USE [Global_Electronics];  -- change if needed
GO

DECLARE @schema sysname = N'raw';
DECLARE @obj    sysname;
DECLARE @sql    nvarchar(max);

IF OBJECT_ID('tempdb..#counts') IS NOT NULL DROP TABLE #counts;
CREATE TABLE #counts (
  object_name sysname NOT NULL,
  row_count   bigint  NULL
);

/* loop all synonyms + real tables in the target schema */
DECLARE cur CURSOR FAST_FORWARD FOR
  SELECT name FROM sys.synonyms WHERE schema_id = SCHEMA_ID(@schema)
  UNION ALL
  SELECT name FROM sys.tables   WHERE schema_id = SCHEMA_ID(@schema);

OPEN cur;
FETCH NEXT FROM cur INTO @obj;

WHILE @@FETCH_STATUS = 0
BEGIN
  SET @sql = N'
    SELECT @objname AS object_name, COUNT_BIG(*) AS row_count
    FROM ' + QUOTENAME(@schema) + N'.' + QUOTENAME(@obj) + N';';

  INSERT INTO #counts (object_name, row_count)
  EXEC sp_executesql 
       @sql,
       N'@objname sysname',
       @objname = QUOTENAME(@schema) + N'.' + QUOTENAME(@obj);

  FETCH NEXT FROM cur INTO @obj;
END

CLOSE cur; DEALLOCATE cur;

SELECT object_name, row_count
FROM #counts
ORDER BY object_name;

DROP TABLE #counts;
GO