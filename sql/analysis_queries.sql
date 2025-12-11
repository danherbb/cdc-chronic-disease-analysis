CREATE TABLE cdi AS SELECT * FROM read_csv('data/raw/cdi.csv');

CREATE VIEW us_states AS 
SELECT DISTINCT LocationDesc as states
FROM cdi
WHERE LocationDesc NOT IN ('Puerto Rico', 'Guam', 'Virgin Islands', 'United States');

/*
Chapter 1 - State Level Burden of Obesity and Diabetes
    - see which states have highest obesity prevalence (age-adjusted)
    - same for diabetes prevalence
    - compare rankings between obesity and diabetes

    visuals:
    - map for obesity and diabetes side by side
    - bar chart for top/bottom, obesity/diabetes (maybe 2x2 charts?)
    - will contain filter for year so can include year as dimension
*/

CREATE VIEW adult_obesity_ovr AS
SELECT LocationDesc, YearEnd, DataValue as prevalence
FROM cdi
WHERE QuestionID = 'NPW14' AND StratificationID1 = 'OVR' AND DataValueTypeID = 'AGEADJPREV';

CREATE VIEW adult_diabetes_ovr AS
SELECT LocationDesc, YearEnd, DataValue AS prevalence
FROM cdi
WHERE QuestionID = 'DIA01' AND StratificationID1 = 'OVR' AND DataValueTypeID = 'AGEADJPREV';

COPY (
    WITH ob AS (
        SELECT LocationDesc AS state, YearEnd AS year, prevalence
        FROM adult_obesity_ovr
        WHERE LocationDesc IN (SELECT states FROM us_states)
    ),
    di AS (
        SELECT LocationDesc AS state, YearEnd AS year, prevalence
        FROM adult_diabetes_ovr
        WHERE LocationDesc IN (SELECT states FROM us_states)
    )
    SELECT ob.state, ob.year, ob.prevalence AS obesity, di.prevalence AS diabetes
    FROM ob INNER JOIN di ON ob.state = di.state AND ob.year = di.year
) TO 'data/processed/state_obesity_diabetes.csv';


/*
Chapter 2 - Sex Differences in Obesity and Diabetes
    - do males or females have higher obesity prevalence WITHIN each state (age adjusted)
    - does diabetes prevalence follow similar sex differences

    visuals:
    - map where color shows disparity for each state (both diabetes and obesity)
    - ranking of disparities
    - dual bar chart (for whole united states)

    notes:
    - also can filter by year
    - disparities can be done with calculated field in tableau
*/

CREATE VIEW adult_obesity_by_sex AS
SELECT LocationDesc, YearEnd, Stratification1 AS sex, DataValue AS prevalence
FROM cdi
WHERE QuestionID = 'NPW14' AND StratificationCategory1 = 'Sex' AND DataValueTypeID = 'AGEADJPREV';

CREATE VIEW adult_diabetes_by_sex AS
SELECT LocationDesc, YearEnd, Stratification1 AS sex, DataValue AS prevalence
FROM cdi
WHERE QuestionID = 'DIA01' AND StratificationCategory1 = 'Sex' AND DataValueTypeID = 'AGEADJPREV';

CREATE VIEW ob_di_by_sex AS
WITH ob_m AS (
    SELECT LocationDesc AS state, YearEnd AS year, prevalence
    FROM adult_obesity_by_sex
    WHERE sex = 'Male'
),
ob_f AS (
    SELECT LocationDesc AS state, YearEnd AS year, prevalence
    FROM adult_obesity_by_sex
    WHERE sex = 'Female'
),
di_m AS (
    SELECT LocationDesc AS state, YearEnd AS year, prevalence
    FROM adult_diabetes_by_sex
    WHERE sex = 'Male'
),
di_f AS (
    SELECT LocationDesc AS state, YearEnd AS year, prevalence
    FROM adult_diabetes_by_sex
    WHERE sex = 'Female'
)
SELECT
    ob_m.state, ob_m.year,
    ob_m.prevalence AS male_obesity, ob_f.prevalence AS female_obesity,
    di_m.prevalence AS male_diabetes, di_f.prevalence AS female_diabetes
FROM
    ob_m INNER JOIN ob_f ON ob_m.state = ob_f.state AND ob_m.year = ob_f.year
    INNER JOIN di_m ON ob_m.state = di_m.state AND ob_m.year = di_m.year
    INNER JOIN di_f ON ob_m.state = di_f.state AND ob_m.year = di_f.year;


COPY (
    SELECT * FROM ob_di_by_sex WHERE state IN (SELECT states FROM us_states)
) TO 'data/processed/state_ob_di_by_sex.csv';

-- COPY (
--     (
--         SELECT YearEnd AS year, 'obesity' AS indicator, sex, prevalence
--         FROM adult_obesity_by_sex
--         WHERE LocationDesc = 'United States'
--     ) 
--     UNION 
--     (
--         SELECT YearEnd AS year, 'diabetes' AS indicator, sex, prevalence
--         FROM adult_diabetes_by_sex
--         WHERE LocationDesc = 'United States'
--     )
-- ) TO 'data/processed/natl_ob_di_by_sex.csv';

/*
Chapter 3 - Physical Activity as a Possible Explanatory Factor
    - which states have the lowest age-adjusted physical activity levels?
    - do those states also show higher obesity or diabetes prevalence?
    - physical activty for men compared to women at national level

    visuals:
    - physical activity vs. obesity prevalence scatterplot
    - same for physical activity vs. diabetes prevalence
    - dual bar chart for male, female physical activity
*/

COPY (
    SELECT LocationDesc AS state, YearEnd as year, DataValue AS prevalence
    FROM cdi
    WHERE 
        QuestionID = 'NPW06'
        AND StratificationID1 = 'OVR'
        AND DataValueTypeID = 'AGEADJPREV'
        AND LocationDesc IN (SELECT states FROM us_states)
) TO 'data/processed/state_no_pa.csv';

COPY (
    (
        SELECT YearEnd AS year, 'no physical activity' AS indicator, Stratification1 AS sex, DataValue AS prevalence
        FROM cdi
        WHERE
            LocationDesc = 'United States'
            AND QuestionID = 'NPW06'
            AND StratificationCategory1 = 'Sex'
            AND DataValueTypeID = 'AGEADJPREV'
    )
    UNION
    (
        SELECT YearEnd AS year, 'obesity' AS indicator, sex, prevalence
        FROM adult_obesity_by_sex
        WHERE LocationDesc = 'United States'
    ) 
    UNION 
    (
        SELECT YearEnd AS year, 'diabetes' AS indicator, sex, prevalence
        FROM adult_diabetes_by_sex
        WHERE LocationDesc = 'United States'
    )
) TO 'data/processed/natl_indicators_by_sex.csv';
