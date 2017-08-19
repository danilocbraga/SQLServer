CREATE PROCEDURE [dbo].[usp_NoTlogBackup] (@Length INT=90) -- 90 Minutes
AS
DECLARE @BadDatabases VARCHAR(8000)
DECLARE @Body VARCHAR(8000)
 
SELECT @BadDatabases = STUFF(
(select ', ' + cast(a.database_name as varchar(100))
 from
 (
 select [name] as database_name
 from master.dbo.sysdatabases
 where databasepropertyex([name], 'recovery') in ('FULL','BULK_LOGGED') 
 and databasepropertyex([name], 'isinstandby') = 0
 and databasepropertyex([name], 'status') = 'online'
 and databasepropertyex([name], 'updateability') = 'read_write'
 and [name] not in ('model','tempdb')
 ) a
 left join msdb.dbo.backupset b
 on a.database_name = b.database_name 
 and b.type='L'
 and datediff(hour,b.backup_finish_date,getdate()) < @Length
 where b.database_name is null
FOR XML PATH ('')
),1,2,'')
 
IF (@BadDatabases IS NOT NULL)
BEGIN
 
declare @ServerT varchar(100)
select @ServerT = 'Alert Backup - '+@@SERVERNAME
 
SET @Body = 'On ' + @@SERVERNAME + ' The following Databases do not have Transaction log backups: ' + @BadDatabases
PRINT @Body
 
 EXEC msdb . dbo. sp_send_dbmail        
      @recipients=N'mail@mail.com;' ,
      @body = @Body ,         
      @subject = @ServerT,         
      @profile_name ='profile_name',         
      @body_format = 'HTML'
 
END