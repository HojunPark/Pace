# Pace
[Under development] R package for running the Prescription pattern Around Clinical Event (PACE) algorithm.

Getting Started
===============
```r
install.packages("devtools")
library(devtools)
install_github("ohdsi/SqlRender", args="--no-multiarch")
install_github("ohdsi/DatabaseConnector", args="--no-multiarch")
install_github("ohdsi/Pace", args="--no-multiarch")

library(SqlRender)
library(DatabaseConnector)
library(Pace)
connectionDetails<-DatabaseConnector::createConnectionDetails(dbms="sql server",
                                                              server="IP",
                                                              port="PORT",
                                                              schema="SCHEMA",
                                                              user="ID",
                                                              password="PW")
connectionDetails$target_database<-"TARGET_DATABASE_NAME"
connectionDetails$cdm_database<-"CDM_DATABASE_NAME"

drug_id<-19112563
labtest_id<-3023103

results<-runPace(connectionDetails, drug_id=drug_id, labtest_id=labtest_id, cutoff_value=6.0)
results
```
