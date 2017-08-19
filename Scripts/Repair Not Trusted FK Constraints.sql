/* 
Repair Not Trusted FK Constraints 
 
If you bulk insert data into a table with a foreign key constraint or with disable FK check, then this FK constraint will be marked as "not trusted". 
This can cause performance issues, because the query optimizer may don't use a related index for this constraint. 
 
This script selects all not trusted foreign key and generate a "repair" SQL Statement, which includes an error handling + logging with TRY/CATCH blocks for each statement. 
Copy the query result into a new query window and execute it to repair the constraints 
 
See MSDN ALTER TABLE (Transact-SQL) => option "WITH CHECK | WITH NOCHECK" 
http://msdn.microsoft.com/en-us/library/ms190273.aspx 
 
*/ 
 
SELECT N'BEGIN TRY ALTER TABLE ' + QUOTENAME(SCH.name) + N'.' + QUOTENAME(TBL.name) + 
                N' WITH CHECK CHECK CONSTRAINT ' + QUOTENAME(FK.name) + N'; END TRY ' + CHAR(13) + CHAR(10) + 
       N'BEGIN CATCH PRINT ERROR_MESSAGE(); END CATCH;' AS AlterCommand 
  FROM sys.foreign_keys AS FK 
       INNER JOIN sys.objects AS TBL 
           ON FK.parent_object_id = TBL.object_id 
       INNER JOIN sys.schemas AS SCH 
           ON FK.schema_id = SCH.schema_id 
 WHERE FK.is_not_trusted = 1 
 ORDER BY SCH.name, TBL.name, FK.name;