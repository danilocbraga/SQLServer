SET NOCOUNT ON;
DECLARE @name VARCHAR(150);
DECLARE @temptable TABLE([Name] VARCHAR(150));
INSERT INTO @temptable
       SELECT name
       FROM sys.databases
       WHERE page_verify_option < 2
             AND database_id > 4
             AND is_read_only = 0
             AND state <> 6;
SELECT TOP 1 @name = [Name]
FROM @temptable;
WHILE(@name <> '##')
    BEGIN
        DECLARE @command VARCHAR(1000);
        SET @command = 'ALTER DATABASE '+@name+' set page_verify CHECKSUM WITH NO_WAIT';
        PRINT @command;
        EXEC (@command);
        DELETE FROM @temptable
        WHERE [Name] = @name;
        SET @name = '##';
        SELECT TOP 1 @name = [Name]
        FROM @temptable;
    END;
