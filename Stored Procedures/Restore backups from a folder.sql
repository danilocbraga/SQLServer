CREATE PROC [dbo]. [sp_RestoreFromAllFilesInDirectory]  
@SourceDirBackupFiles nvarchar (200), @DestDirDbFiles nvarchar(200 ),@DestDirLogFiles nvarchar(200 )  
AS  
--Originally written by Tibor Karaszi 2004. Use at own risk.  
--Restores from all files in a certain directory. Assumes that:  
--  There's only one backup on each backup device.  
--  Each database uses only two database files and the mdf file is returned first from the RESTORE FILELISTONLY command.  
--Sample execution:  
-- EXEC sp_RestoreFromAllFilesInDirectory 'C:\Mybakfiles\', 'D:\Mydatabasesdirectory\' ,’C:\MylogDirectory\’  
  
SET NOCOUNT ON  
  
--Table to hold each backup file name in  
CREATE TABLE #files( fname varchar (200 ), depth int , file_ int)  
INSERT #files  
EXECUTE master .dbo. xp_dirtree @SourceDirBackupFiles , 1, 1  
  
--Table to hold the result from RESTORE HEADERONLY. Needed to get the database name out from  
CREATE TABLE #bdev(  
 BackupName nvarchar(128 )  
,BackupDescription nvarchar(255 )  
,BackupType smallint  
,ExpirationDate datetime  
,Compressed tinyint  
,Position smallint  
,DeviceType tinyint  
,UserName nvarchar(128 )  
,ServerName nvarchar(128 )  
,DatabaseName nvarchar(128 )  
,DatabaseVersion bigint  
,DatabaseCreationDate datetime  
,BackupSize numeric(20 ,0)  
,FirstLSN numeric(25 ,0)  
,LastLSN numeric(25 ,0)  
,CheckpointLSN numeric(25 ,0)  
,DatabaseBackupLSN numeric(25 ,0)  
,BackupStartDate datetime  
,BackupFinishDate datetime  
,SortOrder smallint  
,CodePage smallint  
,UnicodeLocaleId bigint  
,UnicodeComparisonStyle bigint  
,CompatibilityLevel tinyint  
,SoftwareVendorId bigint  
,SoftwareVersionMajor bigint  
,SoftwareVersionMinor bigint  
,SoftwareVersionBuild bigint  
,MachineName nvarchar(128 )  
,Flags bigint  
,BindingID uniqueidentifier  
,RecoveryForkID uniqueidentifier  
,Collation nvarchar(128 )  
,FamilyGUID uniqueidentifier  
,HasBulkLoggedData bigint  
,IsSnapshot bigint  
,IsReadOnly bigint  
,IsSingleUser bigint  
,HasBackupChecksums bigint  
,IsDamaged bigint  
,BegibsLogChain bigint  
,HasIncompleteMetaData bigint  
,IsForceOffline bigint  
,IsCopyOnly bigint  
,FirstRecoveryForkID uniqueidentifier  
,ForkPointLSN numeric(25 ,0)  
,RecoveryModel nvarchar(128 )  
,DifferentialBaseLSN numeric(25 ,0)  
,DifferentialBaseGUID uniqueidentifier  
,BackupTypeDescription nvarchar(128 )  
,BackupSetGUID uniqueidentifier  
,CompressedBackupSize nvarchar(128 )  
, containment tinyint not NULL -- >= 2012  
, KeyAlgorithm nvarchar( 32)    -- >=  SQL Server 2014 (PCU1)  
, EncryptorThumbprint varbinary( 20)   -- >=  SQL Server 2014 (PCU1)  
, EncryptorType nvarchar( 32)          -- >=  SQL Server 2014 (PCU1)  
)  
  
--Table to hold result from RESTORE FILELISTONLY. Need to generate the MOVE options to the RESTORE command  
CREATE TABLE #dbfiles(  
 LogicalName nvarchar(128 )  
,PhysicalName nvarchar(260 )  
,Type char(1 )  
,FileGroupName nvarchar(128 )  
,Size numeric(20 ,0)  
,MaxSize numeric(20 ,0)  
,FileId bigint  
,CreateLSN numeric(25 ,0)  
,DropLSN numeric(25 ,0)  
,UniqueId uniqueidentifier  
,ReadOnlyLSN numeric(25 ,0)  
,ReadWriteLSN numeric(25 ,0)  
,BackupSizeInBytes bigint  
,SourceBlockSize bigint  
,FilegroupId bigint  
,LogGroupGUID uniqueidentifier  
,DifferentialBaseLSN numeric(25 )  
,DifferentialBaseGUID uniqueidentifier  
,IsReadOnly bigint  
,IsPresent bigint  
,TDEThumbprint nvarchar(128 )  
)  
  
  
DECLARE @fname varchar( 200)  
DECLARE @dirfile varchar( 300)  
DECLARE @LogicalName nvarchar( 128)  
DECLARE @PhysicalName nvarchar( 260)  
DECLARE @type char( 1)  
DECLARE @DbName sysname  
DECLARE @sql nvarchar( 1000)  
  
DECLARE files CURSOR FOR  
SELECT fname FROM #files  
  
DECLARE dbfiles CURSOR FOR  
SELECT LogicalName , PhysicalName , Type FROM #dbfiles  
  
OPEN files  
FETCH NEXT FROM files INTO @fname  
WHILE @@FETCH_STATUS = 0  
BEGIN  
SET @dirfile = @SourceDirBackupFiles + @fname  
  
--Get database name from RESTORE HEADERONLY, assumes there's only one backup on each backup file.  
TRUNCATE TABLE #bdev  
INSERT #bdev  
EXEC('RESTORE HEADERONLY FROM DISK = ''' + @dirfile + '''')  
SET @DbName = (SELECT DatabaseName FROM #bdev)  
  
--Construct the beginning for the RESTORE DATABASE command  
SET @sql = 'RESTORE DATABASE ' + @DbName + ' FROM DISK = ''' + @dirfile + ''' WITH MOVE '  
  
--Get information about database files from backup device into temp table  
TRUNCATE TABLE #dbfiles  
INSERT #dbfiles  
EXEC('RESTORE FILELISTONLY FROM DISK = ''' + @dirfile + '''')  
  
OPEN dbfiles  
FETCH NEXT FROM dbfiles INTO @LogicalName, @PhysicalName, @type  
--For each database file that the database uses  
WHILE @@FETCH_STATUS = 0  
BEGIN  
IF @type = 'D'  
SET @sql = @sql + '''' + @LogicalName + ''' TO ''' + @DestDirDbFiles + @DbName + '.mdf'', MOVE ' --@LogicalName +  
ELSE IF @type = 'L'  
SET @sql = @sql + '''' + @LogicalName + ''' TO ''' + @DestDirLogFiles + @DbName +'.ldf''' --  
FETCH NEXT FROM dbfiles INTO @LogicalName, @PhysicalName, @type  
END  
  
--Here's the actual RESTORE command  
PRINT @sql  
--Remove the comment below if you want the procedure to actually execute the restore command.  
--EXEC(@sql)  
CLOSE dbfiles  
FETCH NEXT FROM files INTO @fname  
END  
CLOSE files  
DEALLOCATE dbfiles  
DEALLOCATE files  
   
    