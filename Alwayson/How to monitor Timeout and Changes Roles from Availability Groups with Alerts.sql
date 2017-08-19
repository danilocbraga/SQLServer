EXEC msdb .dbo. sp_add_operator @name =N'AlertTeam',
               @enabled=1 ,
               @weekday_pager_start_time=90000 ,
               @weekday_pager_end_time=180000 ,
               @saturday_pager_start_time=90000 ,
               @saturday_pager_end_time=180000 ,
               @sunday_pager_start_time=90000 ,
               @sunday_pager_end_time=180000 ,
               @pager_days=0 ,
               @email_address=N'email@email.com.br' ,
               @category_name=N'[Uncategorized]'
GO
 
-- 1480 - AG Role Change (failover)
EXEC msdb .dbo. sp_add_alert
        @name = N'AG Role Change',
        @message_id = 1480,
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 0,
    @include_event_description_in = 1;
GO
EXEC msdb .dbo. sp_add_notification
        @alert_name = N'AG Role Change',
        @operator_name = N'AlertTeam',
        @notification_method = 1;
GO
 
-- 35264 - AG Data Movement - Resumed
EXEC msdb .dbo. sp_add_alert
        @name = N'AG Data Movement - Suspended',
        @message_id = 35264,
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 0,
    @include_event_description_in = 1;
GO
EXEC msdb .dbo. sp_add_notification
        @alert_name = N'AG Data Movement - Suspended',
        @operator_name = N'AlertTeam',
        @notification_method = 1;
GO
 
-- 35265 - AG Data Movement - Resumed
EXEC msdb .dbo. sp_add_alert
        @name = N'AG Data Movement - Resumed',
        @message_id = 35265,
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 0,
    @include_event_description_in = 1;
GO
EXEC msdb .dbo. sp_add_notification
        @alert_name = N'AG Data Movement - Resumed',
        @operator_name = N'AlertTeam',
        @notification_method = 1;
GO
 
-- 35206 - AG Timeout to Secondary Replica
EXEC msdb .dbo . sp_add_alert
        @name = N'AG Timeout to Secondary Replica',
        @message_id = 35206,
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 0,
    @include_event_description_in = 1;
GO
EXEC msdb .dbo . sp_add_notification
        @alert_name = N'AG Timeout to Secondary Replica',
        @operator_name = N'AlertTeam',
        @notification_method = 1;
GO
-- 35202 - AG Timeout to Secondary Replica
EXEC msdb .dbo . sp_add_alert
        @name = N'AG Connection has been successfully established',
        @message_id = 35202,
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 0,
    @include_event_description_in = 1;
GO
EXEC msdb .dbo . sp_add_notification
        @alert_name = N'AG Connection has been successfully established',
        @operator_name = N'AlertTeam',
        @notification_method = 1;