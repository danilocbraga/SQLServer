DECLARE @database NVARCHAR(100);
DECLARE @command NVARCHAR(1000);
CREATE TABLE #hist
  (
    [database] NVARCHAR(500) ,
    date DATETIME
  );
SELECT  name
INTO    #database
FROM    master..sysdatabases
WHERE   dbid > 4;
SELECT TOP 1
        @database = name
FROM    #database;
WHILE @database <> ''
  BEGIN

--print 'Last Update Statistics no ' + @database

    SELECT  @command = 'use [' + @database + ']
INSERT INTO #hist (date,[database])
SELECT top 1 STATS_DATE(i.object_id,i.index_id) AS [ ]
, db_name()
FROM
sys.indexes i JOIN
sys.tables t ON t.object_id = i.object_id JOIN
sys.partitions sp ON i.object_id = sp.object_id
WHERE
i.type > 0 and sp.rows > 0
ORDER BY
t.name ASC
,i.type_desc ASC
,i.name ASC

';
    DELETE  FROM #database
    WHERE   name = @database;
    EXEC sp_executesql @command;
    SET @database = '';
    SET @command = '';
    SELECT TOP 1
            @database = name
    FROM    #database;
  END;
SELECT  [database] ,
        ISNULL(date, 00.0) AS LastUpdateStatistics
FROM    #hist
ORDER BY date DESC;
DROP TABLE #database;
DROP TABLE #hist;