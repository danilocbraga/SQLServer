WITH duplicated_plans AS (
    SELECT TOP 20 
        query_hash,
        (SELECT TOP 1 [sql_handle] FROM sys.dm_exec_query_stats AS s2 WHERE s2.query_hash = s1.query_hash ORDER BY [sql_handle]) AS sample_sql_handle,
        (SELECT TOP 1 statement_start_offset FROM sys.dm_exec_query_stats AS s2 WHERE s2.query_hash = s1.query_hash ORDER BY [sql_handle]) AS sample_statement_start_offset,
        (SELECT TOP 1 statement_end_offset FROM sys.dm_exec_query_stats AS s2 WHERE s2.query_hash = s1.query_hash ORDER BY [sql_handle]) AS sample_statement_end_offset,
        CAST (pa.value AS INT) AS dbid,
        COUNT(*) AS plan_count 
    FROM sys.dm_exec_query_stats AS s1
    OUTER APPLY sys.dm_exec_plan_attributes (s1.plan_handle) AS pa 
    WHERE pa.attribute = 'dbid'
    GROUP BY query_hash, pa.value
    ORDER BY COUNT(*) DESC
)
SELECT
    query_hash,
    plan_count,
    CONVERT (NVARCHAR(80), REPLACE (REPLACE (
        LTRIM (
            SUBSTRING (
                sql.[text],
                (sample_statement_start_offset / 2) + 1,
                CASE
                    WHEN sample_statement_end_offset = -1 THEN DATALENGTH (sql.[text])
                    ELSE sample_statement_end_offset 
                END - (sample_statement_start_offset / 2)
            )
        ),
        CHAR(10), ''), CHAR(13), '')) AS qry,
    OBJECT_NAME (sql.objectid, sql.[dbid]) AS [object_name],
    DB_NAME (duplicated_plans.[dbid]) AS [database_name]
FROM duplicated_plans 
CROSS APPLY sys.dm_exec_sql_text (duplicated_plans.sample_sql_handle) AS sql
WHERE ISNULL (duplicated_plans.[dbid], 0) != 32767 -- ignore queries from Resource DB 
AND plan_count > 1;