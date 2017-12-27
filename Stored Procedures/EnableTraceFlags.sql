CREATE PROC [dbo].[EnableTraceFlags]
--Enable Global trace flags upon SQL Server startup.
--Notes: Need to execute sp_procoption to enable this stored procedure to autoexecute
--           whenever SQL Server instance starts:
--           EXEC sp_procoption 'dbo.EnableTraceFlags', 'startup', 'true'

AS
DBCC TRACEON (4199, -1);
-- Enable Query Optimiser fixes (http://support.microsoft.com/kb/974006)
DBCC TRACEON (1222, -1);
-- Write deadlocks to errorlog (BOL)
DBCC TRACEON (3226, -1);
-- Supress successfull backup messages (BOL)
DBCC TRACEON (6498, -1);
--Large query compilation waits on RESOURCE_SEMAPHORE_QUERY_COMPILE in SQL Server 2014
DBCC TRACEON ( 7470 , -1);
--FIX: Sort operator spills to tempdb in SQL Server 2012 or SQL Server 2014 when estimated number of rows and row size are correct
DBCC TRACEON ( 8075 , -1);
-- FIX: Out of memory error when the virtual address space of the SQL Server process is very low on available memory
DBCC TRACEON(2371,-1)
-- Lowers the threshold for automatic statistics updates to occur based on table size. Good for VLDBs.
DBCC TRACEON(2340, -1)
-- Lowers large memory grant requests from optimized Nested Loops
GO
 
EXEC sp_procoption N'[dbo].[EnableTraceFlags]', 'startup', '1'
GO
