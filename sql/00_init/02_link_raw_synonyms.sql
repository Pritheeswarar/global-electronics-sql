/* Creates raw.<table> synonyms that point to the existing source tables, without moving data. */
USE [Global_Electronics];  -- change DB name if different
GO

DECLARE @source_schema sysname = N'dbo';
-- change if your loaded tables are not in dbo
DECLARE @target_schema sysname = N'raw';
DECLARE @db sysname        = DB_NAME();
DECLARE @tbl sysname;
DECLARE @sql nvarchar(max);

/* Create target schema if missing (idempotent) */
IF NOT EXISTS (SELECT 1
FROM sys.schemas
WHERE name = @target_schema)
BEGIN
  DECLARE @create_schema_sql nvarchar(300) = N'CREATE SCHEMA ' + QUOTENAME(@target_schema) + N';';
  EXEC sp_executesql @create_schema_sql;
END

/* Loop all base tables in the source schema and create synonyms in raw if absent */
DECLARE cur CURSOR FAST_FORWARD FOR
SELECT t.name
FROM sys.tables t
  JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = @source_schema;

OPEN cur;
FETCH NEXT FROM cur INTO @tbl;
WHILE @@FETCH_STATUS = 0
BEGIN
  IF NOT EXISTS (
        SELECT 1
  FROM sys.synonyms syn
  WHERE syn.name = @tbl
    AND syn.schema_id = SCHEMA_ID(@target_schema)
    )
    BEGIN
    SET @sql = N'CREATE SYNONYM ' +
           QUOTENAME(@target_schema) + N'.' + QUOTENAME(@tbl) +
           N' FOR ' + QUOTENAME(@db) + N'.' + QUOTENAME(@source_schema) + N'.' + QUOTENAME(@tbl) + N';';
    EXEC sp_executesql @sql;
  -- dynamic synonym creation
  END
  FETCH NEXT FROM cur INTO @tbl;
END
CLOSE cur;
DEALLOCATE cur;

/* Verification */
SELECT s.name AS schema_name, syn.name AS synonym_name, syn.base_object_name
FROM sys.synonyms syn
  JOIN sys.schemas s ON s.schema_id = syn.schema_id
WHERE s.name = @target_schema
ORDER BY synonym_name;
GO