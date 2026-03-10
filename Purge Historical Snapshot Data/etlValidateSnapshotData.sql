USE [SAM]
GO
/****** Object:  StoredProcedure [ClientAdmin].[etlValidateSnapshotData]    Script Date: 3/9/2026 2:05:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   PROCEDURE [ClientAdmin].[etlValidateSnapshotData]
      @EntityID INT
    , @JobID    INT
AS
BEGIN

SET NOCOUNT ON;

--DECLARE @JobID as INT
--DECLARE @EntityID as INT

--SET @EntityID = 43066
--SET @JobID = 305046

------------------------------------------------------------
-- Variables
------------------------------------------------------------
DECLARE 
      @ID INT
    , @DataMartID INT
    , @DataMartNM NVARCHAR(255)
    , @TableID INT
    , @DatabaseNM SYSNAME
    , @SchemaNM SYSNAME
    , @TableNM SYSNAME
    , @ValidateSnapshotFLG BIT
    , @SnapshotPeriodCD
    , @TaskNM NVARCHAR(255)
    , @ProcedureNM NVARCHAR(255)
    , @EventTypeCD NVARCHAR(50)
    , @ExecStatement NVARCHAR(MAX)
    , @BatchDefinitionID INT
    , @EventDSC NVARCHAR(4000)
    , @SQL NVARCHAR(MAX)
    , @RowCount INT
    , @RC INT

PRINT 'Starting Snapshot Validation'

DECLARE validate_cursor CURSOR FAST_FORWARD FOR

SELECT sn.[ID]
      ,dm.DataMartID
      ,sn.[DataMartNM]
      ,sn.[TableID]
      ,tb.DatabaseNM
      ,tb.SchemaNM
      ,tb.TableNM
      ,sn.ValidateSnapshotFLG
      ,sn.SnapshotPeriodCD
      ,'ValidateSnapshotData'
      ,'SAM.ClientAdmin.etlValidateSnapshotData'
      ,'PreEntity'
      ,'EXEC ClientAdmin.etlValidateSnapshotData'
      ,bh.BatchDefinitionID
FROM [IDEA].[ClientAdmin].[SAMSnapshotTableManagementBASE] sn
JOIN EDWAdmin.CatalystAdmin.TableBASE tb 
    ON sn.TableID = tb.TableID
JOIN EDWAdmin.CatalystAdmin.EntityBASE eb 
    ON tb.ContentID = eb.ContentID
JOIN EDWAdmin.CatalystAdmin.DataMartBASE dm 
    ON tb.DataMartID = dm.DataMartID
JOIN EDWAdmin.CatalystAdmin.ETLTableHistoryBASE th 
    ON th.BatchID = @JobID 
   AND th.EntityID = eb.EntityID
JOIN EDWAdmin.CatalystAdmin.ETLBatchHistoryBASE bh 
    ON bh.BatchID = @JobID
WHERE eb.EntityID = @EntityID;

OPEN validate_cursor

FETCH NEXT FROM validate_cursor INTO
      @ID
    , @DataMartID
    , @DataMartNM
    , @TableID
    , @DatabaseNM
    , @SchemaNM
    , @TableNM
    , @ValidateSnapshotFLG
    , @SnapshotPeriodCD
    , @TaskNM
    , @ProcedureNM
    , @EventTypeCD
    , @ExecStatement
    , @BatchDefinitionID

WHILE @@FETCH_STATUS = 0
BEGIN

    PRINT '-----------------------------------------'
    PRINT 'Current Entity: ' + @DatabaseNM + '.' + @SchemaNM + '.' + @TableNM

    SET @EventDSC = CONCAT('Current Entity: ', @DatabaseNM,'.',@SchemaNM,'.',@TableNM)

    EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
            @BatchID           = @JobID
           ,@TableID           = @TableID
           ,@PackageNM         = @TaskNM
           ,@EventTypeCD       = @EventTypeCD
           ,@TaskNM            = 'Table Processing Start'
           ,@EventDSC          = @EventDSC
           ,@BatchDefinitionID = @BatchDefinitionID
           ,@ProcedureNM       = @ProcedureNM
           ,@ExecStatment      = NULL
           ,@DataMartID        = @DataMartID;

    IF @ValidateSnapshotFLG = 1
    BEGIN

        PRINT 'Validation Enabled - Checking LastLoadDTS'

		SET @EventDSC = CONCAT('Starting snapshot validation for ',
                           @DatabaseNM,'.',@SchemaNM,'.',@TableNM)

		EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
				@BatchID           = @JobID
			   ,@TableID           = @TableID
			   ,@PackageNM         = @TaskNM
			   ,@EventTypeCD       = @EventTypeCD
			   ,@TaskNM            = 'Table Processing Start'
			   ,@EventDSC          = @EventDSC
			   ,@BatchDefinitionID = @BatchDefinitionID
			   ,@ProcedureNM       = @ProcedureNM
			   ,@ExecStatment      = NULL
			   ,@DataMartID        = @DataMartID;

        /* Daily Check/Validation - Checks which query to check for row counts */
        IF @SnapshotPeriodCD = 'Daily'
        BEGIN
            SET @SQL = '
            SELECT @RowCountOUT = COUNT(*)
            FROM ' + QUOTENAME(@DatabaseNM) + '.' + QUOTENAME(@SchemaNM) + '.' + QUOTENAME(@TableNM) + '
            WHERE CAST(LastLoadDTS AS DATE) = CAST(GETDATE() AS DATE)'
        END

        /* Monthly Check/Validation - Checks which query to check for row counts */
        IF @SnapshotPeriodCD = 'Monthly'
        BEGIN
            SET @SQL = '
            SELECT @RowCountOUT = COUNT(*)
            FROM ' + QUOTENAME(@DatabaseNM) + '.' + QUOTENAME(@SchemaNM) + '.' + QUOTENAME(@TableNM) + '
            WHERE LastLoadDTS >= DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)
            AND LastLoadDTS < DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1))'
        END


        EXEC sp_executesql
            @SQL,
            N'@RowCountOUT INT OUTPUT',
            @RowCountOUT = @RowCount OUTPUT

			SET @EventDSC = 'Rows loaded today: ' + CAST(@RowCount AS VARCHAR)

            PRINT @EventDSC

			EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
					@BatchID           = @JobID
				   ,@TableID           = @TableID
				   ,@PackageNM         = @TaskNM
				   ,@EventTypeCD       = @EventTypeCD
				   ,@TaskNM            = 'Validation Check'
				   ,@EventDSC          = @EventDSC
				   ,@BatchDefinitionID = @BatchDefinitionID
				   ,@ProcedureNM       = @ProcedureNM
				   ,@ExecStatment      = NULL
				   ,@DataMartID        = @DataMartID;

        IF @RowCount > 0
        BEGIN

            PRINT '*** VALIDATION FAILED - ABOUT TO THROW EXCEPTION ***'

            SET @EventDSC =
                CONCAT('Validation FAILED. Data already exists today in   -->   ',
                       @DatabaseNM,'.',@SchemaNM,'.',@TableNM)

            PRINT @EventDSC

			EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
					@BatchID           = @JobID
				   ,@TableID           = @TableID
				   ,@PackageNM         = @TaskNM
				   ,@EventTypeCD       = @EventTypeCD
				   ,@TaskNM            = 'Validation Status'
				   ,@EventDSC          = @EventDSC
				   ,@BatchDefinitionID = @BatchDefinitionID
				   ,@ProcedureNM       = @ProcedureNM
				   ,@ExecStatment      = NULL
				   ,@DataMartID        = @DataMartID;

            PRINT '*** CLOSING CURSOR AND THROWING EXCEPTION NOW ***'

            CLOSE validate_cursor;
            DEALLOCATE validate_cursor;

            -- Use THROW instead of RAISERROR for better error handling
            THROW 50001, 'Snapshot validation failed. Data already exists today.', 1;

        END
        ELSE
        BEGIN

            SET @EventDSC =
                CONCAT('Validation PASSED. Data has not been loaded today in   -->   ',
                       @DatabaseNM,'.',@SchemaNM,'.',@TableNM)

            PRINT @EventDSC

			EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
					@BatchID           = @JobID
				   ,@TableID           = @TableID
				   ,@PackageNM         = @TaskNM
				   ,@EventTypeCD       = @EventTypeCD
				   ,@TaskNM            = 'Validation Status'
				   ,@EventDSC          = @EventDSC
				   ,@BatchDefinitionID = @BatchDefinitionID
				   ,@ProcedureNM       = @ProcedureNM
				   ,@ExecStatment      = NULL
				   ,@DataMartID        = @DataMartID;

        END

    END
    ELSE
    BEGIN

		SET @EventDSC = 'Validation skipped (ValidateSnapshotFLG = 0)'

            PRINT @EventDSC

			EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
					@BatchID           = @JobID
				   ,@TableID           = @TableID
				   ,@PackageNM         = @TaskNM
				   ,@EventTypeCD       = @EventTypeCD
				   ,@TaskNM            = 'Validation Status'
				   ,@EventDSC          = @EventDSC
				   ,@BatchDefinitionID = @BatchDefinitionID
				   ,@ProcedureNM       = @ProcedureNM
				   ,@ExecStatment      = NULL
				   ,@DataMartID        = @DataMartID;

    END

    FETCH NEXT FROM validate_cursor INTO
          @ID
        , @DataMartID
        , @DataMartNM
        , @TableID
        , @DatabaseNM
        , @SchemaNM
        , @TableNM
        , @ValidateSnapshotFLG
        , @SnapshotPeriodCD
        , @TaskNM
        , @ProcedureNM
        , @EventTypeCD
        , @ExecStatement
        , @BatchDefinitionID

END

CLOSE validate_cursor
DEALLOCATE validate_cursor

SET @EventDSC = 'Snapshot Validation Script Complete'

PRINT @EventDSC

EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
		@BatchID           = @JobID
		,@TableID           = @TableID
		,@PackageNM         = @TaskNM
		,@EventTypeCD       = @EventTypeCD
		,@TaskNM            = 'End of Stored Proc'
		,@EventDSC          = @EventDSC
		,@BatchDefinitionID = @BatchDefinitionID
		,@ProcedureNM       = @ProcedureNM
		,@ExecStatment      = NULL
		,@DataMartID        = @DataMartID;

END
