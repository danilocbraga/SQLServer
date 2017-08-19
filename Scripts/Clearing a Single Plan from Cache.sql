SELECT st. text, qs.query_hash,'DBCC FREEPROCCACHE(' ,plan_handle ,')'
FROM sys .dm_exec_query_stats qs
CROSS APPLY sys .dm_exec_sql_text( qs. sql_handle) st
WHERE st. text LIKE 'SELECT * FROM Person.Address%' -- your query

--Clear all the plans for one particular database from cache
DBCC FLUSHPROCINDB(<db_id>);