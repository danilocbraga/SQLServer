IF OBJECT_ID('GenerateTriggers','P') IS NOT NULL
DROP PROC GenerateTriggers
GO

CREATE PROC GenerateTriggers
@Schemaname Sysname = 'dbo'
,@Tablename Sysname
,@GenerateScriptOnly bit = 1
AS

SET NOCOUNT ON

/*
Parameters
@Schemaname - SchemaName to which the table belongs to. Default value 'dbo'.
@Tablename - TableName for which the procs needs to be generated.
@GenerateScriptOnly - When passed 1 , this will generate the scripts alone..
When passed 0 , this will create the audit tables and triggers in the current database.
Default value is 1
*/

DECLARE @SQL VARCHAR(MAX)
DECLARE @SQLTrigger VARCHAR(MAX)
DECLARE @AuditTableName SYSNAME

SELECT @AuditTableName = @Tablename + '_Audit'

----------------------------------------------------------------------------------------------------------------------
-- Audit Create table
----------------------------------------------------------------------------------------------------------------------

DECLARE @ColList VARCHAR(MAX)

SELECT @ColList = ''

SELECT @ColList = @ColList + CASE SC.is_identity
WHEN 1 THEN 'CONVERT(' + ST.name + ',' + QUOTENAME(SC.name) + ') as ' + QUOTENAME(SC.name)
ELSE QUOTENAME(SC.name)
END + ','
FROM SYS.COLUMNS SC
JOIN SYS.OBJECTS SO
ON SC.object_id = SO.object_id
JOIN SYS.schemas SCH
ON SCH.schema_id = SO.schema_id
JOIN SYS.types ST
ON ST.user_type_id = SC.user_type_id
AND ST.system_type_id = SC.system_type_id
WHERE SCH.Name = @Schemaname
AND SO.name = @Tablename

SELECT @ColList = SUBSTRING(@ColList,1,LEN(@ColList)-1)

SELECT @SQL = '
IF EXISTS (SELECT 1
FROM sys.objects
WHERE Name=''' + @AuditTableName + '''
AND Schema_id=Schema_id(''' + @Schemaname + ''')
AND Type = ''U'')

DROP TABLE ' + @Schemaname + '.' + @AuditTableName + '

SELECT ' + @ColList + '
,AuditDataState=CONVERT(VARCHAR(10),'''')
,AuditDMLAction=CONVERT(VARCHAR(10),'''')
,AuditUser =CONVERT(SYSNAME,'''')
,AuditDateTime=CONVERT(DATETIME,''01-JAN-1900'')
Into ' + @Schemaname + '.' + @AuditTableName + '
FROM ' + @Schemaname + '.' + @Tablename +'
WHERE 1=2 '

IF @GenerateScriptOnly = 1
BEGIN
PRINT REPLICATE ('-',200)
PRINT '--Create Script Audit table for ' + @Schemaname + '.' + @Tablename
PRINT REPLICATE ('-',200)
PRINT @SQL
PRINT 'GO'
END
ELSE
BEGIN
PRINT 'Creating Audit table for ' + @Schemaname + '.' + @Tablename
EXEC(@SQL)
PRINT 'Audit table ' + @Schemaname + '.' + @AuditTableName + ' Created succefully'
END


----------------------------------------------------------------------------------------------------------------------
-- Create Insert Trigger
----------------------------------------------------------------------------------------------------------------------


SELECT @SQL = '
IF EXISTS (SELECT 1
FROM sys.objects
WHERE Name=''' + @Tablename + '_Insert' + '''
AND Schema_id=Schema_id(''' + @Schemaname + ''')
AND Type = ''TR'')
DROP TRIGGER ' + @Tablename + '_Insert
'
SELECT @SQLTrigger = '
CREATE TRIGGER ' + @Tablename + '_Insert
ON '+ @Schemaname + '.' + @Tablename + '
FOR INSERT
AS

INSERT INTO ' + @Schemaname + '.' + @AuditTableName + '
SELECT *,''New'',''Insert'',SUSER_SNAME(),getdate() FROM INSERTED

'

IF @GenerateScriptOnly = 1
BEGIN
PRINT REPLICATE ('-',200)
PRINT '--Create Script Insert Trigger for ' + @Schemaname + '.' + @Tablename
PRINT REPLICATE ('-',200)
PRINT @SQL
PRINT 'GO'
PRINT @SQLTrigger
PRINT 'GO'
END
ELSE
BEGIN
PRINT 'Creating Insert Trigger ' + @Tablename + '_Insert for ' + @Schemaname + '.' + @Tablename
EXEC(@SQL)
EXEC(@SQLTrigger)
PRINT 'Trigger ' + @Schemaname + '.' + @Tablename + '_Insert Created succefully'
END


----------------------------------------------------------------------------------------------------------------------
-- Create Delete Trigger
----------------------------------------------------------------------------------------------------------------------


SELECT @SQL = '

IF EXISTS (SELECT 1
FROM sys.objects
WHERE Name=''' + @Tablename + '_Delete' + '''
AND Schema_id=Schema_id(''' + @Schemaname + ''')
AND Type = ''TR'')
DROP TRIGGER ' + @Tablename + '_Delete
'

SELECT @SQLTrigger =
'
CREATE TRIGGER ' + @Tablename + '_Delete
ON '+ @Schemaname + '.' + @Tablename + '
FOR DELETE
AS

INSERT INTO ' + @Schemaname + '.' + @AuditTableName + '
SELECT *,''Old'',''Delete'',SUSER_SNAME(),getdate() FROM DELETED
'

IF @GenerateScriptOnly = 1
BEGIN
PRINT REPLICATE ('-',200)
PRINT '--Create Script Delete Trigger for ' + @Schemaname + '.' + @Tablename
PRINT REPLICATE ('-',200)
PRINT @SQL
PRINT 'GO'
PRINT @SQLTrigger
PRINT 'GO'
END
ELSE
BEGIN
PRINT 'Creating Delete Trigger ' + @Tablename + '_Delete for ' + @Schemaname + '.' + @Tablename
EXEC(@SQL)
EXEC(@SQLTrigger)
PRINT 'Trigger ' + @Schemaname + '.' + @Tablename + '_Delete Created succefully'
END

----------------------------------------------------------------------------------------------------------------------
-- Create Update Trigger
----------------------------------------------------------------------------------------------------------------------


SELECT @SQL = '

IF EXISTS (SELECT 1
FROM sys.objects
WHERE Name=''' + @Tablename + '_Update' + '''
AND Schema_id=Schema_id(''' + @Schemaname + ''')
AND Type = ''TR'')
DROP TRIGGER ' + @Tablename + '_Update
'

SELECT @SQLTrigger =
'
CREATE TRIGGER ' + @Tablename + '_Update
ON '+ @Schemaname + '.' + @Tablename + '
FOR UPDATE
AS

INSERT INTO ' + @Schemaname + '.' + @AuditTableName + '
SELECT *,''New'',''Update'',SUSER_SNAME(),getdate() FROM INSERTED

INSERT INTO ' + @Schemaname + '.' + @AuditTableName + '
SELECT *,''Old'',''Update'',SUSER_SNAME(),getdate() FROM DELETED
'

IF @GenerateScriptOnly = 1
BEGIN
PRINT REPLICATE ('-',200)
PRINT '--Create Script Update Trigger for ' + @Schemaname + '.' + @Tablename
PRINT REPLICATE ('-',200)
PRINT @SQL
PRINT 'GO'
PRINT @SQLTrigger
PRINT 'GO'
END
ELSE
BEGIN
PRINT 'Creating Delete Trigger ' + @Tablename + '_Update for ' + @Schemaname + '.' + @Tablename
EXEC(@SQL)
EXEC(@SQLTrigger)
PRINT 'Trigger ' + @Schemaname + '.' + @Tablename + '_Update Created succefully'
END

SET NOCOUNT OFF