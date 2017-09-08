/* Set PARAMETERIZATION FORCED for each database */

DECLARE @DB SYSNAME
      ,@cmd NVARCHAR(4000)

SET NOCOUNT ON
SET @cmd = ''

SELECT TOP 1 @DB = D.name
FROM master.sys.databases AS D
WHERE D.database_id > 4
       AND DATABASEPROPERTYEX(D.name, 'status') = 'ONLINE'
       AND is_parameterization_forced = 0
ORDER BY D.name;

WHILE @@ROWCOUNT = 1
BEGIN
      SET @cmd = 
             'ALTER DATABASE [' + @DB + ']  SET PARAMETERIZATION FORCED;'
     PRINT @cmd
     EXEC (@cmd)

      SELECT TOP 1 @DB = NAME
      FROM master.sys.databases AS D
              WHERE D.database_id > 4
              AND DATABASEPROPERTYEX(D.name, 'status') = 'ONLINE'
			  AND is_parameterization_forced = 0
              AND D.NAME > @DB
      ORDER BY D.name
END
