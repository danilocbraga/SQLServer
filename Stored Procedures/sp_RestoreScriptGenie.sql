USE master
GO

IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'sp_RestoreScriptGenie')
  EXEC ('CREATE PROC dbo.sp_RestoreScriptGenie AS SELECT ''stub version, to be replaced''')
GO

/*********************************************************************************************
Restore Script Generator v1.05 (2013-01-15)
(C) 2012, Paul Brewer

Feedback: mailto:paulbrewer@yahoo.co.uk
Updates: http://paul.dynalias.com/sql

License:
Restore Script Genie is free to download and use for personal, educational, and internal
corporate purposes, provided that this header is preserved. Redistribution or sale
of sp_RestoreScriptGenie, in whole or in part, is prohibited without the author's express
written consent.

Usage examples:

sp_RestoreScriptGenie
  No parameters = Generates RESTORE commands for all USER databases, from actual backup files to existing file locations to most current time, consistency checks, CHECKSUM where possible

sp_RestoreScriptGenie @Database = 'db_workspace', @StopAt = '2012-12-23 12:01:00.000', @StandbyMode = 1
  Generates RESTORE commands for a specific database from the most recent full backup + most recent differential + transaction log backups before to STOPAT.
  Databases left in STANDBY
  Ignores COPY_ONLY backups, restores to default file locations from default backup file.

sp_RestoreScriptGenie @Database = 'db_workspace', @StopAt = '2012-12-23 12:31:00.000', @ToFileFolder = 'c:\temp\', @ToLogFolder = 'c:\temp\' , @BackupDeviceFolder = 'c:\backup\'
  Overrides data file folder, log file folder and backup file folder.
  Generates RESTORE commands for a specific database from most recent full backup, most recent differential + transaction log backups before STOPAT.
  Ignores COPY_ONLY backups, includes WITH MOVE to simulate a restore to a test environment with different folder mapping.

CHANGE LOG:
December 23, 2012 - V1.01 - Release
January 4,2013  - V1.02 - LSN Checks + Bug fix to STOPAT date format
January 11,2013  - V1.03 - SQL Server 2005 compatibility (backup compression problem) & @StandbyMode for stepping through log restores with a readable database
January 14, 2013 - V1.04 - Cope with up to 10 striped backup files
January 15, 2013 - V1.05 - Format of constructed restore script, enclose database name in [ ]
*********************************************************************************************/

ALTER PROC dbo.sp_RestoreScriptGenie
(
  @Database SYSNAME = NULL,
  @ToFileFolder VARCHAR(2000) = NULL,
  @ToLogFolder VARCHAR(2000) = NULL,
  @BackupDeviceFolder VARCHAR(2000) = NULL,
  @StopAt DATETIME = NULL,
  @StandbyMode BIT = 0,
  @IncludeSystemBackups BIT = 0
)
AS
BEGIN

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ANSI_WARNINGS ON;
SET NUMERIC_ROUNDABORT OFF;
SET ARITHABORT ON;

IF ISNULL(@StopAt,'') = ''
  SET @StopAt = GETDATE();

--------------------------------------------------------------------------------------------------------------
-- Full backup UNION Differential Backup UNION Log Backup
--------------------------------------------------------------------------------------------------------------
WITH CTE
(
   database_name
  ,current_compatibility_level
  ,Last_LSN
  ,current_is_read_only
  ,current_state_desc
  ,current_recovery_model_desc
  ,has_backup_checksums
  ,backup_size
  ,[type]
  ,backupmediasetid
  ,family_sequence_number
  ,backupfinishdate
  ,physical_device_name
  ,position
)
AS
(
--------------------------------------------------------------------------------------------------------------
-- Full backup (most current or immediately before @StopAt if supplied)
--------------------------------------------------------------------------------------------------------------

SELECT
   bs.database_name
  ,d.[compatibility_level] AS current_compatibility_level
  ,bs.last_lsn
  ,d.[is_read_only] AS current_is_read_only
  ,d.[state_desc] AS current_state_desc
  ,d.[recovery_model_desc] current_recovery_model_desc
  ,bs.has_backup_checksums
  ,bs.backup_size AS backup_size
  ,'D' AS [type]
  ,bs.media_set_id AS backupmediasetid
  ,mf.family_sequence_number
  ,x.backup_finish_date AS backupfinishdate
  ,mf.physical_device_name
  ,bs.position
FROM msdb.dbo.backupset bs

INNER JOIN sys.databases d
  ON bs.database_name = d.name

INNER JOIN
(
  SELECT
    database_name
   ,MAX(backup_finish_date) backup_finish_date
  FROM msdb.dbo.backupset a
  JOIN msdb.dbo.backupmediafamily b
  ON a.media_set_id = b.media_set_id
  WHERE a.[type] = 'D'
  AND b.[Device_Type] = 2
  AND a.is_copy_only = 0
  AND a.backup_finish_date <= ISNULL(@StopAt,a.backup_finish_date)
  GROUP BY database_name
) x
  ON x.database_name = bs.database_name
  AND x.backup_finish_date = bs.backup_finish_date

JOIN msdb.dbo.backupmediafamily mf
  ON mf.media_set_id = bs.media_set_id
  AND mf.family_sequence_number Between bs.first_family_number And bs.last_family_number

WHERE bs.type = 'D'
AND mf.physical_device_name NOT IN ('Nul', 'Nul:')

--------------------------------------------------------------------------------------------------------------
-- Differential backup (most current or immediately before @StopAt if supplied)
--------------------------------------------------------------------------------------------------------------
UNION

SELECT
   bs.database_name
  ,d.[compatibility_level] AS current_compatibility_level
  ,bs.last_lsn
  ,d.[is_read_only] AS current_is_read_only
  ,d.[state_desc] AS current_state_desc
  ,d.[recovery_model_desc] current_recovery_model_desc
  ,bs.has_backup_checksums
  ,bs.backup_size AS backup_size
  ,'I' AS [type]
  ,bs.media_set_id AS backupmediasetid
  ,mf.family_sequence_number
  ,x.backup_finish_date AS backupfinishdate
  ,mf.physical_device_name
  ,bs.position
FROM msdb.dbo.backupset bs

INNER JOIN sys.databases d
  ON bs.database_name = d.name

INNER JOIN
(
  SELECT
    database_name
   ,MAX(backup_finish_date) backup_finish_date
  FROM msdb.dbo.backupset a
  JOIN msdb.dbo.backupmediafamily b
  ON a.media_set_id = b.media_set_id
  WHERE a.[type] = 'I'
  AND b.[Device_Type] = 2
  AND a.is_copy_only = 0
  AND a.backup_finish_date <= ISNULL(@StopAt,GETDATE())
  GROUP BY database_name
) x
  ON x.database_name = bs.database_name
  AND x.backup_finish_date = bs.backup_finish_date

JOIN msdb.dbo.backupmediafamily mf
  ON mf.media_set_id = bs.media_set_id
  AND mf.family_sequence_number Between bs.first_family_number And bs.last_family_number

WHERE bs.type = 'I'
AND mf.physical_device_name NOT IN ('Nul', 'Nul:')
AND bs.backup_finish_date <= ISNULL(@StopAt,GETDATE())

--------------------------------------------------------------------------------------------------------------
-- Log file backups after 1st full backup before @STOPAT, before next full backup after 1st full backup
--------------------------------------------------------------------------------------------------------------
UNION

SELECT
   bs.database_name
  ,d.[compatibility_level] AS current_compatibility_level
  ,bs.last_lsn
  ,d.[is_read_only] AS current_is_read_only
  ,d.[state_desc] AS current_state_desc
  ,d.[recovery_model_desc] current_recovery_model_desc
  ,bs.has_backup_checksums
  ,bs.backup_size AS backup_size
  ,'L' AS [type]
  ,bs.media_set_id AS backupmediasetid
  ,mf.family_sequence_number
  ,bs.backup_finish_date as backupfinishdate
  ,mf.physical_device_name
  ,bs.position

FROM msdb.dbo.backupset bs

INNER JOIN sys.databases d
  ON bs.database_name = d.name

JOIN msdb.dbo.backupmediafamily mf
  ON mf.media_set_id = bs.media_set_id
  AND mf.family_sequence_number Between bs.first_family_number And bs.last_family_number

LEFT OUTER JOIN
(
  SELECT
    database_name
   ,MAX(backup_finish_date) backup_finish_date
  FROM msdb.dbo.backupset a
  JOIN msdb.dbo.backupmediafamily b
  ON a.media_set_id = b.media_set_id
  WHERE a.[type] = 'D'
  AND b.[Device_Type] = 2
  AND a.is_copy_only = 0
  AND a.backup_finish_date <= ISNULL(@StopAt,a.backup_finish_date)
  GROUP BY database_name
) y
  ON bs.database_name = y.Database_name

LEFT OUTER JOIN
(
  SELECT
    database_name
   ,MIN(backup_finish_date) backup_finish_date
  FROM msdb.dbo.backupset a
  JOIN msdb.dbo.backupmediafamily b
   ON a.media_set_id = b.media_set_id
  WHERE a.[type] = 'D'
  AND b.[Device_Type] = 2

  AND a.is_copy_only = 0
  AND a.backup_finish_date > ISNULL(@StopAt,'1 Jan, 1900')
  GROUP BY database_name
) z
  ON bs.database_name = z.database_name

WHERE bs.backup_finish_date > y.backup_finish_date
AND bs.backup_finish_date < ISNULL(z.backup_finish_date,GETDATE())
AND mf.physical_device_name NOT IN ('Nul', 'Nul:')
AND bs.type = 'L'
AND mf.device_type = 2
)

---------------------------------------------------------------
-- Result set below is based on CTE above
---------------------------------------------------------------

SELECT
  a.Command AS TSQL_RestoreCommand_CopyPaste
FROM
(

--------------------------------------------------------------------
-- Most recent full backup
--------------------------------------------------------------------

SELECT
  ';RESTORE DATABASE [' + d.[name] + ']' + SPACE(1) +
  'FROM DISK = ' + '''' +
  CASE ISNULL(@BackupDeviceFolder,'Actual')
    WHEN 'Actual' THEN CTE.physical_device_name
    ELSE @BackupDeviceFolder + SUBSTRING(CTE.physical_device_name,LEN(CTE.physical_device_name) - CHARINDEX('\',REVERSE(CTE.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(CTE.physical_device_name),1) + 1)
  END + '''' + SPACE(1) +

  -- Striped backup files
  CASE ISNULL(Stripe2.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe2.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe2.physical_device_name,LEN(Stripe2.physical_device_name) - CHARINDEX('\',REVERSE(Stripe2.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe2.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe3.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe3.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe3.physical_device_name,LEN(Stripe3.physical_device_name) - CHARINDEX('\',REVERSE(Stripe3.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe3.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe4.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe4.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe4.physical_device_name,LEN(Stripe4.physical_device_name) - CHARINDEX('\',REVERSE(Stripe4.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe4.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe5.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe5.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe5.physical_device_name,LEN(Stripe5.physical_device_name) - CHARINDEX('\',REVERSE(Stripe5.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe5.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe6.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe6.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe6.physical_device_name,LEN(Stripe6.physical_device_name) - CHARINDEX('\',REVERSE(Stripe6.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe6.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe7.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe7.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe7.physical_device_name,LEN(Stripe7.physical_device_name) - CHARINDEX('\',REVERSE(Stripe7.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe7.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe8.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe8.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe8.physical_device_name,LEN(Stripe8.physical_device_name) - CHARINDEX('\',REVERSE(Stripe8.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe8.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe9.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe9.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe9.physical_device_name,LEN(Stripe9.physical_device_name) - CHARINDEX('\',REVERSE(Stripe9.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe9.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe10.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe10.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe10.physical_device_name,LEN(Stripe10.physical_device_name) - CHARINDEX('\',REVERSE(Stripe10.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe10.physical_device_name),1) + 1) END + ''''
  END +

  'WITH REPLACE, FILE = ' + CAST(CTE.Position AS VARCHAR(5)) + ',' +
  CASE CTE.has_backup_checksums WHEN 1 THEN 'CHECKSUM,' ELSE ' ' END +

  CASE @StandbyMode WHEN 0 THEN 'NORECOVERY,' ELSE 'STANDBY =N' + '''' + ISNULL(@BackupDeviceFolder,SUBSTRING(CTE.physical_device_name,1,LEN(CTE.physical_device_name) - CHARINDEX('\',REVERSE(CTE.physical_device_name)))) + '\' + d.name + '_ROLLBACK_UNDO.bak ' + '''' + ',' END + SPACE(1) +

  'STATS=10,' + SPACE(1) +
  'MOVE ' + '''' + x.LogicalName + '''' + ' TO ' +
  '''' +
  CASE ISNULL(@ToFileFolder,'Actual')
    WHEN 'Actual' THEN x.PhysicalName
    ELSE @ToFileFolder + SUBSTRING(x.PhysicalName,LEN(x.PhysicalName) - CHARINDEX('\',REVERSE(x.PhysicalName),1) + 2,CHARINDEX('\',REVERSE(x.PhysicalName),1) + 1)
  END + '''' + ',' + SPACE(1) +

  'MOVE ' + '''' + y.LogicalName + '''' + ' TO ' +
  '''' +
  CASE ISNULL(@ToLogFolder,'Actual')
    WHEN 'Actual' THEN y.PhysicalName
    ELSE @ToLogFolder + SUBSTRING(y.PhysicalName,LEN(y.PhysicalName) - CHARINDEX('\',REVERSE(y.PhysicalName),1) + 2,CHARINDEX('\',REVERSE(y.PhysicalName),1) + 1)
  END + '''' AS Command,
  1 AS Sequence,
  d.name AS database_name,
  CTE.physical_device_name AS BackupDevice,
  CTE.backupfinishdate,
  CTE.backup_size

FROM sys.databases d
JOIN
(
  SELECT
    DB_NAME(mf.database_id) AS name
   ,mf.Physical_Name AS PhysicalName
   ,mf.Name AS LogicalName
  FROM sys.master_files mf
  WHERE type_desc = 'ROWS'
  AND mf.file_id = 1
) x
ON d.name = x.name

JOIN
(
  SELECT
    DB_NAME(mf.database_id) AS name, type_desc
   ,mf.Physical_Name PhysicalName
   ,mf.Name AS LogicalName
  FROM sys.master_files mf
  WHERE type_desc = 'LOG'
) y
ON d.name = y.name

JOIN CTE
  ON CTE.database_name = d.name

-- Striped backup files (caters for up to 10)
LEFT OUTER JOIN CTE AS Stripe2
  ON Stripe2.database_name = d.name
  AND Stripe2.backupmediasetid = CTE.backupmediasetid
  AND Stripe2.family_sequence_number = 2

LEFT OUTER JOIN CTE AS Stripe3
  ON Stripe3.database_name = d.name
  AND Stripe3.backupmediasetid = CTE.backupmediasetid
  AND Stripe3.family_sequence_number = 3

LEFT OUTER JOIN CTE AS Stripe4
  ON Stripe4.database_name = d.name
  AND Stripe4.backupmediasetid = CTE.backupmediasetid
  AND Stripe4.family_sequence_number = 4

LEFT OUTER JOIN CTE AS Stripe5
  ON Stripe5.database_name = d.name
  AND Stripe5.backupmediasetid = CTE.backupmediasetid
  AND Stripe5.family_sequence_number = 5

LEFT OUTER JOIN CTE AS Stripe6
  ON Stripe6.database_name = d.name
  AND Stripe6.backupmediasetid = CTE.backupmediasetid
  AND Stripe6.family_sequence_number = 6

LEFT OUTER JOIN CTE AS Stripe7
  ON Stripe7.database_name = d.name
  AND Stripe7.backupmediasetid = CTE.backupmediasetid
  AND Stripe7.family_sequence_number = 7

LEFT OUTER JOIN CTE AS Stripe8
  ON Stripe8.database_name = d.name
  AND Stripe8.backupmediasetid = CTE.backupmediasetid
  AND Stripe8.family_sequence_number = 8

LEFT OUTER JOIN CTE AS Stripe9
  ON Stripe9.database_name = d.name
  AND Stripe9.backupmediasetid = CTE.backupmediasetid
  AND Stripe9.family_sequence_number = 9

LEFT OUTER JOIN CTE AS Stripe10
  ON Stripe10.database_name = d.name
  AND Stripe10.backupmediasetid = CTE.backupmediasetid
  AND Stripe10.family_sequence_number = 10

WHERE CTE.[type] = 'D'
AND CTE.family_sequence_number = 1

--------------------------------------------------------------------
-- Most recent differential backup
--------------------------------------------------------------------
UNION

SELECT
  ';RESTORE DATABASE [' + d.[name] + ']' + SPACE(1) +
  'FROM DISK = ' + '''' +
  CASE ISNULL(@BackupDeviceFolder,'Actual')
    WHEN 'Actual' THEN CTE.physical_device_name
    ELSE @BackupDeviceFolder + SUBSTRING(CTE.physical_device_name,LEN(CTE.physical_device_name) - CHARINDEX('\',REVERSE(CTE.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(CTE.physical_device_name),1) + 1)
  END + '''' + SPACE(1) +

  -- Striped backup files
  CASE ISNULL(Stripe2.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe2.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe2.physical_device_name,LEN(Stripe2.physical_device_name) - CHARINDEX('\',REVERSE(Stripe2.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe2.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe3.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe3.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe3.physical_device_name,LEN(Stripe3.physical_device_name) - CHARINDEX('\',REVERSE(Stripe3.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe3.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe4.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe4.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe4.physical_device_name,LEN(Stripe4.physical_device_name) - CHARINDEX('\',REVERSE(Stripe4.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe4.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe5.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe5.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe5.physical_device_name,LEN(Stripe5.physical_device_name) - CHARINDEX('\',REVERSE(Stripe5.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe5.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe6.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe6.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe6.physical_device_name,LEN(Stripe6.physical_device_name) - CHARINDEX('\',REVERSE(Stripe6.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe6.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe7.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe7.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe7.physical_device_name,LEN(Stripe7.physical_device_name) - CHARINDEX('\',REVERSE(Stripe7.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe7.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe8.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe8.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe8.physical_device_name,LEN(Stripe8.physical_device_name) - CHARINDEX('\',REVERSE(Stripe8.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe8.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe9.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe9.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe9.physical_device_name,LEN(Stripe9.physical_device_name) - CHARINDEX('\',REVERSE(Stripe9.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe9.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe10.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe10.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe10.physical_device_name,LEN(Stripe10.physical_device_name) - CHARINDEX('\',REVERSE(Stripe10.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe10.physical_device_name),1) + 1) END + ''''
  END +

  'WITH REPLACE, FILE = ' + CAST(CTE.Position AS VARCHAR(5)) + ',' +
  CASE CTE.has_backup_checksums WHEN 1 THEN 'CHECKSUM,' ELSE ' ' END +

  CASE @StandbyMode WHEN 0 THEN 'NORECOVERY,' ELSE 'STANDBY =N' + '''' + ISNULL(@BackupDeviceFolder,SUBSTRING(CTE.physical_device_name,1,LEN(CTE.physical_device_name) - CHARINDEX('\',REVERSE(CTE.physical_device_name)))) + '\' + d.name + '_ROLLBACK_UNDO.bak ' + ''''  + ',' END + SPACE(1) +

  'STATS=10,' + SPACE(1) +
  'MOVE ' + '''' + x.LogicalName + '''' + ' TO ' +
  '''' +
   CASE ISNULL(@ToFileFolder,'Actual')
    WHEN 'Actual' THEN x.PhysicalName
    ELSE @ToFileFolder + SUBSTRING(x.PhysicalName,LEN(x.PhysicalName) - CHARINDEX('\',REVERSE(x.PhysicalName),1) + 2,CHARINDEX('\',REVERSE(x.PhysicalName),1) + 1)
  END + '''' + ',' + SPACE(1) +

  'MOVE ' + '''' + y.LogicalName + '''' + ' TO ' +
  '''' +
  CASE ISNULL(@ToLogFolder,'Actual')
    WHEN 'Actual' THEN y.PhysicalName
    ELSE @ToLogFolder + SUBSTRING(y.PhysicalName,LEN(y.PhysicalName) - CHARINDEX('\',REVERSE(y.PhysicalName),1) + 2,CHARINDEX('\',REVERSE(y.PhysicalName),1) + 1)
  END + '''' AS Command,
  32769/2 AS Sequence,
  d.name AS database_name,
  CTE.physical_device_name AS BackupDevice,
  CTE.backupfinishdate,
  CTE.backup_size

FROM sys.databases d

JOIN CTE
  ON CTE.database_name = d.name

-- Striped backup files (caters for up to 10)
LEFT OUTER JOIN CTE AS Stripe2
  ON Stripe2.database_name = d.name
  AND Stripe2.backupmediasetid = CTE.backupmediasetid
  AND Stripe2.family_sequence_number = 2

LEFT OUTER JOIN CTE AS Stripe3
  ON Stripe3.database_name = d.name
  AND Stripe3.backupmediasetid = CTE.backupmediasetid
  AND Stripe3.family_sequence_number = 3

LEFT OUTER JOIN CTE AS Stripe4
  ON Stripe4.database_name = d.name
  AND Stripe4.backupmediasetid = CTE.backupmediasetid
  AND Stripe4.family_sequence_number = 4

LEFT OUTER JOIN CTE AS Stripe5
  ON Stripe5.database_name = d.name
  AND Stripe5.backupmediasetid = CTE.backupmediasetid
  AND Stripe5.family_sequence_number = 5

LEFT OUTER JOIN CTE AS Stripe6
  ON Stripe6.database_name = d.name
  AND Stripe6.backupmediasetid = CTE.backupmediasetid
  AND Stripe6.family_sequence_number = 6

LEFT OUTER JOIN CTE AS Stripe7
  ON Stripe7.database_name = d.name
  AND Stripe7.backupmediasetid = CTE.backupmediasetid
  AND Stripe7.family_sequence_number = 7

LEFT OUTER JOIN CTE AS Stripe8
  ON Stripe8.database_name = d.name
  AND Stripe8.backupmediasetid = CTE.backupmediasetid
  AND Stripe8.family_sequence_number = 8

LEFT OUTER JOIN CTE AS Stripe9
  ON Stripe9.database_name = d.name
  AND Stripe9.backupmediasetid = CTE.backupmediasetid
  AND Stripe9.family_sequence_number = 9

LEFT OUTER JOIN CTE AS Stripe10
  ON Stripe10.database_name = d.name
  AND Stripe10.backupmediasetid = CTE.backupmediasetid
  AND Stripe10.family_sequence_number = 10

JOIN
(
  SELECT
    DB_NAME(mf.database_id) AS name
   ,mf.Physical_Name AS PhysicalName
   ,mf.Name AS LogicalName
  FROM sys.master_files mf
  WHERE type_desc = 'ROWS'
  AND mf.file_id = 1
) x
ON d.name = x.name

JOIN
(
  SELECT
    DB_NAME(mf.database_id) AS name, type_desc
   ,mf.Physical_Name PhysicalName
   ,mf.Name AS LogicalName
  FROM sys.master_files mf
  WHERE type_desc = 'LOG'
) y
ON d.name = y.name

JOIN
(
  SELECT
   database_name,
   Last_LSN,
   backupfinishdate
  FROM CTE
  WHERE [Type] = 'D'
) z
  ON CTE.database_name = z.database_name

WHERE CTE.[type] = 'I'
AND CTE.backupfinishdate > z.backupfinishdate -- Differential backup was after selected full backup
AND CTE.Last_LSN > z.Last_LSN -- Differential Last LSN > Full Last LSN
AND CTE.backupfinishdate < @StopAt
AND CTE.family_sequence_number = 1

-----------------------------------------------------------------------------------------------------------------------------
UNION -- Restore Log backups taken since most recent full, these are filtered in the CTE to those after the full backup date
-----------------------------------------------------------------------------------------------------------------------------

SELECT
  ';RESTORE LOG [' + d.[name] + ']' + SPACE(1) +
  'FROM DISK = ' + '''' + --CTE.physical_device_name + '''' + SPACE(1) +
  CASE ISNULL(@BackupDeviceFolder,'Actual')
   WHEN 'Actual' THEN CTE.physical_device_name
   ELSE @BackupDeviceFolder + SUBSTRING(CTE.physical_device_name,LEN(CTE.physical_device_name) - CHARINDEX('\',REVERSE(CTE.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(CTE.physical_device_name),1) + 1)
  END + '''' +

  -- Striped backup files
  CASE ISNULL(Stripe2.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe2.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe2.physical_device_name,LEN(Stripe2.physical_device_name) - CHARINDEX('\',REVERSE(Stripe2.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe2.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe3.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe3.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe3.physical_device_name,LEN(Stripe3.physical_device_name) - CHARINDEX('\',REVERSE(Stripe3.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe3.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe4.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe4.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe4.physical_device_name,LEN(Stripe4.physical_device_name) - CHARINDEX('\',REVERSE(Stripe4.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe4.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe5.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe5.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe5.physical_device_name,LEN(Stripe5.physical_device_name) - CHARINDEX('\',REVERSE(Stripe5.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe5.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe6.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe6.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe6.physical_device_name,LEN(Stripe6.physical_device_name) - CHARINDEX('\',REVERSE(Stripe6.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe6.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe7.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe7.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe7.physical_device_name,LEN(Stripe7.physical_device_name) - CHARINDEX('\',REVERSE(Stripe7.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe7.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe8.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe8.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe8.physical_device_name,LEN(Stripe8.physical_device_name) - CHARINDEX('\',REVERSE(Stripe8.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe8.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe9.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe9.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe9.physical_device_name,LEN(Stripe9.physical_device_name) - CHARINDEX('\',REVERSE(Stripe9.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe9.physical_device_name),1) + 1) END + ''''
  END +

  CASE ISNULL(Stripe10.physical_device_name,'')
    WHEN '' THEN ''
    ELSE  ', DISK = ' + '''' + CASE ISNULL(@BackupDeviceFolder,'Actual') WHEN 'Actual' THEN Stripe10.physical_device_name ELSE @BackupDeviceFolder + SUBSTRING(Stripe10.physical_device_name,LEN(Stripe10.physical_device_name) - CHARINDEX('\',REVERSE(Stripe10.physical_device_name),1) + 2,CHARINDEX('\',REVERSE(Stripe10.physical_device_name),1) + 1) END + ''''
  END +

  CASE @StandbyMode WHEN 0 THEN ' WITH NORECOVERY,' ELSE ' WITH STANDBY =N' + '''' + ISNULL(@BackupDeviceFolder,SUBSTRING(CTE.physical_device_name,1,LEN(CTE.physical_device_name) - CHARINDEX('\',REVERSE(CTE.physical_device_name)))) + '\' + d.name + '_ROLLBACK_UNDO.bak ' + ''''  + ',' END + SPACE(1) +

  CASE CTE.has_backup_checksums WHEN 1 THEN ' CHECKSUM,' ELSE ' ' END +
 
  + 'FILE = ' + CAST(CTE.Position AS VARCHAR(5)) +
  CASE CTE.backupfinishdate
    WHEN z.backupfinishdate THEN ' ,STOPAT = ' + '''' + CONVERT(VARCHAR(21),@StopAt,120) + ''''
    ELSE ' '
  END
  AS Command,
  32769 AS Sequence,
  d.name AS database_name,
  CTE.physical_device_name AS BackupDevice,
  CTE.backupfinishdate,
  CTE.backup_size

FROM sys.databases d

JOIN CTE
  ON CTE.database_name = d.name

-- Striped backup files (caters for up to 10)
LEFT OUTER JOIN CTE AS Stripe2
  ON Stripe2.database_name = d.name
  AND Stripe2.backupmediasetid = CTE.backupmediasetid
  AND Stripe2.family_sequence_number = 2

LEFT OUTER JOIN CTE AS Stripe3
  ON Stripe3.database_name = d.name
  AND Stripe3.backupmediasetid = CTE.backupmediasetid
  AND Stripe3.family_sequence_number = 3

LEFT OUTER JOIN CTE AS Stripe4
  ON Stripe4.database_name = d.name
  AND Stripe4.backupmediasetid = CTE.backupmediasetid
  AND Stripe4.family_sequence_number = 4

LEFT OUTER JOIN CTE AS Stripe5
  ON Stripe5.database_name = d.name
  AND Stripe5.backupmediasetid = CTE.backupmediasetid
  AND Stripe5.family_sequence_number = 5

LEFT OUTER JOIN CTE AS Stripe6
  ON Stripe6.database_name = d.name
  AND Stripe6.backupmediasetid = CTE.backupmediasetid
  AND Stripe6.family_sequence_number = 6

LEFT OUTER JOIN CTE AS Stripe7
  ON Stripe7.database_name = d.name
  AND Stripe7.backupmediasetid = CTE.backupmediasetid
  AND Stripe7.family_sequence_number = 7

LEFT OUTER JOIN CTE AS Stripe8
  ON Stripe8.database_name = d.name
  AND Stripe8.backupmediasetid = CTE.backupmediasetid
  AND Stripe8.family_sequence_number = 8

LEFT OUTER JOIN CTE AS Stripe9
  ON Stripe9.database_name = d.name
  AND Stripe9.backupmediasetid = CTE.backupmediasetid
  AND Stripe9.family_sequence_number = 9

LEFT OUTER JOIN CTE AS Stripe10
  ON Stripe10.database_name = d.name
  AND Stripe10.backupmediasetid = CTE.backupmediasetid
  AND Stripe10.family_sequence_number = 10

LEFT OUTER JOIN  -- Next full backup after STOPAT
(
  SELECT
   database_name, MIN(BackupFinishDate) AS backup_finish_date
  FROM CTE
  WHERE type = 'D'
  AND backupfinishdate > @StopAt
  GROUP BY database_name

) x
  ON x.database_name = CTE.database_name

LEFT OUTER JOIN -- Highest differential backup date
(
  SELECT database_name, max(backupfinishdate) AS backupfinishdate
  FROM CTE
  WHERE CTE.type = 'I'
  AND CTE.backupfinishdate < @StandbyMode
  GROUP BY database_name
) y
  ON y.database_name = CTE.database_name

LEFT OUTER JOIN -- First log file after STOPAT
(
  SELECT database_name, min(backupfinishdate) AS backupfinishdate
  FROM CTE
  WHERE CTE.type = 'L'
  AND backupfinishdate > @StopAt
  GROUP BY database_name
) z
  ON z.database_name = CTE.database_name

JOIN
(
  SELECT
   database_name,
   MAX(Last_LSN) AS Last_LSN
  FROM CTE
  WHERE CTE.backupfinishdate < ISNULL(@StopAt,GETDATE())
  AND CTE.Type IN ('D','I')
  GROUP BY database_name
) x1
  ON CTE.database_name = x1.database_name

WHERE CTE.[type] = 'L'
AND CTE.backupfinishdate <= ISNULL(x.backup_finish_date,'31 Dec, 2199') -- Less than next full backup
AND CTE.backupfinishdate >= ISNULL(y.backupfinishdate, CTE.backupfinishdate) --Great than or equal to last differential backup
AND CTE.backupfinishdate <= ISNULL(z.backupfinishdate, CTE.backupfinishdate) -- Less than or equal to last file file in recovery chain (IE Log Backup datetime might be after STOPAT)
AND CTE.Last_LSN > x1.Last_LSN -- Differential or Full Last LSN < Log Last LSN
AND CTE.family_sequence_number = 1

--------------------------------------------------------------------
UNION -- Restore WITH RECOVERY
--------------------------------------------------------------------
SELECT
  ';RESTORE DATABASE [' + d.[name] + ']' + SPACE(1) + 'WITH RECOVERY' AS Command,
  32771 AS Sequence,
  d.name AS database_name,
  '' AS BackupDevice,
  CTE.backupfinishdate,
  CTE.backup_size

FROM sys.databases d

JOIN CTE
  ON CTE.database_name = d.name

WHERE CTE.[type] = 'D'
AND @StandbyMode = 0

--------------------------------------------------------------------
UNION -- CHECKDB
--------------------------------------------------------------------
SELECT
  ';DBCC CHECKDB(' + '''' + d.[name] + '''' + ') WITH NO_INFOMSGS IF @@ERROR > 0 PRINT N''CONSISTENCY PROBLEMS IN DATABASE : ' + d.name + ''' ELSE PRINT N''CONSISTENCY GOOD IN DATABASE : ' + d.name + '''' AS Command,
  32772 AS Sequence,
  d.name AS database_name,
  '' AS BackupDevice,
  CTE.backupfinishdate,
  CTE.backup_size

FROM sys.databases d

JOIN CTE
  ON CTE.database_name = d.name

WHERE CTE.[type] = 'D'
AND @StandbyMode = 0

---------------------------------------------------------------------------------------------------------------------------------------------------
UNION -- MOVE full backup secondary data files, allows for up to 32769/2 file groups
---------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
  ', MOVE ' + '''' + b.name + '''' + ' TO ' +
  '''' +
  CASE ISNULL(@ToFileFolder,'Actual')
    WHEN 'Actual' THEN b.physical_name
    ELSE @ToFileFolder + SUBSTRING(b.Physical_Name,LEN(b.Physical_Name) - CHARINDEX('\',REVERSE(b.Physical_Name),1) + 2,CHARINDEX('\',REVERSE(b.Physical_Name),1) + 1)
  END + '''',
  b.file_id AS Sequence,
  DB_NAME(b.database_id) AS database_name,
  '' AS BackupDevice,
  CTE.backupfinishdate,
  CTE.backup_size

FROM sys.master_files b
INNER JOIN CTE
  ON CTE.database_name = DB_NAME(b.database_id)

WHERE CTE.[type] = 'D'
AND b.type_desc = 'ROWS'
AND b.file_id > 2

---------------------------------------------------------------------------------------------------------------------------------------------------
UNION -- MOVE differential backup secondary data files, allows for up to 32769/2 file groups
---------------------------------------------------------------------------------------------------------------------------------------------------

SELECT
  ', MOVE ' + '''' + b.name + '''' + ' TO ' +
  '''' +
  CASE ISNULL(@ToFileFolder,'Actual')
    WHEN 'Actual' THEN b.physical_name
    ELSE @ToFileFolder + SUBSTRING(b.Physical_Name,LEN(b.Physical_Name) - CHARINDEX('\',REVERSE(b.Physical_Name),1) + 2,CHARINDEX('\',REVERSE(b.Physical_Name),1) + 1)
  END + '''',
  ((b.file_id) + (32769/2)) AS Sequence,
  DB_NAME(b.database_id) AS database_name,
  '' AS BackupDevice,
  CTE.backupfinishdate,
  CTE.backup_size

FROM sys.master_files b
INNER JOIN CTE
  ON CTE.database_name = DB_NAME(b.database_id)

WHERE CTE.[type] = 'I'
AND b.type_desc = 'ROWS'
AND b.file_id > 2
AND CTE.backupfinishdate < @StopAt
) a

WHERE a.database_name = ISNULL(@database,a.database_name)
AND (@IncludeSystemBackups = 1 OR a.database_name NOT IN('master','model','msdb'))

ORDER BY
  database_name,
  sequence,
  backupfinishdate

END