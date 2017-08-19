CREATE PROCEDURE [dbo].[pr_monitor_alwayson]
@server varchar( 50) = 'PRIMARY' ,--'SECONDARY' or 'PRIMARY'
@email varchar( 100) = 'youremail@mail.com.br'
AS
if exists (
SELECT rtrim (ltrim ( ar .replica_server_name )) as replica_server_name ,            
rtrim ( ltrim ( db_name( dr_state.database_id ) )) as database_id ,        
CASE WHEN ar_state.is_local = 1 THEN N'LOCAL' ELSE 'REMOTE' END ,   
CASE WHEN ar_state.role_desc IS NULL THEN N'DISCONNECTED' ELSE ar_state.role_desc END as role_desc,     
rtrim ( ltrim ( ar_state.connected_state_desc )) as connected_state_desc,   
rtrim ( ltrim ( ar.availability_mode_desc )) as availability_mode_desc,    
rtrim ( ltrim ( dr_state.synchronization_state_desc )) as synchronization_state_desc,      
rtrim ( ltrim ( ar_state.synchronization_health_desc )) as synchronization_health_desc,      
rtrim ( ltrim ( last_commit_time)) as last_commit_time
FROM (( sys.availability_groups AS ag JOIN sys. availability_replicas AS ar  ON ag.group_id = ar.group_id )
JOIN sys .dm_hadr_availability_replica_states AS ar_state ON ar .replica_id = ar_state.replica_id)
JOIN sys .dm_hadr_database_replica_states dr_state on
ag.group_id = dr_state. group_id and dr_state .replica_id = ar_state.replica_id
WHERE ar_state. is_local = 1
        AND ( ar_state.role_desc <> @server
        OR connected_state_desc <> 'CONNECTED'
        OR ar. availability_mode_desc not in ( 'SYNCHRONOUS_COMMIT','ASYNCHRONOUS_COMMIT' )
        OR dr_state. synchronization_state_desc NOT IN('SYNCHRONIZED', 'SYNCHRONIZING')
        OR ar_state. synchronization_health_desc<> 'HEALTHY')
UNION ALL
SELECT rtrim (ltrim ( ar .replica_server_name )) as replica_server_name ,            
rtrim ( ltrim ( db_name( dr_state.database_id ) )) as database_id ,        
CASE WHEN ar_state.is_local = 1 THEN N'LOCAL' ELSE 'REMOTE' END ,   
CASE WHEN ar_state.role_desc IS NULL THEN N'DISCONNECTED' ELSE ar_state.role_desc END as role_desc,     
rtrim ( ltrim ( ar_state.connected_state_desc )) as connected_state_desc,   
rtrim ( ltrim ( ar.availability_mode_desc )) as availability_mode_desc,    
rtrim ( ltrim ( dr_state.synchronization_state_desc )) as synchronization_state_desc,      
rtrim ( ltrim ( ar_state.synchronization_health_desc )) as synchronization_health_desc,      
rtrim ( ltrim ( last_commit_time)) as last_commit_time
FROM (( sys.availability_groups AS ag JOIN sys. availability_replicas AS ar  ON ag.group_id = ar.group_id )
JOIN sys .dm_hadr_availability_replica_states AS ar_state ON ar .replica_id = ar_state.replica_id)
JOIN sys .dm_hadr_database_replica_states dr_state on
ag.group_id = dr_state. group_id and dr_state .replica_id = ar_state.replica_id
WHERE (connected_state_desc <> 'CONNECTED'
        OR ar. availability_mode_desc not in ( 'SYNCHRONOUS_COMMIT','ASYNCHRONOUS_COMMIT' )
        OR dr_state. synchronization_state_desc NOT IN('SYNCHRONIZED', 'SYNCHRONIZING')
        OR ar_state. synchronization_health_desc<> 'HEALTHY')
 
)
 
BEGIN
DECLARE @profiler VARCHAR (100)
DECLARE @ServerT VARCHAR (100)
SELECT top 1 @profiler = name  FROM msdb ..sysmail_profile
SELECT @ServerT = '[ALERT] AlwaysOn Status (' +@@SERVERNAME+ ')'
 
DECLARE @tableHTML  NVARCHAR (MAX) ;
 
SET @tableHTML =
    N'<H1>AlwaysOn Status - '+ @@SERVERNAME+'</H1>' +
    N'<table cellpadding=0 cellspacing=0 border=1 style="border: solid black 1px;padding-left:5px;padding-right:5px;padding-top:1px;padding-bottom:1px;font-size:11pt;">' +
    N'<tr bgcolor=#BEBEBE>' +
        N'<th>replica_server</th><th>database</th><th>is_replica_local</th><th>replica_role</th><th>state_desc</th>
<th>mode_desc</th><th>sync_state_desc</th><th>sync_health_desc</th>
<th>last_commit</th>
' +
  
  
   CAST ( ( SELECT td = rtrim (ltrim ( ar .replica_server_name )),        '',
td = rtrim ( ltrim ( db_name( dr_state.database_id ) )),        '',
td = CASE WHEN ar_state.is_local = 1 THEN N'LOCAL' ELSE 'REMOTE' END ,       '' ,
td = CASE WHEN ar_state.role_desc IS NULL THEN N'DISCONNECTED' ELSE ar_state.role_desc END ,       '',
td = rtrim ( ltrim ( ar_state.connected_state_desc )),       '' ,
td = rtrim ( ltrim ( ar.availability_mode_desc )),       '' ,
td = rtrim ( ltrim ( dr_state.synchronization_state_desc )),       '' ,
td = rtrim ( ltrim ( ar_state.synchronization_health_desc )),       '' ,
td = rtrim ( ltrim ( last_commit_time)),       ''
FROM (( sys.availability_groups AS ag JOIN sys. availability_replicas AS ar  ON ag.group_id = ar.group_id )
JOIN sys .dm_hadr_availability_replica_states AS ar_state ON ar .replica_id = ar_state.replica_id)
JOIN sys .dm_hadr_database_replica_states dr_state on
ag.group_id = dr_state. group_id and dr_state .replica_id = ar_state.replica_id
order by 3 desc, 5, 1
 
               FOR XML PATH( 'tr'), TYPE
    ) AS NVARCHAR ( MAX ) ) +
    N'</table>'
 
    ;
IF @tableHTML IS NOT NULL
BEGIN
       EXEC msdb. dbo.sp_send_dbmail
      @recipients=@email ,
      @body =@tableHTML ,
      @subject = @ServerT,
      @profile_name =@profiler,
      @body_format = 'HTML'
END
 
END