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

    PRINT '=== Starting Purge Process ===';
    PRINT 'EntityID: ' + CAST(@EntityID AS VARCHAR(10));
    PRINT 'JobID: ' + CAST(@JobID AS VARCHAR(10));
    
    -- Log process start
    SET @EventDSC = 'Starting Purge Process - EntityID: ' + CAST(@EntityID AS VARCHAR(10)) + ', JobID: ' + CAST(@JobID AS VARCHAR(10));
    EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
        @BatchID           = @JobID
       ,@TableID           = NULL
       ,@PackageNM         = 'PurgeHistoricalSnapshotData'
       ,@EventTypeCD       = 'PostEntity'
       ,@TaskNM            = 'Process Start'
       ,@EventDSC          = @EventDSC
       ,@BatchDefinitionID = NULL
       ,@ProcedureNM       = 'SAM.ClientAdmin.etlPurgeHistoricalSnapshotData'
       ,@ExecStatment      = NULL
       ,@DataMartID        = NULL;

    FETCH NEXT FROM purge_cursor INTO
          @ID, @DataMartID, @DataMartNM, @TableID,
          @SchemaNM, @TableNM,
          @PurgeDataFLG,
          @PurgeDateFieldNM, @PurgeLookbackDaysNBR,
          @PackageNM, @ProcedureNM, @EventTypeCD,@TaskNM,
          @BaseExecStatement, @BatchDefinitionID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT '';
        PRINT '--- Processing Table ---';
        PRINT 'Table: ' + @SchemaNM + '.' + @TableNM;
        PRINT 'TableID: ' + CAST(@TableID AS VARCHAR(10));
        PRINT 'PurgeDataFLG: ' + CAST(@PurgeDataFLG AS VARCHAR(1));
        PRINT 'PurgeDateFieldNM: ' + ISNULL(@PurgeDateFieldNM, 'NULL');
        PRINT 'PurgeLookbackDaysNBR: ' + ISNULL(CAST(@PurgeLookbackDaysNBR AS VARCHAR(10)), 'NULL');
        
        -- Log table processing start
        SET @EventDSC = 'Processing Table: ' + @SchemaNM + '.' + @TableNM + 
                        ' | PurgeDataFLG: ' + CAST(@PurgeDataFLG AS VARCHAR(1)) + 
                        ' | PurgeDateFieldNM: ' + ISNULL(@PurgeDateFieldNM, 'NULL') + 
                        ' | PurgeLookbackDaysNBR: ' + ISNULL(CAST(@PurgeLookbackDaysNBR AS VARCHAR(10)), 'NULL');
        EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
            @BatchID           = @JobID
           ,@TableID           = @TableID
           ,@PackageNM         = @PackageNM
           ,@EventTypeCD       = @EventTypeCD
           ,@TaskNM            = 'Table Processing Start'
           ,@EventDSC          = @EventDSC
           ,@BatchDefinitionID = @BatchDefinitionID
           ,@ProcedureNM       = @ProcedureNM
           ,@ExecStatment      = NULL
           ,@DataMartID        = @DataMartID;
        
        ------------------------------------------------------------------
        -- Compute Whole-Day Cutoff
        ------------------------------------------------------------------
        SET @CutoffDate = DATEADD(DAY, -ISNULL(@PurgeLookbackDaysNBR,0), CAST(GETDATE() AS DATE));
        
        PRINT 'Cutoff Date: ' + CONVERT(VARCHAR(10), @CutoffDate, 120);
        
        -- Log cutoff date
        SET @EventDSC = 'Cutoff Date Calculated: ' + CONVERT(VARCHAR(10), @CutoffDate, 120);
        EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
            @BatchID           = @JobID
           ,@TableID           = @TableID
           ,@PackageNM         = @PackageNM
           ,@EventTypeCD       = @EventTypeCD
           ,@TaskNM            = 'Cutoff Date Calculation'
           ,@EventDSC          = @EventDSC
           ,@BatchDefinitionID = @BatchDefinitionID
           ,@ProcedureNM       = @ProcedureNM
           ,@ExecStatment      = NULL
           ,@DataMartID        = @DataMartID;

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
           AND @PurgeLookbackDaysNBR > 0
        BEGIN
            PRINT 'PURGE ENABLED - Starting deletion process...';
            
            -- Log purge enabled
            SET @EventDSC = 'PURGE ENABLED - Starting deletion process for ' + @SchemaNM + '.' + @TableNM;
            EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
                @BatchID           = @JobID
               ,@TableID           = @TableID
               ,@PackageNM         = @PackageNM
               ,@EventTypeCD       = @EventTypeCD
               ,@TaskNM            = 'Purge Enabled'
               ,@EventDSC          = @EventDSC
               ,@BatchDefinitionID = @BatchDefinitionID
               ,@ProcedureNM       = @ProcedureNM
               ,@ExecStatment      = @ExecStatement
               ,@DataMartID        = @DataMartID;
            
            WHILE 1 = 1   -- Extra-safe loop
            BEGIN
                EXEC sp_executesql 
                      @DeleteSQL,
                      N'@CutoffDate DATE',
                      @CutoffDate = @CutoffDate;

                SET @RowsAffected = @@ROWCOUNT;

                PRINT 'Batch deleted: ' + CAST(@RowsAffected AS VARCHAR(10)) + ' rows';

                IF @RowsAffected = 0
                BEGIN
                    PRINT 'No more rows to delete. Exiting loop.';
                    BREAK;
                END

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
            PRINT 'PURGE DISABLED - Conditions not met:';
            IF @PurgeDataFLG = 0
                PRINT '  - PurgeDataFLG = 0';
            IF @PurgeDateFieldNM IS NULL
                PRINT '  - PurgeDateFieldNM IS NULL';
            IF @PurgeLookbackDaysNBR IS NULL
                PRINT '  - PurgeLookbackDaysNBR IS NULL';
            IF @PurgeLookbackDaysNBR = 0
                PRINT '  - PurgeLookbackDaysNBR = 0 (safety check)';
            
            -- Build detailed reason for disabled purge
            DECLARE @DisabledReason NVARCHAR(500) = 'PURGE DISABLED - Reasons: ';
            IF @PurgeDataFLG = 0
                SET @DisabledReason = @DisabledReason + 'PurgeDataFLG=0; ';
            IF @PurgeDateFieldNM IS NULL
                SET @DisabledReason = @DisabledReason + 'PurgeDateFieldNM IS NULL; ';
            IF @PurgeLookbackDaysNBR IS NULL
                SET @DisabledReason = @DisabledReason + 'PurgeLookbackDaysNBR IS NULL; ';
            IF @PurgeLookbackDaysNBR = 0
                SET @DisabledReason = @DisabledReason + 'PurgeLookbackDaysNBR=0 (safety check); ';
            
            SET @EventDSC =
                CONCAT(@DisabledReason, 
                       ' No deletes executed for ',
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
              @SchemaNM, @TableNM,
              @PurgeDataFLG,
              @PurgeDateFieldNM, @PurgeLookbackDaysNBR,
              @PackageNM, @ProcedureNM, @EventTypeCD,@TaskNM,
              @BaseExecStatement, @BatchDefinitionID;
    END

    CLOSE purge_cursor;
    DEALLOCATE purge_cursor;

    PRINT '';
    PRINT '=== Purge Process Complete ===';
    
    -- Log process completion
    SET @EventDSC = 'Purge Process Complete - EntityID: ' + CAST(@EntityID AS VARCHAR(10)) + ', JobID: ' + CAST(@JobID AS VARCHAR(10));
    EXECUTE @RC = [EDWAdmin].[CatalystAdmin].[etlSetSSISEventLog] 
        @BatchID           = @JobID
       ,@TableID           = NULL
       ,@PackageNM         = 'PurgeHistoricalSnapshotData'
       ,@EventTypeCD       = 'PostEntity'
       ,@TaskNM            = 'Process Complete'
       ,@EventDSC          = @EventDSC
       ,@BatchDefinitionID = NULL
       ,@ProcedureNM       = 'SAM.ClientAdmin.etlPurgeHistoricalSnapshotData'
       ,@ExecStatment      = NULL
       ,@DataMartID        = NULL;

END
