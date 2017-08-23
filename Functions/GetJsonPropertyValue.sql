/*
--http://www.daves-blog.net/post/2014/07/04/Json-Data-Sql-Script.aspx
*/

CREATE FUNCTION dbo.GetJsonPropertyValue (@Content varchar(MAX),@PropertyName varchar(100), @IsPropertyValueString bit)  
RETURNS varchar(255)  
WITH EXECUTE AS CALLER  
AS  
BEGIN  
     DECLARE @JsonFormatLength VARCHAR(max);  
     DECLARE @PropertyNameLength VARCHAR(max);  
     SET @PropertyNameLength= len(@propertyName)  
     set @JsonFormatLength = case when @IsPropertyValueString = 1 then 2 else 1 end  
     set @PropertyName = '"'+@PropertyName+'"'  
     set @PropertyNameLength = LEN(@PropertyName)  
   
return SUBSTRING(@Content, charindex(@PropertyName,@Content) + @PropertyNameLength + @JsonFormatLength,  
case when charindex(',',@Content,charindex(@PropertyName,@Content) + @PropertyNameLength + @JsonFormatLength) > 0  
then charindex(',',@Content,charindex(@PropertyName,@Content) + @PropertyNameLength + @JsonFormatLength)-  
(charindex(@PropertyName,@Content) + @PropertyNameLength + @JsonFormatLength +1)  
else charindex('}',@Content,charindex(@PropertyName,@Content) + @PropertyNameLength)-  
(charindex(@PropertyName,@Content) + @PropertyNameLength + @JsonFormatLength + case when @IsPropertyValueString = 1 then 1 else 0 end)  
end)  
END;