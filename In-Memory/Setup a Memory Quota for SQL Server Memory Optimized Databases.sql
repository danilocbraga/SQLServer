/*
Author: Daniel Farina
https://www.mssqltips.com/sqlservertip/3368/setup-a-memory-quota-for-sql-server-memory-optimized-databases/
*/


-- Query to do the math
USE master 
GO
;WITH    cte
  AS ( SELECT   RP.pool_id ,
  RP.Name ,
  RP.min_memory_percent ,
  RP.max_memory_percent ,
  CAST (RP.max_memory_kb / 1024. / 1024. 
    AS NUMERIC(12, 2)) AS max_memory_gb ,
  CAST (RP.used_memory_kb / 1024. / 1024. 
    AS NUMERIC(12, 2)) AS used_memory_gb ,
  CAST (RP.target_memory_kb / 1024. / 1024. 
    AS NUMERIC(12,2)) AS target_memory_gb,
  CAST (SI.committed_target_kb / 1024. / 1024. 
    AS NUMERIC(12, 2)) AS committed_target_kb 
    FROM     sys.dm_resource_governor_resource_pools RP
    CROSS JOIN sys.dm_os_sys_info SI
  )
SELECT  c.pool_id ,
  c.Name ,
  c.min_memory_percent ,
  c.max_memory_percent ,
  c.max_memory_gb ,
  c.used_memory_gb ,
  c.target_memory_gb ,  
  CAST(c.committed_target_kb  *
  CASE WHEN c.committed_target_kb <= 8 THEN 0.7
    WHEN c.committed_target_kb < 16 THEN 0.75
    WHEN c.committed_target_kb < 32 THEN 0.8
    WHEN c.committed_target_kb <= 96 THEN 0.85
    WHEN c.committed_target_kb > 96 THEN 0.9
  END * c.max_memory_percent /100 AS NUMERIC(12,2))
   AS [Max_for_InMemory_Objects_gb]
FROM    cte c
 

 -- Create a SQL Server Database and Bind a Resource Pool
USE [master]
GO

CREATE DATABASE [SampleDB]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'SampleDB_file1', 
   FILENAME = N'E:\MSSQL\SampleDB_1.mdf',
   SIZE = 128MB , 
   MAXSIZE = UNLIMITED, 
   FILEGROWTH = 64MB), 
 FILEGROUP [SampleDB_MemoryOptimized_filegroup] 
   CONTAINS MEMORY_OPTIMIZED_DATA  DEFAULT
( NAME = N'SampleDB_MemoryOptimized',
    FILENAME = N'E:\MSSQL\SampleDB_MemoryOptimized',
    MAXSIZE = UNLIMITED)
 LOG ON 
( NAME = N'SampleDB_log_file1',
    FILENAME = N'E:\MSSQL\SampleDB_1.ldf',
    SIZE = 64MB,
    MAXSIZE = 2048GB,
    FILEGROWTH = 32MB)
GO


--Now we create a sample table
USE SampleDB
GO

IF OBJECT_ID('dbo.SampleTable','U') IS NOT NULL
    DROP TABLE dbo.SampleTable
GO

CREATE TABLE SampleTable
    (
      ID INT IDENTITY(1,1),
      TextCol CHAR(8000) ,


        CONSTRAINT PK_SampleTable
        PRIMARY KEY NONCLUSTERED HASH ( id ) 
   WITH ( BUCKET_COUNT = 262144 )
    ) WITH (MEMORY_OPTIMIZED =
   ON,
   DURABILITY = SCHEMA_AND_DATA)
GO


--Creating the Resource Pool for SQL Server In-Memory Objects
USE master
GO

CREATE RESOURCE POOL [InMemoryObjects] 
  WITH 
    ( MIN_MEMORY_PERCENT = 50, 
    MAX_MEMORY_PERCENT = 50 );
GO

ALTER RESOURCE GOVERNOR RECONFIGURE;
GO


--Binding the Database to the Resource Pool
USE master
GO

EXEC sp_xtp_bind_db_resource_pool 'SampleDB', 'InMemoryObjects'


--SET our database offline and then back online first.
USE master
GO
ALTER DATABASE SampleDB SET OFFLINE WITH ROLLBACK IMMEDIATE
GO
ALTER DATABASE SampleDB SET ONLINE
GO


--Insert data in our test table
USE SampleDB
GO
INSERT INTO dbo.SampleTable 
        ( TextCol )
SELECT REPLICATE('a', 8000)
GO 60000
GO


--Unbinding the SQL Server Database from the Resource Pool
USE master
GO
EXEC sp_xtp_unbind_db_resource_pool 'SampleDB'
GO
USE master
GO
ALTER DATABASE SampleDB SET OFFLINE WITH ROLLBACK IMMEDIATE
GO
ALTER DATABASE SampleDB SET ONLINE