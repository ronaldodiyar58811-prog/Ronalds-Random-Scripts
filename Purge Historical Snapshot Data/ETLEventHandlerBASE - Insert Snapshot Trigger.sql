USE [EDWAdmin]
GO

INSERT INTO [CatalystAdmin].[ETLEventHandlerBASE]
           ([EventHandlerNM]
           ,[EventNM]
           ,[JobTypeCD]
           ,[MethodCD]
           ,[ObjectID]
           ,[ObjectTypeCD]
           ,[CommandTXT]
           ,[IsAsyncFLG]
           ,[FailsExecutionFLG]
           ,[OrderNBR]
           ,[TimeoutMinutesNBR]
           ,[EventHandlerDSC]
           ,[IsEnabledFLG]
           ,[LastModifiedDTS]
           ,[LastModifiedByNM])
     VALUES
           ('PurgeHistoricalSnapshotData'
           ,'PostEntity'
           ,'Batch'
           ,'PowerShell'
           ,0
           ,'System'
           ,'G:\Databases\Staging\Scripts\PurgeHistoricalSnapshotData.ps1 -entityID $entity -jobID $batchExecution -serverNM "localhost"'
           ,0
           ,1
           ,6
           ,0
           ,'This PowerShell Script executes a stored procedure that purges historical snapshot data.'
           ,1
           ,GETDATE()
           ,'ronald.odiyar@renown.org')
GO

