runPace<-function(connectionDetails, drug_id=NA, labtest_id=NA, cutoff_value=NA){
  conn<-DatabaseConnector::connect(connectionDetails)
  
  if(is.na(drug_id)){
    drug_id<-19112563 #Calcium polystyrene sulfonate product
  }
  if(is.na(labtest_id)){
    labtest_id<-3023103 #Potassium serum/plasma
  }
  if(is.na(cutoff_value)){
    cutoff_value<-0.6
  }
  
  renderedSql<-SqlRender::loadRenderTranslateSql("PACE for CDM_execute.sql",
                                                 packageName="Pace",
                                                 dbms=connectionDetails$dbms,
                                                 target_database=connectionDetails$target_database,
                                                 cdm_database=connectionDetails$cdm_database,
                                                 drug_id=drug_id,
                                                 labtest_id=labtest_id,
                                                 cutoff_value=cutoff_value)
  
  DatabaseConnector::executeSql(conn, renderedSql)
  
  renderedSql<-SqlRender::loadRenderTranslateSql("PACE for CDM_query.sql",
                                                 packageName="Pace",
                                                 dbms=connectionDetails$dbms)
  results<-DatabaseConnector::querySql(conn, renderedSql)
  
  dbDisconnect(conn)
  results
}