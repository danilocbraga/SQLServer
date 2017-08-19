--This should always happen on the client side, but in case you ever need it, here is the SQL code.
Declare @d datetime
    select @d = getdate()
    select @d as OriginalDate,
    convert(varchar,@d,100) as ConvertedDate,
    100 as FormatValue,
    'mon dd yyyy hh:miAM (or PM)' as OutputFormat
    union all
    select @d,convert(varchar,@d,101),101,'mm/dd/yyyy'
    union all
    select @d,convert(varchar,@d,102),102,'yyyy.mm.dd'
    union all
    select @d,convert(varchar,@d,103),103,'dd/mm/yyyy'
    union all
    select @d,convert(varchar,@d,104),104,'dd.mm.yyyy'
    union all
    select @d,convert(varchar,@d,105),105,'dd-mm-yyyy'
    union all
    select @d,convert(varchar,@d,106),106,'dd mon yyyy'
    union all
    select @d,convert(varchar,@d,107),107,'Mon dd, yyyy'
    union all
    select @d,convert(varchar,@d,108),108,'hh:mm:ss'
    union all
    select @d,convert(varchar,@d,109),109,'mon dd yyyy hh:mi:ss:mmmAM (or PM)'
    union all
    select @d,convert(varchar,@d,110),110,'mm-dd-yyyy'
    union all
    select @d,convert(varchar,@d,111),111,'yyyy/mm/dd'
    union all
    select @d,convert(varchar,@d,112),112,'yyyymmdd'
    union all
    select @d,convert(varchar,@d,113),113,'dd mon yyyy hh:mm:ss:mmm(24h)'
    union all
    select @d,convert(varchar,@d,114),114,'hh:mi:ss:mmm(24h)'
    union all
    select @d,convert(varchar,@d,120),120,'yyyy-mm-dd hh:mi:ss(24h)'
    union all
    select @d,convert(varchar,@d,121),121,'yyyy-mm-dd hh:mi:ss.mmm(24h)'
    union all
    select @d,convert(varchar,@d,126),126,'yyyy-mm-dd Thh:mm:ss:mmm(no spaces)'