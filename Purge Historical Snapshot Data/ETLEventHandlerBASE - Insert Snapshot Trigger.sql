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
           ,'This PowerShell Script executes a stored procedure that purges historical snapshot data for defined entities.'
           ,1
           ,GETDATE()
           ,'ronald.odiyar@renown.org')
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
           ('ValidateSnapshotData'
           ,'PreEntity'
           ,'Batch'
           ,'PowerShell'
           ,0
           ,'System'
           ,'G:\Databases\Staging\Scripts\ValidateSnapshotData.ps1 -entityID $entity -jobID $batchExecution -serverNM "localhost"'
           ,0
           ,1
           ,6
           ,0
           ,'This PowerShell Script executes a stored procedure that validates if snapshot data has already exists for a given entity on the given day or month. The purpose is to prevent duplicate data from being loaded into the snapshot table.'
           ,1
           ,GETDATE()
           ,'ronald.odiyar@renown.org')
GO