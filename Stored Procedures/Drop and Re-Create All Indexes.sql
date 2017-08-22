SELECT A.[object_id]
	,OBJECT_NAME(A.[object_id]) AS Table_Name
	,A.Index_ID
	,A.[Name] AS Index_Name
	,CAST(CASE 
			WHEN A.type = 1
				AND is_unique = 1
				THEN 'Create Unique Clustered Index '
			WHEN A.type = 1
				AND is_unique = 0
				THEN 'Create Clustered Index '
			WHEN A.type = 2
				AND is_unique = 1
				THEN 'Create Unique NonClustered Index '
			WHEN A.type = 2
				AND is_unique = 0
				THEN 'Create NonClustered Index '
			END + quotename(A.[Name]) + ' On ' + quotename(S.NAME) + '.' + quotename(OBJECT_NAME(A.[object_id])) + ' (' + Stuff((
				SELECT ',[' + COL_NAME(A.[object_id], C.column_id) + CASE 
						WHEN C.is_descending_key = 1
							THEN '] Desc'
						ELSE '] Asc'
						END
				FROM sys.index_columns C WITH (NOLOCK)
				WHERE A.[Object_ID] = C.object_id
					AND A.Index_ID = C.Index_ID
					AND C.is_included_column = 0
				ORDER BY C.key_Ordinal ASC
				FOR XML Path('')
				), 1, 1, '') + ') ' + CASE 
			WHEN A.type = 1
				THEN ''
			ELSE Coalesce('Include (' + Stuff((
							SELECT ',' + QuoteName(COL_NAME(A.[object_id], C.column_id))
							FROM sys.index_columns C WITH (NOLOCK)
							WHERE A.[Object_ID] = C.object_id
								AND A.Index_ID = C.Index_ID
								AND C.is_included_column = 1
							ORDER BY C.index_column_id ASC
							FOR XML Path('')
							), 1, 1, '') + ') ', '')
			END + CASE 
			WHEN A.has_filter = 1
				THEN 'Where ' + A.filter_definition
			ELSE ''
			END + ' With (Drop_Existing = ON, SORT_IN_TEMPDB = ON'
		--when the same index exists you'd better to set the Drop_Existing = ON
		--SORT_IN_TEMPDB = ON is recommended but based on your own environment.
		+ ', Fillfactor = ' + Cast(CASE 
				WHEN fill_factor = 0
					THEN 100
				ELSE fill_factor
				END AS VARCHAR(3)) + CASE 
			WHEN A.[is_padded] = 1
				THEN ', PAD_INDEX = ON'
			ELSE ', PAD_INDEX = OFF'
			END + CASE 
			WHEN D.[no_recompute] = 1
				THEN ', STATISTICS_NORECOMPUTE = ON'
			ELSE ', STATISTICS_NORECOMPUTE = OFF'
			END + CASE 
			WHEN A.[ignore_dup_key] = 1
				THEN ', IGNORE_DUP_KEY = ON'
			ELSE ', IGNORE_DUP_KEY = OFF'
			END + CASE 
			WHEN A.[ALLOW_ROW_LOCKS] = 1
				THEN ', ALLOW_ROW_LOCKS = ON'
			ELSE ', ALLOW_ROW_LOCKS = OFF'
			END + CASE 
			WHEN A.[ALLOW_PAGE_LOCKS] = 1
				THEN ', ALLOW_PAGE_LOCKS = ON'
			ELSE ', ALLOW_PAGE_LOCKS = OFF'
			END + CASE 
			WHEN P.[data_compression] = 0
				THEN ', DATA_COMPRESSION = NONE'
			WHEN P.[data_compression] = 1
				THEN ', DATA_COMPRESSION = ROW'
			ELSE ', DATA_COMPRESSION = PAGE'
			END + ') On ' + CASE 
			WHEN C.type = 'FG'
				THEN quotename(C.NAME)
			ELSE quotename(C.NAME) + '(' + F.Partition_Column + ')'
			END + ';' --if it uses partition scheme then need partition column
		AS NVARCHAR(Max)) AS Index_Create_Statement
	,C.NAME AS FileGroupName
	,'DROP INDEX ' + quotename(A.[Name]) + ' On ' + quotename(S.NAME) + '.' + quotename(OBJECT_NAME(A.[object_id])) + ';' AS Index_Drop_Statement
FROM SYS.Indexes A WITH (NOLOCK)
INNER JOIN sys.objects B WITH (NOLOCK)
	ON A.object_id = B.object_id
INNER JOIN SYS.schemas S
	ON B.schema_id = S.schema_id
INNER JOIN SYS.data_spaces C WITH (NOLOCK)
	ON A.data_space_id = C.data_space_id
INNER JOIN SYS.stats D WITH (NOLOCK)
	ON A.object_id = D.object_id
		AND A.index_id = D.stats_id
INNER JOIN
	--The below code is to find out what data compression type was used by the index. If an index is not partitioned, it is easy as only one data compression
	--type can be used. If the index is partitioned, then each partition can be configued to use the different data compression. This is hard to generalize,
	--for simplicity, I just use the data compression type used most for the index partitions for all partitions. You can later rebuild the index partition to
	--the appropriate data compression type you want to use
	(
	SELECT object_id
		,index_id
		,Data_Compression
		,ROW_NUMBER() OVER (
			PARTITION BY object_id
			,index_id ORDER BY COUNT(*) DESC
			) AS Main_Compression
	FROM sys.partitions WITH (NOLOCK)
	GROUP BY object_id
		,index_id
		,Data_Compression
	) P
	ON A.object_id = P.object_id
		AND A.index_id = P.index_id
		AND P.Main_Compression = 1
OUTER APPLY (
	SELECT COL_NAME(A.object_id, E.column_id) AS Partition_Column
	FROM sys.index_columns E WITH (NOLOCK)
	WHERE E.object_id = A.object_id
		AND E.index_id = A.index_id
		AND E.partition_ordinal = 1
	) F
WHERE A.type IN (
		1
		,2
		) --clustered and nonclustered
	AND B.Type != 'S'
	AND OBJECT_NAME(A.[object_id]) NOT LIKE 'queue_messages_%'
	AND OBJECT_NAME(A.[object_id]) NOT LIKE 'filestream_tombstone_%'
	AND OBJECT_NAME(A.[object_id]) NOT LIKE 'sys%' --if you have index start with sys then remove it
