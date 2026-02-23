USE EDWADMIN
GO

--BEGIN
DECLARE @IDEAUri VARCHAR(255)
DECLARE @IDEAAppID INT

SELECT @IDEAUri = CASE 
		WHEN RIGHT(ds.ServiceUrl, 1) = '/'
			THEN ds.ServiceUrl
		ELSE CONCAT (
				ds.ServiceUrl
				,'/'
				)
		END
FROM EDWAdmin.CatalystAdmin.DiscoveryServiceBASE ds
WHERE ds.ServiceNM = 'IDEA-Web';

SELECT @IDEAAppID = d.DatamartID
FROM EDWAdmin.CatalystAdmin.DataMartBASE AS d
WHERE d.DataMartNM = 'ETLSequencedBatches'
	AND d.DataMartTypeDSC = 'IDEA';

--GO
WITH sb /*Sequenced Batches*/
AS (
	SELECT DISTINCT CONCAT (
			'"'
			,esb.FromDataMartNM
			,'.'
			,REPLACE(esb.FromBatchDefinitionNM,'&','and') 
			,'"'
			) AS LinkTXT
		,esb.FromDataMartNM AS DataMartNM
		,d.DataMartID
		,d.DataMartTypeDSC
		,REPLACE(esb.FromBatchDefinitionNM,'&','and') AS BatchDefinitionNM
		,bd1.BatchDefinitionID
		,esb.IsActiveFLG
	     ,(SELECT avg(DurationSecondsCNT)/60 FROM EDWAdmin.CatalystAdmin.ETLBatchHistoryBASE X
		 where x.DataMartID=bd1.DataMartID and x.BatchDefinitionID=bd1.BatchDefinitionID  AND EndDTS>GETDATE()-180 AND StatusCD='Succeeded'
		 GROUP BY DataMartID) as AvgDurationNBR
		 ,CASE WHEN CONVERT(DATE, (SELECT max(EndDTS) FROM EDWAdmin.CatalystAdmin.ETLBatchHistoryBASE z
		 WHERE  z.DataMartID=bd1.DataMartID and z.BatchDefinitionID=bd1.BatchDefinitionID  AND StatusCD='Succeeded'
		 GROUP BY DataMartID),101) = CONVERT(DATE, GETDATE(), 101 )THEN 1 ELSE 0 END as SuccessFLG
		 ,(select max(EndDTS) FROM EDWAdmin.CatalystAdmin.ETLBatchHistoryBASE z
		 WHERE  z.DataMartID=bd1.DataMartID and z.BatchDefinitionID=bd1.BatchDefinitionID  AND StatusCD='Succeeded'
		 GROUP BY DataMartID) as CompletedDTS
		 ,CASE WHEN bs.ScheduleID IS NULL THEN 'Schedule (None)' 
			   WHEN bs.EnabledFLG = 1 THEN 'Scheduled (Enabled)' 
			   WHEN bs.EnabledFLG = 0 THEN 'Scheduled (Disabled)'
			   ELSE 'Schedule (Other)'
		  END as ScheduleCategoryCD
		  ,CASE WHEN sp.PatternTypeCD IS NULL THEN 'IDEA' ELSE sp.PatternTypeCD END as SchedulePatternTypeCD
	FROM EDWAdmin.ClientAdmin.ETLSequencedBatches AS esb
	LEFT JOIN EDWAdmin.CatalystAdmin.DataMartBASE AS d ON esb.FromDataMartNM = d.DataMartNM
	LEFT JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE AS bd1 ON d.DataMartID = bd1.DataMartID AND esb.FromBatchDefinitionNM = bd1.BatchDefinitionNM
	LEFT JOIN EDWAdmin.CatalystAdmin.ETLBatchScheduleBASE bs on bd1.BatchDefinitionID = bs.BatchDefinitionID
	LEFT JOIN EDWAdmin.CatalystAdmin.ETLSchedulePatternBASE sp on bs.ScheduleID = sp.ScheduleID

	
	UNION ALL
	
	SELECT DISTINCT CONCAT (
			'"'
			,esb.ToDataMartNM
			,'.'
			,REPLACE(esb.ToBatchDefinitionNM,'&','and')
			,'"'
			) AS LinkTXT
		,esb.ToDataMartNM AS DataMartNM
		,d.DataMartID
		,d.DataMartTypeDSC
		,REPLACE(esb.ToBatchDefinitionNM,'&','and') AS BatchDefinitionNM
		,bd.BatchDefinitionID
		,esb.IsActiveFLG
	   ,(SELECT avg(DurationSecondsCNT)/60 FROM EDWAdmin.CatalystAdmin.ETLBatchHistoryBASE X
		 where x.DataMartID=bd.DataMartID and x.BatchDefinitionID=bd.BatchDefinitionID  AND EndDTS>GETDATE()-180 AND StatusCD='Succeeded'
		 GROUP BY DataMartID) as AvgDurationNBR
	 ,CASE WHEN CONVERT(DATE, (SELECT max(EndDTS) FROM EDWAdmin.CatalystAdmin.ETLBatchHistoryBASE z
		 WHERE  z.DataMartID=bd.DataMartID and z.BatchDefinitionID=bd.BatchDefinitionID  AND StatusCD='Succeeded'
		 GROUP BY DataMartID),101) = CONVERT(DATE, GETDATE(), 101 )THEN 1 ELSE 0 END as SuccessFLG	 
		, (SELECT max(EndDTS) FROM EDWAdmin.CatalystAdmin.ETLBatchHistoryBASE z
		 WHERE  z.DataMartID=bd.DataMartID and z.BatchDefinitionID=bd.BatchDefinitionID  AND StatusCD='Succeeded'
		 GROUP BY DataMartID) as CompletedDTS
		,CASE WHEN bs.ScheduleID IS NULL THEN 'Schedule (None)' 
			   WHEN bs.EnabledFLG = 1 THEN 'Scheduled (Enabled)' 
			   WHEN bs.EnabledFLG = 0 THEN 'Scheduled (Disabled)'
			   ELSE 'Schedule (Other)'
		 END as ScheduleCategoryCD
		,CASE WHEN sp.PatternTypeCD IS NULL THEN 'IDEA' ELSE sp.PatternTypeCD END as SchedulePatternTypeCD	  
	FROM EDWAdmin.ClientAdmin.ETLSequencedBatches AS esb
	LEFT JOIN EDWAdmin.CatalystAdmin.DataMartBASE AS d ON esb.ToDataMartNM = d.DataMartNM
	LEFT JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE AS bd ON d.DataMartID = bd.DataMartID AND esb.ToBatchDefinitionNM = bd.BatchDefinitionNM
	LEFT JOIN EDWAdmin.CatalystAdmin.ETLBatchScheduleBASE bs on bd.BatchDefinitionID = bs.BatchDefinitionID
	LEFT JOIN EDWAdmin.CatalystAdmin.ETLSchedulePatternBASE sp on bs.ScheduleID = sp.ScheduleID
	)
	
SELECT DISTINCT sb.LinkTXT + ' [label=<<table border="1" cellspacing="0" cellpadding="5" cellborder="0">' + CONCAT (
		'<tr>'
		,CASE 
			WHEN sb.DataMartTypeDSC = 'Source'
				THEN '<td bgcolor="#cee2ffff">'
			WHEN sb.DataMartTypeDSC = 'Subject Area'
				THEN '<td bgcolor="#a487b7">'
			ELSE '<td bgcolor="#cfcfcfed" data-cell-info="Broken References">'
			END
		,'<b>'
		,sb.DataMartNM
		,'</b></td></tr>'
		) + CONCAT (
		CASE 
			WHEN sb.BatchDefinitionID IS NOT NULL				THEN '<tr><td bgcolor="#ffffff">'
			ELSE '<tr><td bgcolor="#ffb255ed" data-cell-info="Broken References">'
			END
		, sb.BatchDefinitionNM
		,'</td></tr>'
		,'<tr><td>'
		,CONCAT('Average Duration-',ISNULL(AvgDurationNBR,0),' min')
		,'</td></tr>'
		,'<tr><td>'
		,CONCAT(ScheduleCategoryCD, ' | ', SchedulePatternTypeCD)
		,'</td></tr>'
		, CASE WHEN SuccessFLG=1 
			then concat('<tr><td bgcolor="#69b660ff">Finished at ',CompletedDTS,'</td></tr>') 
			else concat('<tr><td>Last Run ',CompletedDTS,'</td></tr>','<tr><td bgcolor="#FF0000" style="color: #ffffff">Did not run today</td></tr>') 
		  end
		) + '</table>>];' AS SegmentLabel
FROM sb;

SELECT CONCAT (
		'"'
		,esb.FromDataMartNM
		,'.'
		,REPLACE(esb.FromBatchDefinitionNM,'&','and')
		,'" -> "'
		,esb.ToDataMartNM
		,'.'
		,REPLACE(esb.ToBatchDefinitionNM,'&','and')
		,'"'
		) + CONCAT (
		' [href="'
		,@IDEAUri
		,'applications/'
		,@IDEAAppID
		,'/entry/'
		,esb.ID
		,'" '
		,CASE 
			WHEN esb.IsActiveFLG = 1
				THEN 'target="_blank" rel="noopener noreferrer" style="solid"'
			ELSE 'style="dashed" color="#5E676F"'
			END
		,']'
		) AS SegmentDisplay
FROM ClientAdmin.ETLSequencedBatches AS esb
	--END
