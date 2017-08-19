
BEGIN
    SET ARITHABORT ON;
    SET QUOTED_IDENTIFIER ON;
    DECLARE @vDatabase NVARCHAR(128);
    DECLARE curDatabases CURSOR
    FOR
        SELECT name
        FROM master.dbo.sysdatabases
        WHERE name NOT IN('master', 'model', 'msdb', 'tempdb')
        AND DATABASEPROPERTYEX(name, 'STATUS') = 'ONLINE'
        AND DATABASEPROPERTYEX(name, 'Updateability') = 'READ_WRITE';
    OPEN curDatabases;
    FETCH NEXT FROM curDatabases INTO @vDatabase;
    WHILE(@@FETCH_STATUS <> -1)
        BEGIN
            IF(@@FETCH_STATUS <> -2)
                BEGIN
                    EXEC ('dbcc checkdb('''+@vDatabase+''')');
            END;
            FETCH NEXT FROM curDatabases INTO @vDatabase;
        END;
    CLOSE curDatabases;
    DEALLOCATE curDatabases;
END;
