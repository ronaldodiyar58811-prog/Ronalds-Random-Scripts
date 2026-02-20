
SELECT  DISTINCT 
		FromDataMart.DataMartNM as FromDataMartNM
		,CASE WHEN FromDataMart.DataMartTypeDSC<>'IDEA' THEN COALESCE(FromBatch.BatchDefinitionNM,FromBatchAll.BatchDefinitionNM,FromBatchByLoadType.BatchDefinitionNM,FromBatchAllSpecificConnection.BatchDefinitionNM,'No Batch is created')
			      ELSE 'IDEA Source - Batch is not needed'  END AS FromDataMartBatchName
	     , fromtable.SchemaNM+'.'+ FromTable.TableNM as SourceTableNM
		,ToDataMart.DataMartNM AS ToDataMartNM
	     , ToTable.SchemaNM +','+ToTable.TableNM as DestinationTableNM
		,CASE WHEN ToDataMart.DataMartTypeDSC<>'IDEA' THEN COALESCE(ToBatch.BatchDefinitionNM,ToBatchAll.BatchDefinitionNM,ToBatchByLoadType.BatchDefinitionNM,ToBatchAllSpecificConnection.BatchDefinitionNM,'No Batch is created')
			      ELSE 'IDEA Source - Batch is not needed'  END  AS ToDataMartBatchName
	
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
WHERE  ToDataMart.DataMartID <> FromTable.DataMartID /*Exclude table dependencies from same SAM*/
	   AND
	     b.BindingStatusCD = 'Active' --AND D.DataMartTypeDSC<>'IDEA' AND TD.DataMartTypeDSC<>'IDEA'
	AND ((COALESCE(FromBatch.BatchDefinitionNM,FromBatchAll.BatchDefinitionNM,FromBatchByLoadType.BatchDefinitionNM,FromBatchAllSpecificConnection.BatchDefinitionNM) is null and FromDataMart.DataMartTypeDSC<>'IDEA') 
	or (COALESCE(ToBatch.BatchDefinitionNM,ToBatchAll.BatchDefinitionNM,ToBatchByLoadType.BatchDefinitionNM,ToBatchAllSpecificConnection.BatchDefinitionNM) is null and ToDataMart.DataMartTypeDSC<>'IDEA' ))