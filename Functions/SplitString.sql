CREATE FUNCTION dbo.SplitString (  
      @Input NVARCHAR(MAX),  
      @Character CHAR(1)  
)  
RETURNS @Output TABLE (  
      Value NVARCHAR(1000)  
)  
AS  
BEGIN  
      DECLARE @StartIndex INT, @EndIndex INT  
   
      SET @StartIndex = 1  
      IF SUBSTRING(@Input, LEN(@Input) - 1, LEN(@Input)) <> @Character  
      BEGIN  
            SET @Input = @Input + @Character  
      END  
   
      WHILE CHARINDEX(@Character, @Input) > 0  
      BEGIN  
            SET @EndIndex = CHARINDEX(@Character, @Input)  
             
            INSERT INTO @Output(Value)  
            SELECT SUBSTRING(@Input, @StartIndex, @EndIndex - 1)  
             
            SET @Input = SUBSTRING(@Input, @EndIndex + 1, LEN(@Input))  
      END  
   
      RETURN  
END  

/*
DECLARE @SQLString AS NVARCHAR(MAX) = 'a,b,c'              
SELECT Value
FROM dbo.SplitString(@SQLString, ',')  
*/