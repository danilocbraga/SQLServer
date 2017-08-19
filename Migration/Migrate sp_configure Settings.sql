set nocount on ;
Select 
name , minimum , maximum , value_in_use ,
case is_dynamic
when 1 then 'reconfigure with override'
when 0 then 'restart' end as [APPLY]
into #configurations

from sys .configurations 

select 'sp_configure  ' + ''''+ rtrim( name)+ '''' + ' , ' + convert (Varchar, value_in_use) + '  ' + CHAR(13) +CHAR (10 )+'go' +CHAR (13 ) +CHAR( 10)+
case [APPLY] when 'restart' then '-- Please restart sql services' + CHAR(13) +CHAR( 10)+ 'go'
  Else  'reconfigure with override  '+ CHAR(13)  +CHAR (10 )+'go'  end as sql_text
  into #configurations_final from #configurations
  If exists  (Select 1  from sys.configurations where value_in_use <>0
   and  is_dynamic = 0 )
   Begin
   insert into #configurations_final values
   ('Select ''IMP NOTE : One of configuration option need sql server restart to get activated''')
   End

   SELECT
     RowNum = ROW_NUMBER() OVER (ORDER BY sql_text desc )
     ,*
INTO #Geo
FROM #configurations_final


DECLARE @MaxRownum INT
SET @MaxRownum = (SELECT MAX (RowNum ) FROM #Geo )

DECLARE @Iter INT
Set @Iter = 1
DECLARE @sql_text varchar (2000 )
Set @sql_text = ''
SET @Iter = (SELECT MIN (RowNum ) FROM #Geo )
Create table #final (sql_text varchar (2000))

WHILE @Iter <= @MaxRownum
BEGIN
     insert into #final 
     select sql_text
     FROM #Geo
     WHERE RowNum = @Iter

   SET @Iter = @Iter + 1
  END

   Select * from #final

Drop table #configurations
Drop table #configurations_final
Drop table #Geo
Drop table #final
/*********************************/
