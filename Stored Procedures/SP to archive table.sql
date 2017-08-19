CREATE PROCEDURE dbo.AudLog_Archive
(
  @BatchSize INT = 2000, -- don't go above 3000 to avoid lock escalation
  @SecondsToRun INT = 180, -- run for 3 minutes
  @DaysToKeep INT = 185 -- archive rows older than 6 months
)
AS
SET NOCOUNT ON;

DECLARE @EndTime DATETIME = DATEADD(SECOND , @SecondsToRun, GETDATE()),
        @ArchiveDate DATETIME = DATEADD( DAY, @DaysToKeep * - 1, GETDATE()),
        @RowsArchived INT = @BatchSize; -- initialize to be able to enter the loop


WHILE (@EndTime > GETDATE () AND @RowsArchived = @BatchSize )
BEGIN

    IF (EXISTS(
                 SELECT 1
                 FROM   dbo. AudLog al
                 WHERE  al. [XDATE] < @ArchiveDate
              )
        )
    BEGIN
        ;WITH batch AS
        (
            -- Keep this as SELECT * as it will alert you, via job failure, if
            -- you add columns to AudLog but forget to add them to AudLog_Backup
            SELECT  TOP (@BatchSize) al.*
            FROM    dbo. AudLog al
            WHERE   al. [XDATE] < @ArchiveDate
            ORDER BY al.[XDATE] ASC
        )
        DELETE b
        OUTPUT DELETED.* -- keep as * for same reason as noted above
        INTO   dbo. AudLog_Backup ( [PVKEY], [DKEY] , ...) -- specify all columns
        FROM   batch b

        SET @RowsArchived = @@ROWCOUNT;

        WAITFOR DELAY '00:00:01.000'; -- one second delay for breathing room
    END;
    ELSE
    BEGIN
        BREAK;
    END;
END;
