CREATE TABLE cdi AS SELECT * FROM read_csv('data/raw/cdi.csv');

-- locations include territories and national level so get just states+dc
.maxrows 60
SELECT DISTINCT LocationDesc FROM cdi;

CREATE VIEW us_states AS 
SELECT DISTINCT LocationDesc as states
FROM cdi
WHERE LocationDesc NOT IN ('Puerto Rico', 'Guam', 'Virgin Islands', 'United States');
-- DC isn't technically a state but hey i'm just a man, leave me alone
SELECT * FROM us_states;


-- Basic Counts:

-- 1. How many total records are in the dataset?
SELECT COUNT(*) FROM cdi;

-- 2. How many indicators (questions) are there per topic?
SELECT Topic, TopicID, COUNT(DISTINCT Question) AS num_indicators
FROM cdi
GROUP BY Topic, TopicID
ORDER BY num_indicators DESC;


-- State-Level Health Comparisons

-- 3. Which states have the highest and lowest values for obesity prevalence?

-- First find relevant question
SELECT DISTINCT Question, QuestionID FROM cdi WHERE TopicID = 'NPAW';
-- Time intervals the data was collected
SELECT YearStart, YearEnd, COUNT(1) AS num
FROM cdi
WHERE QuestionID = 'NPW14'
GROUP BY YearStart, YearEnd
ORDER BY YearStart, YearEnd; -- 2019-2022, all collected over one year
-- Determine which stratification to use
SELECT Stratification1, StratificationID1, COUNT(1) AS num
FROM cdi
WHERE QuestionID = 'NPW14'
GROUP BY Stratification1, StratificationID1;

-- Use age adjusted prevalence to control for different age distributions across states
CREATE VIEW adult_obesity AS
SELECT LocationDesc, YearEnd, DataValue AS age_adj_prevalence
FROM cdi
WHERE QuestionID = 'NPW14' AND StratificationID1 = 'OVR' AND DataValueTypeID = 'AGEADJPREV';


SELECT LocationDesc AS state, age_adj_prevalence
FROM adult_obesity
WHERE YearEnd = 2022 AND LocationDesc IN (SELECT states FROM us_states)
ORDER BY age_adj_prevalence DESC;


-- 4. Which states have the highest diabetes prevalence?

-- find relevant question
SELECT DISTINCT Question, QuestionID FROM cdi WHERE TopicID = 'DIA';
-- time intervals for relevant data
SELECT YearStart, YearEnd, COUNT(1) AS num
FROM cdi
WHERE QuestionID = 'DIA01'
GROUP BY YearStart, YearEnd
ORDER BY YearStart, YearEnd; -- 2019-2022, all collected over one year

CREATE VIEW adult_diabetes AS
SELECT LocationDesc, YearEnd, DataValue AS age_adj_prevalence
FROM cdi
WHERE QuestionID = 'DIA01' AND StratificationID1 = 'OVR' AND DataValueTypeID = 'AGEADJPREV';

SELECT LocationDesc AS state, age_adj_prevalence
FROM adult_diabetes
WHERE YearEnd = 2022 AND LocationDesc IN (SELECT states FROM us_states)
ORDER BY age_adj_prevalence DESC;


-- 5. Which states have the highest cancer screening compliance?
-- find relevant questions
SELECT Question, QuestionID, COUNT(1)
FROM cdi
WHERE TopicID = 'CAN'
GROUP BY Question, QuestionID
ORDER BY QuestionID; -- CAN06: colorectal screening, CAN09: mammography use, CAN10: cervical screening

CREATE VIEW screen_compliance AS
SELECT YearStart, YearEnd, LocationDesc AS state, DataValue AS compliance, QuestionID
FROM cdi
WHERE QuestionID IN ('CAN06', 'CAN09', 'CAN10')
    AND StratificationID1 = 'OVR'
    AND DataValueTypeID = 'AGEADJPREV'
    AND LocationDesc IN (SELECT states FROM us_states);

SELECT * FROM screen_compliance ORDER BY YearStart, YearEnd, state, QuestionID;

-- find time interval data was taken
SELECT YearStart, YearEnd, QuestionID, COUNT(1)
FROM screen_compliance
GROUP BY YearStart, YearEnd, QuestionID
ORDER BY YearStart, YearEnd, QuestionID; -- 6 and 9 have 2020 and 2022, 10 only has 2020

WITH col AS (
    SELECT state, compliance AS colorectal
    FROM screen_compliance
    WHERE QuestionID = 'CAN06' AND YearEnd = 2020
),
mam AS (
    SELECT state, compliance AS mammography
    FROM screen_compliance
    WHERE QuestionID = 'CAN09' AND YearEnd = 2020 
),
cer AS (
    SELECT state, compliance AS cervical
    FROM screen_compliance
    WHERE QuestionID = 'CAN10' AND YearEnd = 2020   
)
SELECT col.state, colorectal, mammography, cervical
FROM col INNER JOIN mam ON col.state = mam.state
    INNER JOIN cer ON col.state = cer.state
ORDER BY col.colorectal DESC;



-- Trends Over Time

-- 6. How have obesity rates changed from 2019 to 2022 at the national level?
SELECT YearEnd, DataValue
FROM cdi
WHERE LocationDesc = 'United States' AND QuestionID = 'NPW14'
    AND DataValueTypeID = 'AGEADJPREV' AND StratificationID1 = 'OVR';

-- 7. Which states show the greatest increase in diabetes prevalence?
WITH latest AS (SELECT LocationDesc, age_adj_prevalence FROM adult_diabetes WHERE YearEnd = 2022),
oldest AS (SELECT LocationDesc, age_adj_prevalence FROM adult_diabetes WHERE YearEnd = 2019)
SELECT latest.LocationDesc, ROUND(latest.age_adj_prevalence - oldest.age_adj_prevalence, 3) AS change_in_diabetes_prev
FROM latest INNER JOIN oldest ON latest.LocationDesc = oldest.LocationDesc
WHERE latest.LocationDesc IN (SELECT states FROM us_states)
ORDER BY change_in_diabetes_prev DESC;

-- 8. What is the average prevalence of obesity by sex (male vs. female)?
CREATE VIEW adult_obesity_by_sex AS
SELECT YearEnd, LocationDesc AS state, Stratification1 AS sex, DataValue AS age_adj_prevalence
FROM cdi
WHERE QuestionID = 'NPW14' AND DataValueTypeID = 'AGEADJPREV'
    AND StratificationCategory1 ='Sex' AND LocationDesc IN (SELECT states FROM us_states);

-- latest average (2022) unweighted across states
SELECT sex, AVG(age_adj_prevalence)
FROM adult_obesity_by_sex
WHERE YearEnd = 2022
GROUP BY sex;


-- 9. Which racial/ethnic groups report the highest asthma prevalence?

-- find relevant asthma question
SELECT Question, QuestionID, COUNT(1)
FROM cdi
WHERE TopicID = 'AST'
Group By QuestionID, Question;

-- find time interval data was taking
SELECT YearStart, YearEnd, COUNT(1)
FROM cdi
WHERE QuestionID = 'AST02' AND StratificationCategoryID1 = 'RACE'
GROUP BY YearStart, YearEnd
ORDER BY YearStart, YearEnd; -- 2019-2022 all the same year


CREATE VIEW adult_asthma_by_race AS
SELECT LocationDesc, YearEnd, Stratification1 as RACE, DataValue AS age_adj_prevalence
FROM cdi
WHERE QuestionID = 'AST02' AND StratificationCategoryID1 = 'RACE' AND DataValueTypeID = 'AGEADJPREV';

SELECT race, age_adj_prevalence
FROM adult_asthma_by_race
WHERE LocationDesc = 'United States' AND YearEnd = (SELECT MAX(YearEnd) FROM adult_asthma_by_race)
ORDER BY age_adj_prevalence DESC;
 


-- 11. Which states have the lowest physical activity levels?

-- find relevant questions
.maxrows 120
SELECT Question, QuestionID, COUNT(1)
FROM cdi
GROUP BY Question, QuestionID
ORDER BY QuestionID;
-- NPW09: met aerobic physical activity guidelines
-- NPW06: no leisure-time physical activity

-- check time interval data was taken in
SELECT QuestionID, YearStart, YearEnd, COUNT(1)
FROM cdi
WHERE QuestionID IN ('NPW06', 'NPW09')
GROUP BY QuestionID, YearStart, YearEnd
ORDER BY QuestionID, YearStart, YearEnd;
/*
NPW06 (no activity) has data for 2019-2022 while NPW09 (met guidelines) 
has only for 2022 so we'll use NPW06
*/

