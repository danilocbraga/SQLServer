CREATE PROCEDURE sp_job_list @jobname VARCHAR(100)=NULL  
as  
  
DECLARE @sql VARCHAR(8000)  
DECLARE @is_sysadmin INT  
DECLARE @job_owner   sysname  
  
IF OBJECT_ID('tempdb..#xp_results') IS NOT NULL  
BEGIN  
    DROP TABLE #xp_results  
END  
  
  
CREATE TABLE #xp_results (  
     job_id                UNIQUEIDENTIFIER NOT NULL,  
     last_run_date         INT              NOT NULL,  
     last_run_time         INT              NOT NULL,  
     next_run_date         INT              NOT NULL,  
     next_run_time         INT              NOT NULL,  
     next_run_schedule_id  INT              NOT NULL,  
     requested_to_run      INT              NOT NULL,   
     request_source        INT              NOT NULL,  
     request_source_id     sysname          COLLATE database_default NULL,  
     running               INT              NOT NULL,   
     current_step          INT              NOT NULL,  
     current_retry_attempt INT              NOT NULL,  
     job_state             INT              NOT NULL)  
  
  
  
SELECT @is_sysadmin = ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0)  
SELECT @job_owner = SUSER_SNAME()  
  
INSERT INTO #xp_results  
    EXECUTE master.dbo.xp_sqlagent_enum_jobs @is_sysadmin, @job_owner  
  
SELECT   
  j.Name AS JobName  
, c.Name AS Category  
, CASE j.enabled WHEN 1 THEN 'Yes' else 'No' END as Enabled  
, CASE s.enabled WHEN 1 THEN 'Yes' else 'No' END as Scheduled  
, j.Description   
, CASE s.freq_type   
     WHEN  1 THEN 'Once'  
     WHEN  4 THEN 'Daily'  
     WHEN  8 THEN 'Weekly'  
     WHEN 16 THEN 'Monthly'  
     WHEN 32 THEN 'Monthly relative'  
     WHEN 64 THEN 'When SQL Server Agent starts'   
     WHEN 128 THEN 'Start whenever the CPU(s) become idle' END as Occurs    
, CASE s.freq_type   
     WHEN  1 THEN 'O'  
     WHEN  4 THEN 'Every '   
        + convert(varchar,s.freq_interval)   
        + ' day(s)'  
     WHEN  8 THEN 'Every '   
        + convert(varchar,s.freq_recurrence_factor)   
        + ' weeks(s) on '   
        + master.dbo.fn_freq_interval_desc(s.freq_interval)         
     WHEN 16 THEN 'Day ' + convert(varchar,s.freq_interval)   
        + ' of every '   
        + convert(varchar,s.freq_recurrence_factor)   
        + ' month(s)'   
     WHEN 32 THEN 'The '   
        + CASE s.freq_relative_interval   
            WHEN  1 THEN 'First'  
            WHEN  2 THEN 'Second'  
            WHEN  4 THEN 'Third'   
            WHEN  8 THEN 'Fourth'  
            WHEN 16 THEN 'Last' END   
        + CASE s.freq_interval   
            WHEN  1 THEN ' Sunday'  
            WHEN  2 THEN ' Monday'  
            WHEN  3 THEN ' Tuesday'  
            WHEN  4 THEN ' Wednesday'  
            WHEN  5 THEN ' Thursday'  
            WHEN  6 THEN ' Friday'  
            WHEN  7 THEN ' Saturday'  
            WHEN  8 THEN ' Day'  
            WHEN  9 THEN ' Weekday'  
            WHEN 10 THEN ' Weekend Day' END   
        + ' of every '   
        + convert(varchar,s.freq_recurrence_factor)   
        + ' month(s)' END AS Occurs_detail   
, CASE s.freq_subday_type   
     WHEN 1 THEN 'Occurs once at '   
        + master.dbo.fn_Time2Str(s.active_start_time)   
     WHEN 2 THEN 'Occurs every '   
        + convert(varchar,s.freq_subday_interval)   
        + ' Seconds(s) Starting at '   
        + master.dbo.fn_Time2Str(s.active_start_time)   
        + ' ending at '   
        + master.dbo.fn_Time2Str(s.active_end_time)   
     WHEN 4 THEN 'Occurs every '   
        + convert(varchar,s.freq_subday_interval)   
        + ' Minute(s) Starting at '   
        + master.dbo.fn_Time2Str(s.active_start_time)   
        + ' ending at '   
        + master.dbo.fn_Time2Str(s.active_end_time)   
     WHEN 8 THEN 'Occurs every '   
        + convert(varchar,s.freq_subday_interval)   
        + ' Hour(s) Starting at '   
        + master.dbo.fn_Time2Str(s.active_start_time)   
        + ' ending at '   
        + master.dbo.fn_Time2Str(s.active_end_time) END AS Frequency  
, CASE WHEN s.freq_type =  1 THEN 'On date: '   
          + master.dbo.fn_Date2Str(s.active_start_date)   
+ ' At time: '   
          + master.dbo.fn_Time2Str(s.active_start_time)  
       WHEN s.freq_type < 64 THEN 'Start date: '   
          + master.dbo.fn_Date2Str(s.active_start_date)   
          + ' end date: '   
          + master.dbo.fn_Date2Str(s.active_end_date) END as Duration  
, master.dbo.fn_Date2Str(xp.next_run_date) + ' '   
    + master.dbo.fn_Time2Str(xp.next_run_time) AS Next_Run_Date  
FROM  msdb.dbo.sysjobs j (NOLOCK)  
INNER JOIN msdb.dbo.sysjobschedules js (NOLOCK) ON j.job_id = js.job_id  
INNER JOIN msdb.dbo.sysschedules s (NOLOCK) ON js.schedule_id = s.schedule_id  
INNER JOIN msdb.dbo.syscategories c (NOLOCK) ON j.category_id = c.category_id  
INNER JOIN #xp_results xp (NOLOCK) ON j.job_id = xp.job_id  
WHERE ( j.Name LIKE +@jobname +'%' OR @jobname IS NULL)  
ORDER BY j.name