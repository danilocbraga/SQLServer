USE master
GO

IF (OBJECT_ID('dbo.SP_AutoCompressData') IS NOT NULL)
	DROP PROCEDURE dbo.SP_AutoCompressData;
GO

CREATE PROCEDURE dbo.SP_AutoCompressData
AS
SET NOCOUNT ON

/*

Author: Danilo Braga
Script to compress all tables and indexes in all databases.

*/
DECLARE @DB SYSNAME
	,@cmd NVARCHAR(4000)

SET NOCOUNT ON
SET @cmd = ''

SELECT TOP 1 @DB = D.NAME
FROM master..sysdatabases AS D
WHERE dbid > 4
	AND DATABASEPROPERTYEX(D.NAME, 'status') = 'ONLINE'
ORDER BY D.NAME;

WHILE @@ROWCOUNT = 1
BEGIN
	SET @cmd = 'USE ' + @DB + '; 

	IF NOT EXISTS(	
	
		SELECT 1
		FROM sys.partitions
		INNER JOIN sys.objects ON sys.partitions.object_id = sys.objects.object_id
		WHERE data_compression > 0
			AND SCHEMA_NAME(sys.objects.schema_id) <> ''SYS''
)
BEGIN


	DECLARE @command VARCHAR(max)
	DECLARE curCOMMAND CURSOR FAST_FORWARD
	FOR
	
		SELECT DISTINCT 
		   ''ALTER TABLE ['' 
		   + s.[name] 
		   + ''].['' 
		   + o.[name] 
		   + ''] REBUILD WITH (DATA_COMPRESSION=PAGE);''
		FROM sys.objects AS o WITH (NOLOCK)
		INNER JOIN sys.indexes AS i WITH (NOLOCK)
		   ON o.[object_id] = i.[object_id]
		INNER JOIN sys.schemas AS s WITH (NOLOCK)
		   ON o.[schema_id] = s.[schema_id]
		INNER JOIN sys.dm_db_partition_stats AS ps WITH (NOLOCK)
		   ON i.[object_id] = ps.[object_id]
		AND ps.[index_id] = i.[index_id]
		WHERE o.[type] = ''U''

	OPEN curCOMMAND
	FETCH NEXT
	FROM curCOMMAND
	INTO @command

	WHILE (@@FETCH_STATUS = 0)
	BEGIN
	
		PRINT @command
		EXEC sp_sqlexec @command
		
		FETCH NEXT
		FROM curCOMMAND
		INTO @command
	END
	CLOSE curCOMMAND
	DEALLOCATE curCOMMAND


	DECLARE @commandIndex VARCHAR(max)
	DECLARE curCOMMANDIndex CURSOR FAST_FORWARD
	FOR
	
		SELECT DISTINCT
		   ''ALTER INDEX ['' 
		   + i.[name] 
		   + ''] ON ['' 
		   + s.[name] 
		   + ''].['' 
		   + o.[name] 
		   + ''] REBUILD WITH (DATA_COMPRESSION=PAGE);''
		FROM sys.objects AS o WITH (NOLOCK)
		INNER JOIN sys.indexes AS i WITH (NOLOCK)
		   ON o.[object_id] = i.[object_id]
		INNER JOIN sys.schemas s WITH (NOLOCK)
		   ON o.[schema_id] = s.[schema_id]
		INNER JOIN sys.dm_db_partition_stats AS ps WITH (NOLOCK)
		   ON i.[object_id] = ps.[object_id]
		AND ps.[index_id] = i.[index_id]
		WHERE o.type = ''U'' 
		AND i.[index_id] >0

	OPEN curCOMMANDIndex
	FETCH NEXT
	FROM curCOMMANDIndex
	INTO @commandIndex

	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		
		PRINT @commandIndex
		EXEC sp_sqlexec @commandIndex
			
		FETCH NEXT
		FROM curCOMMANDIndex
		INTO @commandIndex
	END
	CLOSE curCOMMANDIndex
	DEALLOCATE curCOMMANDIndex
END	';

	EXEC (@cmd)
	PRINT @cmd

	SELECT TOP 1 @DB = NAME
	FROM master..sysdatabases AS D
	WHERE dbid > 4
		AND DATABASEPROPERTYEX(D.NAME, 'status') = 'ONLINE'
		AND D.NAME > @DB
	ORDER BY D.NAME
END
