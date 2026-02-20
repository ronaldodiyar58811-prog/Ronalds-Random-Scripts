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
	FROM ClientAdmin.ETLSequencedBatches AS esb
	LEFT JOIN CatalystAdmin.DataMartBASE AS d ON esb.FromDataMartNM = d.DataMartNM
	LEFT JOIN CatalystAdmin.ETLBatchDefinitionBASE AS bd1 ON d.DataMartID = bd1.DataMartID AND esb.FromBatchDefinitionNM = bd1.BatchDefinitionNM


	
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
	FROM ClientAdmin.ETLSequencedBatches AS esb
	LEFT JOIN CatalystAdmin.DataMartBASE AS d ON esb.ToDataMartNM = d.DataMartNM
	LEFT JOIN CatalystAdmin.ETLBatchDefinitionBASE AS bd ON d.DataMartID = bd.DataMartID AND esb.ToBatchDefinitionNM = bd.BatchDefinitionNM


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
		,'</td></tr><tr><td>'
		,CONCAT('Average Duration-',ISNULL(AvgDurationNBR,0),' min')
		,'</td></tr><tr>'
		, CASE WHEN SuccessFLG=1 then concat('<td bgcolor="#69b660ff">Finished at ',CompletedDTS) else concat('Last Run ',CompletedDTS,'<td bgcolor="#FF0000" style="color: #ffffff">Did not run today') end
		,'</td></tr>') + '</table>>];' AS SegmentLabel
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
