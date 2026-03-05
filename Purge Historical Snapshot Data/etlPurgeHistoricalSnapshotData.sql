USE [SAM]
GO
/****** Object:  StoredProcedure [ClientAdmin].[etlPurgeHistoricalSnapshotData]    Script Date: 3/5/2026 2:22:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   PROCEDURE [ClientAdmin].[etlPurgeHistoricalSnapshotData]
      @EntityID INT
    , @JobID    INT
AS
BEGIN

--DECLARE @JobID as INT
--DECLARE @EntityID as INT

--SET @EntityID = 43066
--SET @JobID = 302798

    SET NOCOUNT ON;

    ----------------------------------------------------------------------
    -- Variable Declarations
    ----------------------------------------------------------------------
    DECLARE 
          @ID                   INT
		, @BatchID				INT
        , @DataMartID           INT
        , @DataMartNM           NVARCHAR(255)
        , @TableID              INT
        , @SchemaNM             SYSNAME
        , @TableNM              SYSNAME
        , @ValidationFLG        BIT
        , @UniqueIndexNM        SYSNAME
        , @PurgeDataFLG         BIT
        , @PurgeDateFieldNM     SYSNAME
        , @PurgeLookbackDaysNBR INT
        , @PackageNM            NVARCHAR(255)
        , @ProcedureNM          NVARCHAR(255)
        , @EventTypeCD          NVARCHAR(255)
		, @TaskNM				NVARCHAR(255)
        , @BaseExecStatement    NVARCHAR(MAX)
        , @BatchDefinitionID    INT
        , @CutoffDate           DATE
        , @DeleteSQL            NVARCHAR(MAX)
        , @ExecStatement        NVARCHAR(MAX)
        , @EventDSC             NVARCHAR(4000)
        , @RowsAffected         INT
        , @BatchSize            INT = 10000
        , @RC                   INT;

    ----------------------------------------------------------------------
    -- Cursor Using Updated Base Query (all fields retained)
    ----------------------------------------------------------------------
    DECLARE purge_cursor CURSOR FAST_FORWARD FOR
    SELECT sn.[ID]
          ,dm.DataMartID
          ,sn.[DataMartNM]
          ,sn.[TableID]
          ,tb.SchemaNM
          ,tb.[TableNM]
          ,[ValidationFLG]
          ,sn.[UniqueIndexNM]
          ,sn.[PurgeDataFLG]
          ,sn.[PurgeDateFieldNM]
          ,sn.[PurgeLookbackDaysNBR]
          ,'PurgeHistoricalSnapshotData'
          ,'SAM.ClientAdmin.etlPurgeHistoricalSnapshotData'
          ,'PostEntity'
		  ,'DELETE Statement'
          ,'EXEC ClientAdmin.etlPurgeHistoricalSnapshotData @BatchID = ' 
                + CAST(@JobID AS VARCHAR(255)) 
                + ', @EntityID = ' 
                + CAST(eb.EntityID AS VARCHAR(255))
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

    OPEN purge_cursor;

    FETCH NEXT FROM purge_cursor INTO
          @ID, @DataMartID, @DataMartNM, @TableID,
          @SchemaNM, @TableNM, @ValidationFLG,
          @UniqueIndexNM, @PurgeDataFLG,
          @PurgeDateFieldNM, @PurgeLookbackDaysNBR,
          @PackageNM, @ProcedureNM, @EventTypeCD,@TaskNM,
          @BaseExecStatement, @BatchDefinitionID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        ------------------------------------------------------------------
        -- Compute Whole-Day Cutoff
        ------------------------------------------------------------------
        SET @CutoffDate = DATEADD(DAY, -ISNULL(@PurgeLookbackDaysNBR,0), CAST(GETDATE() AS DATE));

        ------------------------------------------------------------------
        -- Build DELETE Statement (execution or preview)
        ------------------------------------------------------------------
        SET @DeleteSQL = N'
            DELETE TOP (' + CAST(@BatchSize AS NVARCHAR(10)) + N')
            FROM ' + QUOTENAME(@SchemaNM) + N'.' + QUOTENAME(@TableNM) + N'
            WHERE ' + QUOTENAME(@PurgeDateFieldNM) + N' < @CutoffDate;';

        SET @ExecStatement = REPLACE(@DeleteSQL, 
                                     '@CutoffDate', 
                                     '''' + CONVERT(VARCHAR(10), @CutoffDate, 120) + '''');

        ------------------------------------------------------------------
        -- PURGE ENABLED
        ------------------------------------------------------------------
        IF @PurgeDataFLG = 1 
           AND @PurgeDateFieldNM IS NOT NULL
           AND @PurgeLookbackDaysNBR IS NOT NULL
        BEGIN
            WHILE 1 = 1   -- Extra-safe loop
            BEGIN
                EXEC sp_executesql 
                      @DeleteSQL,
                      N'@CutoffDate DATE',
                      @CutoffDate = @CutoffDate;

                SET @RowsAffected = @@ROWCOUNT;

                IF @RowsAffected = 0
                    BREAK;

                SET @EventDSC =
                    CONCAT(@RowsAffected,
                           ' records deleted from ',
                           @SchemaNM, '.', @TableNM,
                           ' using cutoff date ',
                           CONVERT(VARCHAR(10), @CutoffDate,120),
                           '.');

                SET @BatchID = @JobID;

				EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
					    @BatchID           = @BatchID
					   ,@TableID           = @TableID
					   ,@PackageNM         = @PackageNM
					   ,@EventTypeCD       = @EventTypeCD
					   ,@TaskNM            = @TaskNM
					   ,@EventDSC          = @EventDSC
					   ,@BatchDefinitionID = @BatchDefinitionID
					   ,@ProcedureNM       = @ProcedureNM
					   ,@ExecStatment      = @ExecStatement
					   ,@DataMartID        = @DataMartID;
            END
        END
        ELSE
        BEGIN
            ------------------------------------------------------------------
            -- PURGE DISABLED (Audit-Only Mode)
            ------------------------------------------------------------------
            SET @EventDSC =
                CONCAT('PurgeDataFLG = 0. No deletes executed for ',
                       @SchemaNM, '.', @TableNM,
                       '. Delete statement preview only.');
			SET @BatchID = @JobID;

			EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
					@BatchID           = @BatchID
				   ,@TableID           = @TableID
				   ,@PackageNM         = @PackageNM
				   ,@EventTypeCD       = @EventTypeCD
				   ,@TaskNM            = @TaskNM
				   ,@EventDSC          = @EventDSC
				   ,@BatchDefinitionID = @BatchDefinitionID
				   ,@ProcedureNM       = @ProcedureNM
				   ,@ExecStatment      = @ExecStatement
				   ,@DataMartID        = @DataMartID;
        END

        FETCH NEXT FROM purge_cursor INTO
              @ID, @DataMartID, @DataMartNM, @TableID,
              @SchemaNM, @TableNM, @ValidationFLG,
              @UniqueIndexNM, @PurgeDataFLG,
              @PurgeDateFieldNM, @PurgeLookbackDaysNBR,
              @PackageNM, @ProcedureNM, @EventTypeCD,@TaskNM,
              @BaseExecStatement, @BatchDefinitionID;
    END

    CLOSE purge_cursor;
    DEALLOCATE purge_cursor;

END
