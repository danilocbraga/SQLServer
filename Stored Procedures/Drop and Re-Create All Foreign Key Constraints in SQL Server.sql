IF OBJECT_ID('dbo.foreign_key$script', 'FN') IS NOT NULL
DROP FUNCTION dbo.foreign_key$script
GO
CREATE FUNCTION dbo.foreign_key$script( 
    @schema_name sysname, 
    @foreign_key_name sysname, 
    @constraint_status VARCHAR(20) = 'AS_WAS' --ENABLED, UNTRUSTED, DISABLED 
                                               --ANY OTHER VALUES RETURN NULL 
) 
-------------------------------------------------- 
-- Use to script a foreign key constraint 
-- 
-- 2017  Louis Davidson  drsql.org 
--   Thanks to Aaron Bertrand and John Paul Cook's code 
/*

EXEC dbo.foreign_key$batch_drop
    @table_Schema  = 'dbo', 
    @table_Name  = 'TableName', 
    @add_to_history_flag  = 1, 
    @force_replace_status = 'AS_WAS' --ENABLED, UNTRUSTED, DISABLED 

SELECT table_schema AS schemaName, table_name AS tableName, constraint_name AS constraintName, 
	   disabled_flag AS disabledFlag, recreate_script AS statement, trusted_flag 
FROM   dbo.foreign_key$batch_drop_toRestore

EXEC foreign_key$batch_recreate        
*/
-------------------------------------------------- 
RETURNS NVARCHAR(MAX) 
AS 
BEGIN 
    --based on code to gen list of FK constraints from this article by Aaron Bertrand 
    --https://www.mssqltips.com/sqlservertip/3347/drop-and-recreate-all-foreign-key-constraints-in-sql-server/

    --and code from John Paul Cook: 
    --https://social.technet.microsoft.com/wiki/contents/articles/2958.script-to-create-all-foreign-keys.aspx

    DECLARE @script NVARCHAR(MAX);

    IF @constraint_status NOT IN ('AS_WAS','ENABLED','UNTRUSTED','DISABLED') 
        RETURN NULL;

    SELECT @script 
        =  N'ALTER TABLE ' + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) + CHAR(13) + CHAR(10) + '   ' 
            --code added to set the constraint's status if it is not to be checked (and 
            --in the case of disabled, you create it not trusted and disable it 
          + CASE 
                WHEN(is_not_trusted = 1 
                     OR fk.is_disabled = 1 
                      OR @constraint_status IN ( 'UNTRUSTED', 'DISABLED' )) 
                    --not forcing it to be enabled 
                     AND @constraint_status <> 'ENABLED' THEN 
                     'WITH NOCHECK ' 
                ELSE 
                     '' 
            END 
          + 'ADD CONSTRAINT ' + QUOTENAME(fk.name) + CHAR(13) + CHAR(10) + 
          '      FOREIGN KEY (' 
          + STUFF((SELECT   ',' + QUOTENAME(c.name) 
                    -- get all the columns in the constraint table 
                    FROM     sys.columns c 
                            INNER JOIN sys.foreign_key_columns fkc 
                                 ON fkc.parent_column_id = c.column_id 
                                    AND fkc.parent_object_id = c.object_id 
                    WHERE    fkc.constraint_object_id = fk.object_id 
                    ORDER BY fkc.constraint_column_id 
        FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'),1,1,N'') 
           + ')' + CHAR(13) + CHAR(10) + '         REFERENCES ' + QUOTENAME(rs.name) + '.' + QUOTENAME(rt.name) 
           + '(' 
           + STUFF((SELECT   ',' + QUOTENAME(c.name) 
                    -- get all the referenced columns 
                   FROM     sys.columns c 
                            INNER JOIN sys.foreign_key_columns fkc 
                                ON fkc.referenced_column_id = c.column_id 
                                   AND fkc.referenced_object_id = c.object_id 
                   WHERE    fkc.constraint_object_id = fk.object_id 
                   ORDER BY fkc.constraint_column_id 
        FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'),1,1, N'') + ')' 
         + CASE fk.update_referential_action 
                WHEN 1 THEN CHAR(13) + CHAR(10) + '         ON UPDATE CASCADE ' 
                WHEN 2 THEN CHAR(13) + CHAR(10) + '         ON UPDATE SET NULL ' 
                 WHEN 3 THEN CHAR(13) + CHAR(10) + '         ON UPDATE SET DEFAULT ' 
                ELSE '' --could also say "no action" which is the default 
           END 
          + CASE fk.delete_referential_action 
                WHEN 1 THEN CHAR(13) + CHAR(10) + '         ON DELETE CASCADE ' 
                WHEN 2 THEN CHAR(13) + CHAR(10) + '         ON DELETE SET NULL ' 
                 WHEN 3 THEN CHAR(13) + CHAR(10) + '         ON DELETE SET DEFAULT ' 
                ELSE '' --could also say "no action" which is the default 
            END 
          + CASE fk.is_not_for_replication 
                WHEN 1 THEN CHAR(13) + CHAR(10) + '         NOT FOR REPLICATION ' 
                ELSE '' 
             END 
          + ';' 
          + CASE 
                WHEN(fk.is_disabled = 1 AND @constraint_status IN ( 'DISABLED', 'AS_WAS' )) 
                     OR @constraint_status = 'DISABLED' 
                     THEN CHAR(13) + CHAR(10)+  CHAR(13) + CHAR(10)+   'ALTER TABLE ' + QUOTENAME(cs.name) + '.' 
                          + QUOTENAME(ct.name) + CHAR(13) + CHAR(10) 
                           + '   NOCHECK CONSTRAINT ' + QUOTENAME(fk.name) + ';' 
                 ELSE 
                    '' 
            END 
    FROM   sys.foreign_keys fk 
           INNER JOIN sys.tables rt 
                -- referenced table 
               ON fk.referenced_object_id = rt.object_id 
           INNER JOIN sys.schemas rs 
                ON rt.schema_id = rs.schema_id 
           INNER JOIN sys.tables ct 
               -- constraint table 
               ON fk.parent_object_id = ct.object_id 
           INNER JOIN sys.schemas cs 
               ON ct.schema_id = cs.schema_id 
    WHERE  OBJECT_SCHEMA_NAME(fk.object_id) = @schema_name 
           AND fk.name = @foreign_key_name; 
    RETURN @script; 
END;

/*
Author: Louis Davidson
Original link: http://sqlblog.com/blogs/louis_davidson/archive/2017/06/15/utility-to-temporarily-drop-foreign-key-constraints-on-a-set-of-tables.aspx
Desctiption: Utility to temporarily drop FOREIGN KEY constraints on a set of tables
*/

GO
 
IF OBJECT_ID('dbo.foreign_key$batch_drop', 'P') IS NULL
EXECUTE('CREATE PROCEDURE dbo.foreign_key$batch_drop as SELECT 1');
GO

ALTER PROCEDURE dbo.foreign_key$batch_drop
( 
    @table_Schema sysname = '%', 
    @table_Name sysname = '%', 
    @add_to_history_flag BIT = 0, 
    @force_replace_status  VARCHAR(20) = 'AS_WAS' --ENABLED, UNTRUSTED, DISABLED 
) AS
-- ---------------------------------------------------------------- 
-- Used to drop foreign keys, saving off what to recreate by batch name 
-- 
-- 2017 Louis Davidson - drsql.org 
-- ----------------------------------------------------------------
 
BEGIN
    IF OBJECT_ID('dbo.foreign_key$batch_drop_toRestore') IS  NULL
            EXEC (' 
            CREATE TABLE dbo.foreign_key$batch_drop_toRestore
            ( 
                table_schema    sysname NOT null, 
                table_name        sysname NOT null, 
                constraint_name    sysname NOT null, 
                recreate_script  NVARCHAR(MAX) NOT null, 
                disabled_flag   BIT NOT null, 
                trusted_flag bit NOT NULL 
            ) 
            ') 
    ELSE
    IF @add_to_history_flag = 0 
          BEGIN
            THROW 50000,'Parameter @add_to_history_flag set to only allow initialize case',1; 
            RETURN -100 
          END
 
    set nocount on
    declare @statements cursor
    SET @statements = CURSOR FOR
           WITH FK AS ( 
                        SELECT OBJECT_SCHEMA_NAME(parent_object_id) AS schemaName, OBJECT_NAME(parent_object_id) AS tableName, 
                               NAME AS constraintName, foreign_keys.is_disabled AS disabledFlag, 
                               IIF(foreign_keys.is_not_trusted = 1e,0,1) AS trustedFlag 
                        FROM   sys.foreign_keys 
                        ) 
                        SELECT schemaName, tableName, constraintName, disabledFlag, FK.trustedFlag 
                        FROM   FK 
                        WHERE  schemaName LIKE @table_Schema 
                          AND  tableName LIKE @table_Name
 
                          ORDER BY schemaName, tableName, constraintName
 
    OPEN @statements
 
    DECLARE  @statement VARCHAR(1000), @schemaName sysname, @tableName sysname, @constraintName sysname, 
             @constraintType sysname,@disabledFlag BIT, @trustedFlag BIT; 
     
    WHILE 1=1 
     BEGIN
           FETCH FROM @statements INTO @schemaName, @tableName, @constraintName, @disabledFlag, @trustedFlag 
               IF @@FETCH_STATUS <> 0 
                    BREAK
 
               BEGIN TRY 
                   BEGIN TRANSACTION
 
                    INSERT INTO dbo.foreign_key$batch_drop_toRestore (table_schema, table_name, constraint_name, 
                                                                                    recreate_script, disabled_flag, trusted_flag) 
                    SELECT  @schemaName 
                             , @tableName 
                             , @constraintName 
                             , dbo.foreign_key$script(@schemaName, @constraintName,@force_replace_status) -- must be before the drop 
                             , @disabledFlag 
                             , @trustedFlag
 
 
                    SELECT @statement = 'ALTER TABLE ' + @schemaName + '.' + @tableName + ' DROP ' + @constraintName
 
                    EXEC (@statement) 
                     
                    COMMIT TRANSACTION
 
               END TRY 
              BEGIN CATCH 
              IF XACT_STATE() <> 0 
                ROLLBACK
 
              DECLARE @msg NVARCHAR(2000) = 
                    CONCAT('Error occurred: ' , CAST(ERROR_NUMBER() AS VARCHAR(10)) , ':'
                            , ERROR_MESSAGE() , CHAR(13) , CHAR(10) , 
                            'Statement executed: ' ,  @statement); 
              THROW 50000,@msg,1;
 
           END CATCH
 
 
     END
 
END
GO
 

IF OBJECT_ID('dbo.foreign_key$batch_recreate', 'P') IS NULL
EXECUTE('CREATE PROCEDURE dbo.foreign_key$batch_recreate as SELECT 1');
GO

ALTER PROCEDURE dbo.foreign_key$batch_recreate 
AS 
-- ---------------------------------------------------------------- 
-- Used to enable constraints 
-- 
-- 2017 Louis Davidson - drsql.org 
-- ----------------------------------------------------------------
 
BEGIN
    IF OBJECT_ID('dbo.foreign_key$batch_drop_toRestore') IS  NULL
          BEGIN
            THROW 50000,'Table dbo.foreign_key$batch_drop_toRestore must exist, as this is where the objects to resore are stored',1; 
            RETURN -100 
          END
   
     set nocount on
    declare @statements cursor
    SET @statements = CURSOR FOR
        SELECT table_schema AS schemaName, table_name AS tableName, constraint_name AS constraintName, 
               disabled_flag AS disabledFlag, recreate_script AS statement, trusted_flag 
        FROM   dbo.foreign_key$batch_drop_toRestore        
 
    OPEN @statements
 
    DECLARE   @schemaName sysname, @tableName sysname, @constraintName sysname, 
             @disabledFlag BIT, @trustedFlag BIT, @codelocation VARCHAR(200), @statement NVARCHAR(MAX); 
     
 
    WHILE 1=1 
     BEGIN
           FETCH FROM @statements INTO @schemaName, @tableName, @constraintName, @disabledFlag, @statement, @trustedFlag 
               IF @@FETCH_STATUS <> 0 
                    BREAK
 
               BEGIN TRY 
                   BEGIN TRANSACTION
 
                    EXEC (@statement) 
                    --PRINT @statement
 
                    DELETE FROM  dbo.foreign_key$batch_drop_toRestore 
                    WHERE table_schema = @schemaName 
                      AND table_name = @tableName 
                      AND constraint_name = @constraintName 
                     
                    COMMIT TRANSACTION
 
               END TRY 
              BEGIN CATCH 
              IF XACT_STATE() = 0 
                ROLLBACK; 
              DECLARE @msg NVARCHAR(2000) = 
                    'Error occurred: ' + CAST(ERROR_NUMBER() AS VARCHAR(10))+ ':' + ERROR_MESSAGE() + CHAR(13) + CHAR(10) + 
                                        'Statement executed: ' +  @statement; 
              THROW 50000, @msg, 1; 
                
           END CATCH
 
 
     END
 
     DROP TABLE dbo.foreign_key$batch_drop_toRestore;
 
 
END
GO
