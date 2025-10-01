/* Edit the database name on the next line to the one that already contains your Maven tables. */
USE [Global_Electronics];  -- <-- change if your DB name is different
GO

/* Idempotent creation of core schemas */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw')   EXEC('CREATE SCHEMA raw;');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stage') EXEC('CREATE SCHEMA stage;');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'marts') EXEC('CREATE SCHEMA marts;');
GO

/* Quick verification */
SELECT name 
FROM sys.schemas 
WHERE name IN ('raw','stage','marts')
ORDER BY name;