SET NOCOUNT ON
DECLARE @name VARCHAR( 50) -- database name
DECLARE @path VARCHAR( 256) -- path for backup files
DECLARE @fileName NVARCHAR( 256) -- filename for backup

SET @path = 'C:\Backup\'

IF OBJECT_ID ('tempdb..#DirectoryTree') IS NOT NULL
      DROP TABLE #DirectoryTree;

CREATE TABLE #DirectoryTree (
       id int IDENTITY( 1,1 )
      ,subdirectory nvarchar(512 )
      ,depth int
      ,isfile bit)

INSERT #DirectoryTree (subdirectory ,depth, isfile) EXEC master .sys. xp_dirtree @path ,1, 1;


WHILE (exists(SELECT TOP 1 * FROM #DirectoryTree ))
 BEGIN
       Select TOP 1 @name= subdirectory from #DirectoryTree
       SET @fileName = @path + @name
       RESTORE VERIFYONLY FROM DISK = @fileName --WITH CHECKSUM       
          SELECT @fileName
          delete from #DirectoryTree WHERE subdirectory = @name
          Select TOP 1 @name= subdirectory from #DirectoryTree
 END
  
