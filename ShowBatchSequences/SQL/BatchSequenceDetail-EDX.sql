USE EDWADMIN
GO
with 
list as
(SELECT  DISTINCT  CONCAT (
			'"'
			,FromDataMart.DataMartNM
			,'.'
			,CASE WHEN FromDataMart.DataMartTypeDSC<>'IDEA' THEN COALESCE(FromBatch.BatchDefinitionNM,FromBatchAll.BatchDefinitionNM,FromBatchByLoadType.BatchDefinitionNM,FromBatchAllSpecificConnection.BatchDefinitionNM,'No Batch is created')
			      ELSE 'IDEA Source - Batch is not needed'  END 
			,'"'
			) AS LinkTXT
FROM	   EDWAdmin.CatalystAdmin.DataMartBASE As ToDataMart
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.SAMBASE s ON s.DataMartID =  ToDataMart.DataMartID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE b ON b.DataMartID = s.DataMartID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingDependencyBASE bd ON bd.BindingID = b.BindingID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.TableBASE FromTable ON FromTable.TableID = bd.SourceEntityID /*source table in the source mart or a sam*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.TableBASE ToTable ON ToTable.TableID=b.DestinationEntityID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.DataMartBASE FromDataMart ON FromDataMart.DataMartID = FromTable.DataMartID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ConnectionBASE c ON c.ConnectionID = FromTable.SourceConnectionID
	   /* this is for individual tables in a batch*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionTableBASE FromBatchTable ON FromBatchTable.TableID=FromTable.TableID
        LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatch ON FromBatch.BatchDefinitionID=FromBatchTable.BatchDefinitionID
        /* for all tables and connections*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchAll ON FromBatchAll.DataMartID=FromTable.DataMartID and FromBatchAll.BatchLoadTypeCD='All' and FromBatchAll.SourceConnectionID is null
        /* for all tables and a selected connection*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE destb on FromTable.TableID=destb.DestinationEntityID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchAllSpecificConnection ON FromBatchAllSpecificConnection.DataMartID=FromTable.DataMartID and FromBatchAllSpecificConnection.BatchLoadTypeCD='All' and FromBatchAllSpecificConnection.SourceConnectionID = destb.SourceConnectionID
        /*for specific load type*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchByLoadType ON FromBatchByLoadType.DataMartID=FromTable.DataMartID and  FromBatchByLoadType.BatchLoadTypeCD =FromTable.LoadTypeCD 
 	   /* this is for individual tables in a batch for down stream tables*/
	 --  LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionTableBASE ToBatchTable ON ToBatchTable.TableID=ToTable.TableID
     --   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatch ON ToBatch.BatchDefinitionID=ToBatchTable.BatchDefinitionID
        
	--   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchAll ON ToBatchAll.DataMartID=ToTable.DataMartID and ToBatchAll.BatchLoadTypeCD='All' and ToBatchAll.SourceConnectionID is null 
        /* for all tables and a selected connection*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE ToDestB on ToTable.TableID=ToDestB.DestinationEntityID
	  -- LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchAllSpecificConnection ON ToBatchAllSpecificConnection.DataMartID=ToTable.DataMartID and ToBatchAllSpecificConnection.BatchLoadTypeCD='All' and ToBatchAllSpecificConnection.SourceConnectionID = ToDestB.SourceConnectionID
       
	  -- LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchByLoadType ON ToBatchByLoadType.DataMartID=ToTable.DataMartID and ToBatchByLoadType.BatchLoadTypeCD='All' and ToBatchByLoadType.BatchLoadTypeCD=ToTable.LoadTypeCD 
WHERE  (destb.SourceConnectionID<>ToDestB.SourceConnectionID )/*Exclude binding dependencies from same SAM*/
	   AND
	     b.BindingStatusCD = 'Active'
union 
SELECT  DISTINCT  CONCAT (
			'"'
			,ToDataMart.DataMartNM
			,'.'
			,CASE WHEN ToDataMart.DataMartTypeDSC<>'IDEA' THEN COALESCE(toBatch.BatchDefinitionNM,toBatchAll.BatchDefinitionNM,toBatchByLoadType.BatchDefinitionNM,toBatchAllSpecificConnection.BatchDefinitionNM,'No Batch is created')
			      ELSE 'IDEA Source - Batch is not needed'  END 
			,'"'
			) AS LinkTXT
FROM	   EDWAdmin.CatalystAdmin.DataMartBASE As ToDataMart
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.SAMBASE s ON s.DataMartID =  ToDataMart.DataMartID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE b ON b.DataMartID = s.DataMartID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingDependencyBASE bd ON bd.BindingID = b.BindingID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.TableBASE FromTable ON FromTable.TableID = bd.SourceEntityID /*source table in the source mart or a sam*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.TableBASE ToTable ON ToTable.TableID=b.DestinationEntityID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.DataMartBASE FromDataMart ON FromDataMart.DataMartID = FromTable.DataMartID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ConnectionBASE c ON c.ConnectionID = FromTable.SourceConnectionID
	   /* this is for individual tables in a batch*/
	 --  LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionTableBASE FromBatchTable ON FromBatchTable.TableID=FromTable.TableID
      --  LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatch ON FromBatch.BatchDefinitionID=FromBatchTable.BatchDefinitionID
        /* for all tables and connections*/
	 --  LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchAll ON FromBatchAll.DataMartID=FromTable.DataMartID and FromBatchAll.BatchLoadTypeCD='All' and FromBatchAll.SourceConnectionID is null
        /* for all tables and a selected connection*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE destb on FromTable.TableID=destb.DestinationEntityID
	  -- LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchAllSpecificConnection ON FromBatchAllSpecificConnection.DataMartID=FromTable.DataMartID and FromBatchAllSpecificConnection.BatchLoadTypeCD='All' and FromBatchAllSpecificConnection.SourceConnectionID = destb.SourceConnectionID
        /*for specific load type*/
	 --  LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchByLoadType ON FromBatchByLoadType.DataMartID=FromTable.DataMartID and  FromBatchByLoadType.BatchLoadTypeCD =FromTable.LoadTypeCD 
 	   /* this is for individual tables in a batch for down stream tables*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionTableBASE ToBatchTable ON ToBatchTable.TableID=ToTable.TableID
        LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatch ON ToBatch.BatchDefinitionID=ToBatchTable.BatchDefinitionID
        LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchAll ON ToBatchAll.DataMartID=ToTable.DataMartID and ToBatchAll.BatchLoadTypeCD='All' and ToBatchAll.SourceConnectionID is null 
        /* for all tables and a selected connection*/
	 LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE ToDestB on ToTable.TableID=ToDestB.DestinationEntityID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchAllSpecificConnection ON ToBatchAllSpecificConnection.DataMartID=ToTable.DataMartID and ToBatchAllSpecificConnection.BatchLoadTypeCD='All' and ToBatchAllSpecificConnection.SourceConnectionID = ToDestB.SourceConnectionID
       
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchByLoadType ON ToBatchByLoadType.DataMartID=ToTable.DataMartID and ToBatchByLoadType.BatchLoadTypeCD='All' and ToBatchByLoadType.BatchLoadTypeCD=ToTable.LoadTypeCD 
WHERE  (destb.SourceConnectionID<>ToDestB.SourceConnectionID )/*Exclude binding dependencies from same SAM*/
	   AND
	     b.BindingStatusCD = 'Active')
,sb 
/*this query returns a list of defined batches in ETL Batch definition base table 
  and missing batches that needed to run for downstream SAMs\sources*/
AS (/* a list of batches defined on the client system*/
	SELECT DISTINCT CONCAT (
			'"'
			,d.DataMartNM
			,'.'
			,CASE WHEN D.DataMartTypeDSC<>'IDEA' THEN COALESCE(bd1.BatchDefinitionNM,'No Batch is created')
			      ELSE 'IDEA Source - Batch is not needed'  END 
			,'"'
			) AS LinkTXT
		,d.DataMartNM AS DataMartNM
		,d.DataMartID
		,d.DataMartTypeDSC
		,CASE WHEN D.DataMartTypeDSC<>'IDEA' THEN COALESCE(bd1.BatchDefinitionNM,'No Batch is created')
			      ELSE 'IDEA Source - Batch is not needed'  END  BatchDefinitionNM
		,bd1.BatchDefinitionID
		,'' as IsActiveFLG
	     ,(SELECT avg(DurationSecondsCNT)/60 FROM EDWAdmin.CatalystAdmin.ETLBatchHistoryBASE X
		 where x.DataMartID=bd1.DataMartID and x.BatchDefinitionID=bd1.BatchDefinitionID  AND EndDTS>GETDATE()-180 AND StatusCD='Succeeded'
		 GROUP BY DataMartID) as AvgDurationNBR
		 ,CASE WHEN CONVERT(DATE, (SELECT max(EndDTS) FROM EDWAdmin.CatalystAdmin.ETLBatchHistoryBASE z
		 WHERE  z.DataMartID=bd1.DataMartID and z.BatchDefinitionID=bd1.BatchDefinitionID  AND StatusCD='Succeeded'
		 GROUP BY DataMartID),101) = CONVERT(DATE, GETDATE(), 101 )THEN 1 ELSE 0 END as SuccessFLG
		 ,(select max(EndDTS) FROM EDWAdmin.CatalystAdmin.ETLBatchHistoryBASE z
		 WHERE  z.DataMartID=bd1.DataMartID and z.BatchDefinitionID=bd1.BatchDefinitionID  AND StatusCD='Succeeded'
		 GROUP BY DataMartID) as CompletedDTS
		 ,DATEPART(HH, LastRunDTS)  AS LastRunHourTXT
	FROM CatalystAdmin.DataMartBASE AS d 
	LEFT JOIN CatalystAdmin.ETLBatchDefinitionBASE AS bd1 ON d.DataMartID = bd1.DataMartID

	WHERE D.IsHiddenFLg='N' 
	
	UNION
	/* a list of missing batches from the source side*/
	SELECT  DISTINCT 
	           CONCAT (
				'"'
				,fromDataMart.DataMartNM
				,'.'
				,'No Batch is created'
				,'"'
				) AS LinkTXT
			 ,FromDataMart.DataMartNM AS DataMartNM
			 ,FromDataMart.DataMartID DataMartID
			 ,FromDataMart.DataMartTypeDSC DataMartTypeDSC
			 ,'No Batch is created' BatchDefinitionNM
			 ,NULL BatchDefinitionID
			 ,'' as IsActiveFLG
			 ,NULL as AvgDurationNBR
			 ,null as SuccessFLG
			 ,NULL CompletedDTS
			  ,NULL AS LastRunHourTXT
			 FROM	   EDWAdmin.CatalystAdmin.DataMartBASE As ToDataMart
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.SAMBASE s ON s.DataMartID =  ToDataMart.DataMartID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE b ON b.DataMartID = s.DataMartID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingDependencyBASE bd ON bd.BindingID = b.BindingID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.TableBASE FromTable ON FromTable.TableID = bd.SourceEntityID /*source table in the source mart or a sam*/
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.TableBASE ToTable ON ToTable.TableID=b.DestinationEntityID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.DataMartBASE FromDataMart ON FromDataMart.DataMartID = FromTable.DataMartID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ConnectionBASE c ON c.ConnectionID = FromTable.SourceConnectionID
				    /* this is for individual tables in a batch*/
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionTableBASE FromBatchTable ON FromBatchTable.TableID=FromTable.TableID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatch ON FromBatch.BatchDefinitionID=FromBatchTable.BatchDefinitionID
				    /* for all tables and connections*/
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchAll ON FromBatchAll.DataMartID=FromTable.DataMartID and FromBatchAll.BatchLoadTypeCD='All' and FromBatchAll.SourceConnectionID is null
				    /* for all tables and a selected connection*/
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE destb on FromTable.TableID=destb.DestinationEntityID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchAllSpecificConnection ON FromBatchAllSpecificConnection.DataMartID=FromTable.DataMartID and FromBatchAllSpecificConnection.BatchLoadTypeCD='All' and FromBatchAllSpecificConnection.SourceConnectionID = destb.SourceConnectionID
				    /*for specific load type*/
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchByLoadType ON FromBatchByLoadType.DataMartID=FromTable.DataMartID and  FromBatchByLoadType.BatchLoadTypeCD =FromTable.LoadTypeCD 
			LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE ToDestB on ToTable.TableID=ToDestB.DestinationEntityID
			 WHERE  (destb.SourceConnectionID<>ToDestB.SourceConnectionID )/*Exclude binding dependencies from same SAM*/
				    AND
					 b.BindingStatusCD = 'Active' --AND D.DataMartTypeDSC<>'IDEA' AND TD.DataMartTypeDSC<>'IDEA'
				 AND ((COALESCE(FromBatch.BatchDefinitionNM,FromBatchAll.BatchDefinitionNM,FromBatchByLoadType.BatchDefinitionNM,FromBatchAllSpecificConnection.BatchDefinitionNM) is null and FromDataMart.DataMartTypeDSC<>'IDEA') 
				 )
			 UNION
			 /* a list of missing batches from the destination side*/
			 SELECT  DISTINCT CONCAT (
						 '"'
						 ,ToDataMart.DataMartNM
						 ,'.'
						 ,'No Batch is created'
						 ,'"'
						 ) AS LinkTXT
					 ,ToDataMart.DataMartNM AS DataMartNM
					 ,ToDataMart.DataMartID DataMartID
					 ,ToDataMart.DataMartTypeDSC DataMartTypeDSC
					 ,'No Batch is created' BatchDefinitionNM
					 ,NULL BatchDefinitionID
					 ,'' as IsActiveFLG
					 ,NULL as AvgDurationNBR
					 ,null as SuccessFLG
					 ,NULL CompletedDTS
	                     ,NULL AS LastRunHourTXT
			 FROM	   EDWAdmin.CatalystAdmin.DataMartBASE As ToDataMart
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.SAMBASE s ON s.DataMartID =  ToDataMart.DataMartID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE b ON b.DataMartID = s.DataMartID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingDependencyBASE bd ON bd.BindingID = b.BindingID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.TableBASE FromTable ON FromTable.TableID = bd.SourceEntityID /*source table in the source mart or a sam*/
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.TableBASE ToTable ON ToTable.TableID=b.DestinationEntityID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.DataMartBASE FromDataMart ON FromDataMart.DataMartID = FromTable.DataMartID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ConnectionBASE c ON c.ConnectionID = FromTable.SourceConnectionID
				    /* this is for individual tables in a batch for down stream tables*/
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionTableBASE ToBatchTable ON ToBatchTable.TableID=ToTable.TableID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatch ON ToBatch.BatchDefinitionID=ToBatchTable.BatchDefinitionID
        
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchAll ON ToBatchAll.DataMartID=ToTable.DataMartID and ToBatchAll.BatchLoadTypeCD='All' and ToBatchAll.SourceConnectionID is null 
				    /* for all tables and a selected connection*/
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE ToDestB on ToTable.TableID=ToDestB.DestinationEntityID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchAllSpecificConnection ON ToBatchAllSpecificConnection.DataMartID=ToTable.DataMartID and ToBatchAllSpecificConnection.BatchLoadTypeCD='All' and ToBatchAllSpecificConnection.SourceConnectionID = ToDestB.SourceConnectionID
                        LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE destb on FromTable.TableID=destb.DestinationEntityID
				    LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchByLoadType ON ToBatchByLoadType.DataMartID=ToTable.DataMartID and ToBatchByLoadType.BatchLoadTypeCD='All' and ToBatchByLoadType.BatchLoadTypeCD=ToTable.LoadTypeCD 
			 WHERE  (destb.SourceConnectionID<>todestb.SourceConnectionID )/*Exclude binding dependencies from same SAM*/
				    AND
					 b.BindingStatusCD = 'Active' --AND D.DataMartTypeDSC<>'IDEA' AND TD.DataMartTypeDSC<>'IDEA'
				 AND ((COALESCE(ToBatch.BatchDefinitionNM,ToBatchAll.BatchDefinitionNM,ToBatchByLoadType.BatchDefinitionNM,ToBatchAllSpecificConnection.BatchDefinitionNM) is null and ToDataMart.DataMartTypeDSC<>'IDEA' ))

				 )

/* format the boxes on a diagram, include source  mart\sam name, the batch, completion date and time and average duration*/	
SELECT DISTINCT sb.LinkTXT + ' [label=<<table border="1" cellspacing="0" cellpadding="5" cellborder="0">' + CONCAT (
		'<tr>'
		,CASE 
			WHEN sb.DataMartTypeDSC = 'Source'
				THEN '<td bgcolor="#fffece">'
			WHEN sb.DataMartTypeDSC = 'Subject Area'
				THEN '<td bgcolor="#ffdb99">'
               WHEN sb.DataMartTypeDSC='IDEA'
			     THEN '<td bgcolor="#DDA0DD">'
			ELSE '<td bgcolor="#F13C45">'
			END
		,'<b>'
		,sb.DataMartNM
		,'</b></td></tr>'
		) + CONCAT (
		CASE 
			WHEN sb.DataMartTypeDSC='IDEA' OR sb.BatchDefinitionID IS NOT NULL	THEN '<tr><td bgcolor="#FFFFFF">'
			ELSE '<tr><td bgcolor="#F13C45">'
			END
		, sb.BatchDefinitionNM
		,'</td></tr><tr><td>'
		,CASE WHEN sb.DataMartTypeDSC<>'IDEA' THEN CONCAT('Average Duration-',ISNULL(AvgDurationNBR,0),' min') END
		,'</td></tr><tr>'
		, CASE WHEN SuccessFLG=1  then concat('<td bgcolor="#c3e5d3">Finished at ',CompletedDTS) 
		       WHEN sb.DataMartTypeDSC='IDEA' then '<td bgcolor="#c3e5d3">'
		else concat('Last Run ',CompletedDTS,'<td bgcolor="#FF0000">Did not run today') end
		,'</td></tr>') + '</table>>];' AS SegmentLabel
		,LastRunHourTXT
		
FROM sb
inner join list on sb.LinkTXT=list.linktxt


--UNION
--/*{ rank = same; "2 pm"; "SharedClinical.Shared Clinical Full Override"; "SharedClinical.Orlando Shared Clinical"; }
--{ rank = same; "8 pm"; "Population Explorer.Orlando Population Explorer"; }*/
--/* assign scheduled time so the box will position on the graph according to the scheduled time*/	
--SELECT CONCAT ('{ rank = same; '
--	  ,'"' 
--      ,CASE WHEN CAST(DATEPART(hh, LastRunDTS) AS int)>12
--          THEN CONCAT(CAST(DATEPART(hh, LastRunDTS) AS int)-12 ,' pm')
--         WHEN CAST(DATEPART(hh, LastRunDTS) AS int)<12 
--	    THEN CONCAT(DATEPART(hh, LastRunDTS),' am') 
--	    ELSE 'Not Scheduled' END
--      ,'"; "'

--    , D.DataMartNM
--    ,'.'
--    ,sb.BatchDefinitionNM
--    ,'";' 
--   ,'}') as SegmentLabel
--   , DATEPART(hh, LastRunDTS) AS LastRunHourTXT
--  FROM sb  
--   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE EBS ON SB.BatchDefinitionID=EBS.BatchDefinitionID
--  LEFT OUTER JOIN EDWAdmin.CatalystAdmin.DataMartBASE D ON D.DataMartID=SB.DataMartID
--  inner join list on sb.LinkTXT=list.linktxt
  order by LastRunHourTXT, SegmentLabel

;

/* format connections between the boxes of the diagram*/
SELECT  DISTINCT 

CONCAT (
		'"'
		,FromDataMart.DataMartNM
		,'.'
		,CASE WHEN FromDataMart.DataMartTypeDSC<>'IDEA' THEN COALESCE(FromBatch.BatchDefinitionNM,FromBatchAll.BatchDefinitionNM,FromBatchByLoadType.BatchDefinitionNM,FromBatchAllSpecificConnection.BatchDefinitionNM,'No Batch is created')
			      ELSE 'IDEA Source - Batch is not needed'  END
		,'" -> "'
		,ToDataMart.DataMartNM
		,'.'
		,CASE WHEN ToDataMart.DataMartTypeDSC<>'IDEA' THEN COALESCE(ToBatch.BatchDefinitionNM,ToBatchAll.BatchDefinitionNM,ToBatchByLoadType.BatchDefinitionNM,ToBatchAllSpecificConnection.BatchDefinitionNM,'No Batch is created')
			      ELSE 'IDEA Source - Batch is not needed'  END  
		,'"'
		--, ' [headlabel="'
		--,CASE WHEN FromDataMart.DataMartTypeDSC<>'IDEA' THEN COALESCE(FromBatch.BatchDefinitionNM,FromBatchAll.BatchDefinitionNM,FromBatchByLoadType.BatchDefinitionNM,FromBatchAllSpecificConnection.BatchDefinitionNM,'No Batch is created')
		--	      ELSE 'IDEA Source - Batch is not needed'  END
		--,'",labeldistance=15,fontname=Arial, fontsize=8,labeltooltip="'
		--,CASE WHEN FromDataMart.DataMartTypeDSC<>'IDEA' THEN COALESCE(FromBatch.BatchDefinitionNM,FromBatchAll.BatchDefinitionNM,FromBatchByLoadType.BatchDefinitionNM,FromBatchAllSpecificConnection.BatchDefinitionNM,'No Batch is created')
		--	      ELSE 'IDEA Source - Batch is not needed'  END
		--,'"]'
		) AS SegmentDisplay
		--,CASE WHEN COALESCE(FromBatch.LastRunDTS,FromBatchAll.LastRunDTS,FromBatchByLoadType.LastRunDTS,FromBatchAllSpecificConnection.LastRunDTS) IS NULL THEN 'Not Scheduled'
		--WHEN CAST(DATEPART(hh, COALESCE(FromBatch.LastRunDTS,FromBatchAll.LastRunDTS,FromBatchByLoadType.LastRunDTS,FromBatchAllSpecificConnection.LastRunDTS)) AS int)>12 THEN CONCAT(CAST(DATEPART(hh, COALESCE(FromBatch.LastRunDTS,FromBatchAll.LastRunDTS,FromBatchByLoadType.LastRunDTS,FromBatchAllSpecificConnection.LastRunDTS)) AS int)-12 ,' pm')
  --       WHEN CAST(DATEPART(hh, COALESCE(FromBatch.LastRunDTS,FromBatchAll.LastRunDTS,FromBatchByLoadType.LastRunDTS,FromBatchAllSpecificConnection.LastRunDTS)) AS int)<12 THEN CONCAT(DATEPART(hh, COALESCE(FromBatch.LastRunDTS,FromBatchAll.LastRunDTS,FromBatchByLoadType.LastRunDTS,FromBatchAllSpecificConnection.LastRunDTS)),' am') 
	 --   END
	,     DATEPART(hh, COALESCE(FromBatch.LastRunDTS,FromBatchAll.LastRunDTS,FromBatchByLoadType.LastRunDTS,FromBatchAllSpecificConnection.LastRunDTS))	 LastRunHourTXT	
FROM	   EDWAdmin.CatalystAdmin.DataMartBASE As ToDataMart
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.SAMBASE s ON s.DataMartID =  ToDataMart.DataMartID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE b ON b.DataMartID = s.DataMartID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingDependencyBASE bd ON bd.BindingID = b.BindingID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.TableBASE FromTable ON FromTable.TableID = bd.SourceEntityID /*source table in the source mart or a sam*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.TableBASE ToTable ON ToTable.TableID=b.DestinationEntityID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.DataMartBASE FromDataMart ON FromDataMart.DataMartID = FromTable.DataMartID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ConnectionBASE c ON c.ConnectionID = FromTable.SourceConnectionID
	   /* this is for individual tables in a batch*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionTableBASE FromBatchTable ON FromBatchTable.TableID=FromTable.TableID
        LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatch ON FromBatch.BatchDefinitionID=FromBatchTable.BatchDefinitionID
        /* for all tables and connections*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchAll ON FromBatchAll.DataMartID=FromTable.DataMartID and FromBatchAll.BatchLoadTypeCD='All' and FromBatchAll.SourceConnectionID is null
        /* for all tables and a selected connection*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE destb on FromTable.TableID=destb.DestinationEntityID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchAllSpecificConnection ON FromBatchAllSpecificConnection.DataMartID=FromTable.DataMartID and FromBatchAllSpecificConnection.BatchLoadTypeCD='All' and FromBatchAllSpecificConnection.SourceConnectionID = destb.SourceConnectionID
        /*for specific load type*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE FromBatchByLoadType ON FromBatchByLoadType.DataMartID=FromTable.DataMartID and  FromBatchByLoadType.BatchLoadTypeCD =FromTable.LoadTypeCD 
 	   /* this is for individual tables in a batch for down stream tables*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionTableBASE ToBatchTable ON ToBatchTable.TableID=ToTable.TableID
        LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatch ON ToBatch.BatchDefinitionID=ToBatchTable.BatchDefinitionID
        
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchAll ON ToBatchAll.DataMartID=ToTable.DataMartID and ToBatchAll.BatchLoadTypeCD='All' and ToBatchAll.SourceConnectionID is null 
        /* for all tables and a selected connection*/
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.BindingBASE ToDestB on ToTable.TableID=ToDestB.DestinationEntityID
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchAllSpecificConnection ON ToBatchAllSpecificConnection.DataMartID=ToTable.DataMartID and ToBatchAllSpecificConnection.BatchLoadTypeCD='All' and ToBatchAllSpecificConnection.SourceConnectionID = ToDestB.SourceConnectionID
       
	   LEFT OUTER JOIN EDWAdmin.CatalystAdmin.ETLBatchDefinitionBASE ToBatchByLoadType ON ToBatchByLoadType.DataMartID=ToTable.DataMartID and ToBatchByLoadType.BatchLoadTypeCD='All' and ToBatchByLoadType.BatchLoadTypeCD=ToTable.LoadTypeCD 
WHERE  (b.SourceConnectionID<>destb.SourceConnectionID )/*Exclude binding dependencies from same SAM*/
	   AND
	     b.BindingStatusCD = 'Active' 
         ORDER BY DATEPART(hh, COALESCE(FromBatch.LastRunDTS,FromBatchAll.LastRunDTS,FromBatchByLoadType.LastRunDTS,FromBatchAllSpecificConnection.LastRunDTS))	
			 