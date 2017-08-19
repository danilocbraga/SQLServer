DECLARE @NamedInstance bit
IF CAST(SERVERPROPERTY('ServerName') AS varchar) LIKE '%\%' SET @NamedInstance = 1 ELSE SET @NamedInstance = 0

DECLARE @ServiceName varchar(50)

IF @NamedInstance = 0
BEGIN
SET @ServiceName = 'MSSQLSERVER'
END
ELSE
BEGIN
SET @ServiceName = 'MSSQL$' + RIGHT(CAST(SERVERPROPERTY('ServerName') AS varchar),LEN(CAST(SERVERPROPERTY('ServerName') AS varchar)) - CHARINDEX('\',CAST(SERVERPROPERTY('ServerName') AS varchar),1))
END

DECLARE @KEY_VALUE varchar(100)
DECLARE @ServiceAccountName varchar(100)

SET @KEY_VALUE = 'SYSTEM\CurrentControlSet\Services\' + @ServiceName
EXECUTE master..xp_regread 'HKEY_LOCAL_MACHINE', @KEY_VALUE, 'ObjectName', @ServiceAccountName OUTPUT
SELECT @ServiceAccountName as 'SQLService Account'
IF CAST(SERVERPROPERTY('ServerName') AS varchar) LIKE '%\%' SET @NamedInstance = 1 ELSE SET @NamedInstance = 0


IF @NamedInstance = 0
BEGIN
SET @ServiceName = 'SQLSERVERAGENT'
END
ELSE
BEGIN
SET @ServiceName = 'SQLAgent$' + RIGHT(CAST(SERVERPROPERTY('ServerName') AS varchar),LEN(CAST(SERVERPROPERTY('ServerName') AS varchar)) - CHARINDEX('\',CAST(SERVERPROPERTY('ServerName') AS varchar),1))
END

SET @KEY_VALUE = 'SYSTEM\CurrentControlSet\Services\' + @ServiceName

EXECUTE master..xp_regread 'HKEY_LOCAL_MACHINE', @KEY_VALUE, 'ObjectName', @ServiceAccountName OUTPUT
SELECT @ServiceAccountName as 'SQLAgent Account'