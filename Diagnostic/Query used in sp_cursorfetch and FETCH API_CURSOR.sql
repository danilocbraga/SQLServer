SELECT creation_time,
cursor_id,
c.session_id,
c.properties,
c.creation_time,
c.is_open,
SUBSTRING(st.TEXT, ( c.statement_start_offset / 2) + 1, (
( CASE c.statement_end_offset
WHEN -1 THEN DATALENGTH(st.TEXT)
ELSE c.statement_end_offset
END - c.statement_start_offset) / 2) + 1) AS statement_text
FROM   sys.Dm_exec_cursors(0) AS c
JOIN sys.dm_exec_sessions AS s
ON c.session_id = s.session_id
CROSS apply sys.Dm_exec_sql_text(c.sql_handle) AS st