CREATE TABLE #temp (
    DATE DATETIME
    ,category VARCHAR(3)
    ,amount MONEY
    )
INSERT INTO #temp VALUES ('1/1/2012'    ,'ABC'  ,1000.00)
INSERT INTO #temp VALUES ('2/1/2012'    ,'DEF'  ,500.00)
INSERT INTO #temp VALUES ('2/1/2012'    ,'GHI'  ,800.00)
INSERT INTO #temp VALUES ('2/10/2012','DEF' ,700.00)
INSERT INTO #temp VALUES ('3/1/2012'    ,'ABC'  ,1100.00)
DECLARE @cols AS NVARCHAR(MAX)
    ,@sql AS NVARCHAR(MAX);
SET @cols = STUFF((
            SELECT DISTINCT ',' + QUOTENAME(c.category)
            FROM #temp c
            FOR XML PATH('')
                ,TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 1, '')
SET @sql = 'SELECT date, ' + @cols + ' from
            (
                select date
                    , amount
                    , category
                from #temp
           ) x
            pivot
            (
                 max(amount)
                for category in (' + @cols + ')
            ) p '
 
EXEC sp_executesql @sql
DROP TABLE #temp