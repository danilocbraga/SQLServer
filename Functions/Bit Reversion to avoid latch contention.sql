CREATE SEQUENCE <SomeSequenceName> START WITH 1 INCREMENT BY 1
--Now you get the next value calling:
SET @Variable= NEXT VALUE FOR <SomeSequenceName>

--Now all you need to do is the inversion… And here is how that is done: (The code works for Bigint…)
CREATE FUNCTION BitReverse
(
    @Input bigint
)
RETURNS bigint
AS
BEGIN
    DECLARE @WorkValue bigint=@Input
    DECLARE @Result bigint=0;
    DECLARE @Counter int=0;
    WHILE @Counter<63
    BEGIN
        SET @Result=@Result*2
        IF (@WorkValue&1)=1
        BEGIN
            SET @Result=@Result+1
            SET @WorkValue=@WorkValue-1
        END
        SET @WorkValue=@WorkValue/2
        SET @Counter=@Counter+1
    END
    
    RETURN @Result
    
END
--http://dangerousdba.blogspot.ca/2011/10/bit-reversion.html