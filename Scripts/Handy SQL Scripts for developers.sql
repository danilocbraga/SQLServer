-- Printing Table Column Definitions
SELECT
sh.name+'.'+o.name AS ObjectName,
s.name as ColumnName
,CASE
    WHEN t.name IN ('char','varchar') THEN t.name+'('+CASE WHEN s.max_length<0 then 'MAX' ELSE CONVERT(varchar(10),s.max_length) END+')'
    WHEN t.name IN ('nvarchar','nchar') THEN t.name+'('+CASE WHEN s.max_length<0 then 'MAX' ELSE CONVERT(varchar(10),s.max_length/2) END+')'
    WHEN t.name IN ('numeric') THEN t.name+'('+CONVERT(varchar(10),s.precision)+','+CONVERT(varchar(10),s.scale)+')'
    ELSE t.name
END AS DataType
,CASE
     WHEN s.is_nullable=1 THEN 'NULL'
    ELSE 'NOT NULL'
END AS Nullable       
FROM sys.columns s
INNER JOIN sys.types t ON s.system_type_id=t.user_type_id and t.is_user_defined=0
INNER JOIN sys.objects o ON s.object_id=o.object_id
INNER JOIN sys.schemas sh on o.schema_id=sh.schema_id
WHERE O.name IN (select table_name from information_schema.tables) 
	--AND o.name like '%%'
ORDER BY sh.name+'.'+o.name,s.column_id


-- Find all tables that contain a certain column
SELECT c.TABLE_NAME,
TABLE_TYPE,
COLUMN_NAME,
ORDINAL_POSITION,
IS_NULLABLE,
DATA_TYPE,
NUMERIC_PRECISION
FROM INFORMATION_SCHEMA.COLUMNS c
JOIN INFORMATION_SCHEMA.TABLES t ON c.TABLE_NAME = t.TABLE_NAME
--WHERE COLUMN_NAME like '%%'
ORDER BY TABLE_TYPE ,c.TABLE_NAME


-- Find Primary Keys and Columns Used in a specific database
select cons.TABLE_NAME
    , cons.CONSTRAINT_NAME PK_NAME
    , cols.COLUMN_NAME
from INFORMATION_SCHEMA.TABLE_CONSTRAINTS cons
left join INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE cols
on cons.CONSTRAINT_NAME = cols.CONSTRAINT_NAME
where cons.CONSTRAINT_TYPE = 'PRIMARY KEY'
order by cons.TABLE_NAME
    , cons.CONSTRAINT_NAME
    , cols.COLUMN_NAME


-- Return all the columns in the database which allow NULLS
select table_name,column_name
from information_schema.columns
where is_nullable ='YES'
order by table_name,column_name

-- Search for Text Inside All the SQL Procedures
SELECT DISTINCT o.name AS Object_Name,o.type_desc
FROM sys.sql_modules m
INNER JOIN sys.objects o
ON m.object_id=o.object_id
WHERE m.definition Like '%%'


-- List the defined constraints on tables with the column names
SELECT    a.table_name,
          a.constraint_name,
          b.column_name,
          a.constraint_type
FROM      information_schema.table_constraints a,
          information_schema.key_column_usage b
WHERE     a.table_name = 'employeeidentification'
AND       a.table_name = b.table_name
AND       a.table_schema = b.table_schema
AND       a.constraint_name = b.constraint_name;


-- Generate script of tables with their constraints 
DECLARE @object_id INT, @object_name SYSNAME
DECLARE cur CURSOR FAST_FORWARD READ_ONLY LOCAL FOR

    SELECT o.[object_id], '[' + s.name + '].[' + o.name + ']'
    FROM sys.objects o WITH (NOWAIT)
    JOIN sys.schemas s WITH (NOWAIT) ON o.[schema_id] = s.[schema_id]
    WHERE o.[type] = 'U'
        AND o.is_ms_shipped = 0

OPEN cur
FETCH NEXT FROM cur INTO @object_id, @object_name

WHILE @@FETCH_STATUS = 0 BEGIN

    DECLARE @SQL NVARCHAR(MAX) = ''
    ;WITH index_column AS 
    (	SELECT 
              ic.[object_id]
            , ic.index_id
            , ic.is_descending_key
            , ic.is_included_column
            , c.name
        FROM sys.index_columns ic WITH (NOWAIT)
        JOIN sys.columns c WITH (NOWAIT) ON ic.[object_id] = c.[object_id] AND ic.column_id = c.column_id
        WHERE ic.[object_id] = @object_id
    ),
    fk_columns AS 
    (	SELECT 
              k.constraint_object_id
            , cname = c.name
            , rcname = rc.name
        FROM sys.foreign_key_columns k WITH (NOWAIT)
        JOIN sys.columns rc WITH (NOWAIT) ON rc.[object_id] = k.referenced_object_id AND rc.column_id = k.referenced_column_id 
        JOIN sys.columns c WITH (NOWAIT) ON c.[object_id] = k.parent_object_id AND c.column_id = k.parent_column_id
        WHERE k.parent_object_id = @object_id
    )
    SELECT @SQL = 'CREATE TABLE ' + @object_name + CHAR(13) + '(' + CHAR(13) + STUFF((
        SELECT CHAR(9) + ', [' + c.name + '] ' + 
            CASE WHEN c.is_computed = 1
                THEN 'AS ' + cc.[definition] 
                ELSE UPPER(tp.name) + 
                    CASE WHEN tp.name IN ('varchar', 'char', 'varbinary', 'binary', 'text')
                           THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR(5)) END + ')'
                         WHEN tp.name IN ('nvarchar', 'nchar', 'ntext')
                           THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length / 2 AS VARCHAR(5)) END + ')'
                         WHEN tp.name IN ('datetime2', 'time2', 'datetimeoffset') 
                           THEN '(' + CAST(c.scale AS VARCHAR(5)) + ')'
                         WHEN tp.name = 'decimal' 
                           THEN '(' + CAST(c.[precision] AS VARCHAR(5)) + ',' + CAST(c.scale AS VARCHAR(5)) + ')'
                        ELSE ''
                    END +
                    CASE WHEN c.is_nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END +
                    CASE WHEN dc.[definition] IS NOT NULL THEN ' DEFAULT' + dc.[definition] ELSE '' END + 
                    CASE WHEN ic.is_identity = 1 THEN ' IDENTITY(' + CAST(ISNULL(ic.seed_value, '0') AS CHAR(1)) + ',' + CAST(ISNULL(ic.increment_value, '1') AS CHAR(1)) + ')' ELSE '' END 
            END + CHAR(13)
        FROM sys.columns c WITH (NOWAIT)
        JOIN sys.types tp WITH (NOWAIT) ON c.user_type_id = tp.user_type_id
        LEFT JOIN sys.computed_columns cc WITH (NOWAIT) ON c.[object_id] = cc.[object_id] AND c.column_id = cc.column_id
        LEFT JOIN sys.default_constraints dc WITH (NOWAIT) ON c.default_object_id != 0 AND c.[object_id] = dc.parent_object_id AND c.column_id = dc.parent_column_id
        LEFT JOIN sys.identity_columns ic WITH (NOWAIT) ON c.is_identity = 1 AND c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
        WHERE c.[object_id] = @object_id
        ORDER BY c.column_id
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, CHAR(9) + ' ')
        + ISNULL((SELECT CHAR(9) + ', CONSTRAINT [' + k.name + '] PRIMARY KEY (' + 
                        (SELECT STUFF((
                             SELECT ', [' + c.name + '] ' + CASE WHEN ic.is_descending_key = 1 THEN 'DESC' ELSE 'ASC' END
                             FROM sys.index_columns ic WITH (NOWAIT)
                             JOIN sys.columns c WITH (NOWAIT) ON c.[object_id] = ic.[object_id] AND c.column_id = ic.column_id
                             WHERE ic.is_included_column = 0
                                 AND ic.[object_id] = k.parent_object_id 
                                 AND ic.index_id = k.unique_index_id     
                             FOR XML PATH(N''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, ''))
                + ')' + CHAR(13)
                FROM sys.key_constraints k WITH (NOWAIT)
                WHERE k.parent_object_id = @object_id 
                    AND k.[type] = 'PK'), '') + ')'  + CHAR(13)
        + ISNULL((SELECT (
            SELECT CHAR(13) +
                 'ALTER TABLE ' + @object_name + ' WITH' 
                + CASE WHEN fk.is_not_trusted = 1 
                    THEN ' NOCHECK' 
                    ELSE ' CHECK' 
                  END + 
                  ' ADD CONSTRAINT [' + fk.name  + '] FOREIGN KEY(' 
                  + STUFF((
                    SELECT ', [' + k.cname + ']'
                    FROM fk_columns k
                    WHERE k.constraint_object_id = fk.[object_id]
                    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
                   + ')' +
                  ' REFERENCES [' + SCHEMA_NAME(ro.[schema_id]) + '].[' + ro.name + '] ('
                  + STUFF((
                    SELECT ', [' + k.rcname + ']'
                    FROM fk_columns k
                    WHERE k.constraint_object_id = fk.[object_id]
                    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
                   + ')'
                + CASE 
                    WHEN fk.delete_referential_action = 1 THEN ' ON DELETE CASCADE' 
                    WHEN fk.delete_referential_action = 2 THEN ' ON DELETE SET NULL'
                    WHEN fk.delete_referential_action = 3 THEN ' ON DELETE SET DEFAULT' 
                    ELSE '' 
                  END
                + CASE 
                    WHEN fk.update_referential_action = 1 THEN ' ON UPDATE CASCADE'
                    WHEN fk.update_referential_action = 2 THEN ' ON UPDATE SET NULL'
                    WHEN fk.update_referential_action = 3 THEN ' ON UPDATE SET DEFAULT'  
                    ELSE '' 
                  END 
                + CHAR(13) + 'ALTER TABLE ' + @object_name + ' CHECK CONSTRAINT [' + fk.name  + ']' + CHAR(13)
            FROM sys.foreign_keys fk WITH (NOWAIT)
            JOIN sys.objects ro WITH (NOWAIT) ON ro.[object_id] = fk.referenced_object_id
            WHERE fk.parent_object_id = @object_id
            FOR XML PATH(N''), TYPE).value('.', 'NVARCHAR(MAX)')), '')
        + ISNULL(((SELECT
             CHAR(13) + 'CREATE' + CASE WHEN i.is_unique = 1 THEN ' UNIQUE' ELSE '' END 
                    + ' NONCLUSTERED INDEX [' + i.name + '] ON ' + @object_name + ' (' +
                    STUFF((
                    SELECT ', [' + c.name + ']' + CASE WHEN c.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
                    FROM index_column c
                    WHERE c.is_included_column = 0
                        AND c.index_id = i.index_id
                    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ')'  
                    + ISNULL(CHAR(13) + 'INCLUDE (' + 
                        STUFF((
                        SELECT ', [' + c.name + ']'
                        FROM index_column c
                        WHERE c.is_included_column = 1
                            AND c.index_id = i.index_id
                        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + ')', '')  + CHAR(13)
            FROM sys.indexes i WITH (NOWAIT)
            WHERE i.[object_id] = @object_id
                AND i.is_primary_key = 0
                AND i.[type] = 2
            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
        ), '') + CHAR(13) + 'GO'

    PRINT @SQL
    FETCH NEXT FROM cur INTO @object_id, @object_name
END

CLOSE cur
DEALLOCATE cur