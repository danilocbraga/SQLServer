/*************************************************************************
Author          :   Kin Shah
Purpose         :   Recommend MaxDop settings for the server instance
Tested RDBMS    :   SQL Server 2008R2

**************************************************************************/
declare @hyperthreadingRatio bit
declare @logicalCPUs int
declare @HTEnabled int
declare @physicalCPU int
declare @SOCKET int
declare @logicalCPUPerNuma int
declare @NoOfNUMA int

select @logicalCPUs = cpu_count -- [Logical CPU Count]
    ,@hyperthreadingRatio = hyperthread_ratio --  [Hyperthread Ratio]
    ,@physicalCPU = cpu_count / hyperthread_ratio -- [Physical CPU Count]
    ,@HTEnabled = case 
        when cpu_count > hyperthread_ratio
            then 1
        else 0
        end -- HTEnabledfrom sys.dm_os_sys_info
option (recompile);

select @logicalCPUPerNuma = COUNT(parent_node_id) -- [NumberOfLogicalProcessorsPerNuma]from sys.dm_os_schedulers
where [status] = 'VISIBLE ONLINE'
    and parent_node_id < 64group by parent_node_id
option (recompile);

select @NoOfNUMA = count(distinct parent_node_id)from sys.dm_os_schedulers -- find NO OF NUMA Nodes where [status] = 'VISIBLE ONLINE'
    and parent_node_id < 64

-- Report the recommendations ....select
    --- 8 or less processors and NO HT enabled
    case 
        when @logicalCPUs < 8
            and @HTEnabled = 0
            then 'MAXDOP setting should be : ' + CAST(@logicalCPUs as varchar(3))
                --- 8 or more processors and NO HT enabled
        when @logicalCPUs >= 8
            and @HTEnabled = 0
            then 'MAXDOP setting should be : 8'
                --- 8 or more processors and HT enabled and NO NUMA
        when @logicalCPUs >= 8
            and @HTEnabled = 1
            and @NoofNUMA = 1
            then 'MaxDop setting should be : ' + CAST(@logicalCPUPerNuma / @physicalCPU as varchar(3))
                --- 8 or more processors and HT enabled and NUMA
        when @logicalCPUs >= 8
            and @HTEnabled = 1
            and @NoofNUMA > 1
            then 'MaxDop setting should be : ' + CAST(@logicalCPUPerNuma / @physicalCPU as varchar(3))
        else ''
        end as Recommendations