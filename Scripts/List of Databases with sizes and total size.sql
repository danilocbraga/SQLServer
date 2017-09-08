--Script to list of Databases with sizes and total size of databases

SELECT ISNULL(D.NAME, 'Total') AS DBNAME
	,CAST((SUM(M.SIZE) * 8 / 1024.00 / 1024.00) AS NUMERIC(18, 2)) AS [DB Size(In GB)]
FROM SYS.MASTER_FILES M
INNER JOIN SYSDATABASES D
	ON D.DBID = M.DATABASE_ID
GROUP BY D.NAME
WITH ROLLUP


-- Only the total size
SELECT *
FROM (
	SELECT ISNULL(D.NAME, 'Total') AS DBNAME
		,CAST((SUM(M.SIZE) * 8 / 1024.00 / 1024.00) AS NUMERIC(18, 2)) AS [DB Size(In GB)]
	FROM SYS.MASTER_FILES M
	INNER JOIN SYSDATABASES D
		ON D.DBID = M.DATABASE_ID
	WHERE [database_id] > 4
		AND [database_id] <> 32767
	--and DB_NAME ([database_id] ) like 'D%'
	--AND type_desc = 'ROWS'
	--AND physical_name LIKE 'D:%'
	GROUP BY D.NAME
	WITH ROLLUP
	) T
WHERE T.DBNAME = 'Total'

