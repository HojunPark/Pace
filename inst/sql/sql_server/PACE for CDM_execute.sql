--Variable Setting--
----Target laboratory test
IF OBJECT_ID('tempdb..#observation_concept_id', 'U') IS NOT NULL
	DROP TABLE #observation_concept_id;
create table #observation_concept_id (observation_concept_id varchar(10))
insert into #observation_concept_id values ('@labtest_id') --Potassium serum/plasma

----Setting cutoff value to define the event
IF OBJECT_ID('tempdb..#event_cutoff', 'U') IS NOT NULL
	DROP TABLE #event_cutoff;
create table #event_cutoff (cutoff float)
insert into #event_cutoff values (@cutoff_value) 

----Tafget drug
IF OBJECT_ID('tempdb..#DRUG_CONCEPT_ID', 'U') IS NOT NULL
	DROP TABLE #DRUG_CONCEPT_ID;
create table #DRUG_CONCEPT_ID (DRUG_CONCEPT_ID varchar(10))
insert into #DRUG_CONCEPT_ID values ('@drug_id') --Calcium polystyrene sulfonate product


--Analysis Start--
----Extracting laboratory test results
IF OBJECT_ID('tempdb..#Target_Lab', 'U') IS NOT NULL
	DROP TABLE #Target_Lab;
select * into #Target_Lab from 
(select person_id, observation_date, observation_time, UNIT_CONCEPT_ID, VALUE_AS_NUMBER, RANGE_LOW, RANGE_HIGH
from @cdm_database.[OBSERVATION] 
where observation_concept_id in (select * from #observation_concept_id)
and isnumeric(VALUE_AS_NUMBER)=1
)v

----Extracting patients who ever had abnormal results on target lab
IF OBJECT_ID('tempdb..#Abnormal_pt_list', 'U') IS NOT NULL
	DROP TABLE #Abnormal_pt_list;
Select * into #Abnormal_pt_list from 
(Select distinct person_id 
from #Target_Lab
where VALUE_AS_NUMBER>(select * from #event_cutoff))v 
--If lowering than lower reference range is event, you should change '>RANGE_HIGH' into '<RANGE_LOW'

----All target lab results of patients who ever had abnormal results
IF OBJECT_ID('tempdb..#Ever_event', 'U') IS NOT NULL
	DROP TABLE #Ever_event;
Select * into #Ever_event from 
(select * 
From #Target_Lab
where person_id in (select person_id from #Abnormal_pt_list))v

----Selecting inpatient data
IF OBJECT_ID('tempdb..#inpat_visit', 'U') IS NOT NULL
	DROP TABLE #inpat_visit;
select * into #inpat_visit from @cdm_database.[VISIT_OCCURRENCE] where person_id in (select distinct person_id from #Ever_event) and PLACE_OF_SERVICE_CONCEPT_ID='9201' --inpatient

IF OBJECT_ID('tempdb..#Target_lab_with_hosp', 'U') IS NOT NULL
	DROP TABLE #Target_lab_with_hosp;
select A.*, B.VISIT_START_DATE, B.VISIT_END_DATE into #Target_lab_with_hosp 
from #Target_Lab A, #inpat_visit B where a.PERSON_ID=b.PERSON_ID and a.OBSERVATION_DATE between b.VISIT_START_DATE and b.VISIT_END_DATE


----Making indentifier on every admission (hospitalization)
alter table #Target_lab_with_hosp add ID varchar(30)
update #Target_lab_with_hosp set ID=cast(person_id as varchar(10))+cast(VISIT_START_DATE as varchar(20))

----Extracting patients whose the first lab in the admission was within reference range
IF OBJECT_ID('tempdb..#subj', 'U') IS NOT NULL
	DROP TABLE #subj;
select * into #subj from (
select ID from #Target_lab_with_hosp a 
where a.OBSERVATION_DATE=(select min(OBSERVATION_DATE) from #Target_lab_with_hosp where PERSON_ID=a.PERSON_ID) 
and VALUE_AS_NUMBER>=range_low and VALUE_AS_NUMBER<=range_high)v

IF OBJECT_ID('tempdb..#Target_lab_with_hosp_init_normal', 'U') IS NOT NULL
	DROP TABLE #Target_lab_with_hosp_init_normal;
select * into #Target_lab_with_hosp_init_normal from (
select * from #Target_lab_with_hosp where ID in (select ID from #subj) 
and OBSERVATION_DATE between dateadd(day, 4, VISIT_START_DATE) and dateadd(day, -1, VISIT_END_DATE)
)v

----Extracting target event during admission
IF OBJECT_ID('tempdb..#event', 'U') IS NOT NULL
	DROP TABLE #event;
select * into #event 
from (
select * from #Target_lab_with_hosp_init_normal
where cast(VALUE_AS_NUMBER as float)>(select * from #event_cutoff))v 
--setting the event 

----Extracting target drug exposure information
IF OBJECT_ID('tempdb..#Target_Drug', 'U') IS NOT NULL
	DROP TABLE #Target_Drug;
select * into #Target_Drug from 
	(select * from @cdm_database.[DRUG_EXPOSURE] 
		where person_id in (select distinct person_id from #event) and DRUG_CONCEPT_ID in ('19112563'))v --Calcium polystyrene sulfonate product


----Calculating prescription change index
IF OBJECT_ID('tempdb..#PCI', 'U') IS NOT NULL
	DROP TABLE #PCI;
create table #PCI (B1 int, B2 int, A1 int, A2 int)

insert into #PCI (B1)
select count(*) as cnt from 
	(select distinct * from #Target_lab_with_hosp_init_normal where datediff(day, VISIT_START_DATE, OBSERVATION_DATE)>=4) A 
		inner join 
	(select distinct * from #Target_Drug) B 
	on a.person_id = b.person_id 
	where  datediff(day, a.OBSERVATION_DATE, b.DRUG_EXPOSURE_START_DATE) =-3;

insert into #PCI (B2)
select count(*) as cnt from 
	(select distinct * from #Target_lab_with_hosp_init_normal where datediff(day, VISIT_START_DATE, OBSERVATION_DATE)>=4) A 
		inner join 
	(select distinct * from #Target_Drug) B 
	on a.person_id = b.person_id 
	where  datediff(day, a.OBSERVATION_DATE, b.DRUG_EXPOSURE_START_DATE) =-2;

insert into #PCI (A1)
select count(*) as cnt from 
	(select distinct * from #Target_lab_with_hosp_init_normal where datediff(day, VISIT_START_DATE, OBSERVATION_DATE)>=4) A 
		inner join 
	(select distinct * from #Target_Drug) B 
	on a.person_id = b.person_id 
	where  datediff(day, a.OBSERVATION_DATE, b.DRUG_EXPOSURE_START_DATE) =0;

insert into #PCI (A2)
select count(*) as cnt from 
	(select distinct * from #Target_lab_with_hosp_init_normal where datediff(day, VISIT_START_DATE, OBSERVATION_DATE)>=4) A 
		inner join 
	(select distinct * from #Target_Drug) B 
	on a.person_id = b.person_id 
	where  datediff(day, a.OBSERVATION_DATE, b.DRUG_EXPOSURE_START_DATE) =1;
