/*
Author: Sorna Kumar Muthuraj
https://gallery.technet.microsoft.com/scriptcenter/5ec149a1-a808-440c-a5c9-19fb083e4441
*/


IF OBJECT_ID('GetForeignKeyRelations','P') IS NOT NULL
    DROP PROC GetForeignKeyRelations
GO


CREATE PROC GetForeignKeyRelations
@Schemaname Sysname = 'dbo'
,@Tablename Sysname
,@WhereClause NVARCHAR(2000) = ''
,@GenerateDeleteScripts bit  = 0 
,@GenerateSelectScripts bit  = 0

AS

SET NOCOUNT ON

DECLARE @fkeytbl TABLE
(
ReferencingObjectid        int NULL
,ReferencingSchemaname  Sysname NULL
,ReferencingTablename   Sysname NULL 
,ReferencingColumnname  Sysname NULL
,PrimarykeyObjectid     int  NULL
,PrimarykeySchemaname   Sysname NULL
,PrimarykeyTablename    Sysname NULL
,PrimarykeyColumnname   Sysname NULL
,Hierarchy              varchar(max) NULL
,level                  int NULL
,rnk                    varchar(max) NULL
,Processed                bit default 0  NULL
);



WITH fkey (ReferencingObjectid,ReferencingSchemaname,ReferencingTablename,ReferencingColumnname
            ,PrimarykeyObjectid,PrimarykeySchemaname,PrimarykeyTablename,PrimarykeyColumnname,Hierarchy,level,rnk)
    AS
    (
        SELECT                  
                               soc.object_id
                              ,scc.name
                              ,soc.name
                              ,convert(sysname,null)
                              ,convert(int,null)
                              ,convert(sysname,null)
                              ,convert(sysname,null)
                              ,convert(sysname,null)
                              ,CONVERT(VARCHAR(MAX), scc.name + '.' + soc.name  ) as Hierarchy
                              ,0 as level
                              ,rnk=convert(varchar(max),soc.object_id)
        FROM SYS.objects soc
        JOIN sys.schemas scc
          ON soc.schema_id = scc.schema_id
       WHERE scc.name =@Schemaname
         AND soc.name =@Tablename
      UNION ALL
      SELECT                   sop.object_id
                              ,scp.name
                              ,sop.name
                              ,socp.name
                              ,soc.object_id
                              ,scc.name
                              ,soc.name
                              ,socc.name
                              ,CONVERT(VARCHAR(MAX), f.Hierarchy + ' --> ' + scp.name + '.' + sop.name ) as Hierarchy
                              ,f.level+1 as level
                              ,rnk=f.rnk + '-' + convert(varchar(max),sop.object_id)
        FROM SYS.foreign_key_columns sfc
        JOIN Sys.Objects sop
          ON sfc.parent_object_id = sop.object_id
        JOIN SYS.columns socp
          ON socp.object_id = sop.object_id
         AND socp.column_id = sfc.parent_column_id
        JOIN sys.schemas scp
          ON sop.schema_id = scp.schema_id
        JOIN SYS.objects soc
          ON sfc.referenced_object_id = soc.object_id
        JOIN SYS.columns socc
          ON socc.object_id = soc.object_id
         AND socc.column_id = sfc.referenced_column_id
        JOIN sys.schemas scc
          ON soc.schema_id = scc.schema_id
        JOIN fkey f
          ON f.ReferencingObjectid = sfc.referenced_object_id
        WHERE ISNULL(f.PrimarykeyObjectid,0) <> f.ReferencingObjectid
      )
        
     INSERT INTO @fkeytbl
     (ReferencingObjectid,ReferencingSchemaname,ReferencingTablename,ReferencingColumnname
            ,PrimarykeyObjectid,PrimarykeySchemaname,PrimarykeyTablename,PrimarykeyColumnname,Hierarchy,level,rnk)
     SELECT ReferencingObjectid,ReferencingSchemaname,ReferencingTablename,ReferencingColumnname
            ,PrimarykeyObjectid,PrimarykeySchemaname,PrimarykeyTablename,PrimarykeyColumnname,Hierarchy,level,rnk
       FROM fkey
        
        SELECT F.Relationshiptree
         FROM
        (
        SELECT DISTINCT Replicate('------',Level) + CASE LEVEL WHEN 0 THEN '' ELSE '>' END +  ReferencingSchemaname + '.' + ReferencingTablename 'Relationshiptree'
               ,RNK
          FROM @fkeytbl
          ) F
        ORDER BY F.rnk ASC
    
-------------------------------------------------------------------------------------------------------------------------------
-- Generate the Delete / Select script
-------------------------------------------------------------------------------------------------------------------------------

    DECLARE @Sql VARCHAR(MAX)
    DECLARE @RnkSql VARCHAR(MAX)

    DECLARE @Jointables TABLE
    (
    ID INT IDENTITY
    ,Object_id int
    )

    DECLARE @ProcessTablename SYSNAME
    DECLARE @ProcessSchemaName SYSNAME

    DECLARE @JoinConditionSQL VARCHAR(MAX)
    DECLARE @Rnk VARCHAR(MAX)
    DECLARE @OldTablename SYSNAME
    
    IF @GenerateDeleteScripts = 1 or @GenerateSelectScripts = 1 
    BEGIN

          WHILE EXISTS ( SELECT 1
                           FROM @fkeytbl
                          WHERE Processed = 0
                            AND level > 0 )
          BEGIN
          
            SELECT @ProcessTablename = ''
            SELECT @Sql                 = ''
            SELECT @JoinConditionSQL = ''
            SELECT @OldTablename     = ''
            
          
            SELECT TOP 1 @ProcessTablename = ReferencingTablename
                  ,@ProcessSchemaName  = ReferencingSchemaname
                  ,@Rnk = RNK 
              FROM @fkeytbl
             WHERE Processed = 0
              AND level > 0 
             ORDER BY level DESC


            SELECT @RnkSql ='SELECT ' + REPLACE (@rnk,'-',' UNION ALL SELECT ') 

            DELETE FROM @Jointables

            INSERT INTO @Jointables
            EXEC(@RnkSql)

            IF @GenerateDeleteScripts = 1
                SELECT @Sql = 'DELETE [' + @ProcessSchemaName + '].[' + @ProcessTablename + ']' + CHAR(10) + ' FROM [' + @ProcessSchemaName + '].[' + @ProcessTablename + ']' + CHAR(10)

            IF @GenerateSelectScripts = 1
                SELECT @Sql = 'SELECT  [' + @ProcessSchemaName + '].[' + @ProcessTablename + '].*' + CHAR(10) + ' FROM [' + @ProcessSchemaName + '].[' + @ProcessTablename + ']' + CHAR(10)

            SELECT @JoinConditionSQL = @JoinConditionSQL 
                                           + CASE 
                                             WHEN @OldTablename <> f.PrimarykeyTablename THEN  'JOIN ['  + f.PrimarykeySchemaname  + '].[' + f.PrimarykeyTablename + '] ' + CHAR(10) + ' ON '
                                             ELSE ' AND ' 
                                             END
                                           + ' ['  + f.PrimarykeySchemaname  + '].[' + f.PrimarykeyTablename + '].[' + f.PrimarykeyColumnname + '] =  ['  + f.ReferencingSchemaname  + '].[' + f.ReferencingTablename + '].[' + f.ReferencingColumnname + ']' + CHAR(10) 
                     , @OldTablename = CASE 
                                         WHEN @OldTablename <> f.PrimarykeyTablename THEN  f.PrimarykeyTablename
                                         ELSE @OldTablename
                                         END
            
                  FROM @fkeytbl f
                  JOIN @Jointables j
                    ON f.Referencingobjectid  = j.Object_id
                 WHERE charindex(f.rnk + '-',@Rnk + '-') <> 0
                   AND F.level > 0
                 ORDER BY J.ID DESC
                 
            SELECT @Sql = @Sql +  @JoinConditionSQL

            IF LTRIM(RTRIM(@WhereClause)) <> '' 
                SELECT @Sql = @Sql + ' WHERE (' + @WhereClause + ')'

            PRINT @SQL
            PRINT CHAR(10)
            
            UPDATE @fkeytbl
               SET Processed = 1
             WHERE ReferencingTablename = @ProcessTablename
               AND rnk = @Rnk
          
          END

          IF @GenerateDeleteScripts = 1
            SELECT @Sql = 'DELETE FROM [' + @Schemaname + '].[' + @Tablename + ']'

          IF @GenerateSelectScripts = 1
            SELECT @Sql = 'SELECT * FROM [' + @Schemaname + '].[' + @Tablename + ']'

          IF LTRIM(RTRIM(@WhereClause)) <> '' 
                SELECT @Sql = @Sql  + ' WHERE ' + @WhereClause

         PRINT @SQL
     END

SET NOCOUNT OFF 