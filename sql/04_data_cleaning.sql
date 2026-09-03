USE world_bank_project;

-- Create a copy of the raw data
CREATE TABLE cleaned_world_bank_data AS
SELECT *
FROM raw_world_bank_data;

SELECT COUNT(*) AS total_rows
FROM cleaned_world_bank_data;

-- Remove extra spaces in the data
UPDATE cleaned_world_bank_data
SET
    country_name = TRIM(country_name),
    country_code = TRIM(country_code),
    region = TRIM(region),
    income_group = TRIM(income_group);
    
-- Fix the wrong data compared to the reference data
UPDATE cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_code = r.country_code
SET
    c.country_name = r.country_name,
    c.region = r.region,
    c.income_group = r.income_group;

-- Fix the incorrect country codes with the reference data
SELECT
    c.country_name,
    c.country_code AS incorrect_code,
    r.country_code AS correct_code
FROM cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_name = r.country_name
WHERE c.country_code <> r.country_code;

-- Fixing the incorrect country codes
UPDATE cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_name = r.country_name
SET c.country_code = r.country_code
WHERE c.country_code <> r.country_code;

-- Checking that the updates worked from dirty to clean
SELECT DISTINCT
    c.country_name,
    c.country_code
FROM cleaned_world_bank_data c
LEFT JOIN country_reference r
    ON c.country_code = r.country_code
WHERE r.country_code IS NULL;

-- Verify the countries that appeared from the reference data
SELECT *
FROM country_reference
WHERE country_name IN (
    'Iran',
    'European Union',
    'Australia',
    'South Africa',
    'World'
);

-- Fix the country code for South Africa and Australia
UPDATE cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_name = r.country_name
SET c.country_code = r.country_code
WHERE c.country_code <> r.country_code; 

-- Standardise country names using the corrected country codes

SET SQL_SAFE_UPDATES = 0;

UPDATE cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_code = r.country_code
SET c.country_name = r.country_name
WHERE c.country_name <> r.country_name;

SET SQL_SAFE_UPDATES = 1;

-- Verify country names match the reference table
SELECT DISTINCT
    c.country_name AS cleaned_country_name,
    c.country_code,
    r.country_name AS expected_country_name
FROM cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_code = r.country_code
WHERE c.country_name <> r.country_name;

-- Checking for the duplicate values in the cleaned table
SELECT
    country_name,
    year,
    COUNT(*) AS duplicate_count
FROM cleaned_world_bank_data
GROUP BY country_name, year
HAVING COUNT(*) > 1;

-- Determine if the data is exact duplicate or conflicting duplicate
SELECT *
FROM cleaned_world_bank_data
WHERE (country_name = 'Australia' AND year = '2000')
   OR (country_name = 'Korea, Rep.' AND year = '2000')
   OR (country_name = 'Vietnam' AND year = '2013')
   OR (country_name = 'India' AND year = '2011')
ORDER BY country_name, year;

-- Duplicate cleaning notes:
-- Australia 2000: exact duplicate
-- India 2011: exact duplicate
-- Korea, Rep. 2000: conflicting duplicate (life_expectancy)
-- Vietnam 2013: conflicting duplicate (life_expectancy)
--
-- Exact duplicates can be safely deduplicated.
-- Conflicting duplicates require further investigation before correction.


-- Inspect rows containing missing values

SELECT *
FROM cleaned_world_bank_data
WHERE country_name IS NULL OR TRIM(country_name) = ''
   OR country_code IS NULL OR TRIM(country_code) = ''
   OR region IS NULL OR TRIM(region) = ''
   OR income_group IS NULL OR TRIM(income_group) = ''
   OR year IS NULL OR TRIM(year) = ''
   OR gdp_usd IS NULL OR TRIM(gdp_usd) = ''
   OR population IS NULL OR TRIM(population) = ''
   OR life_expectancy IS NULL OR TRIM(life_expectancy) = ''
   OR unemployment_rate IS NULL OR TRIM(unemployment_rate) = ''
   OR co2_emissions_per_capita IS NULL OR TRIM(co2_emissions_per_capita) = ''
   OR access_to_electricity_pct IS NULL OR TRIM(access_to_electricity_pct) = '';
   
-- Missing value findings:
-- Kenya: multiple fields are missing.
-- China: unemployment_rate is missing.
-- Nigeria: gdp_usd is missing.
-- Türkiye: population is missing.
--
-- Missing values will not automatically be replaced with 0 or estimated.
-- Records will be retained or quarantined based on whether they can be reliably used in final analysis

-- Kenya missing values

SELECT *
FROM cleaned_world_bank_data
WHERE country_name = 'Kenya'
  AND (
       country_code IS NULL OR TRIM(country_code) = ''
       OR region IS NULL OR TRIM(region) = ''
       OR income_group IS NULL OR TRIM(income_group) = ''
       OR year IS NULL OR TRIM(year) = ''
       OR gdp_usd IS NULL OR TRIM(gdp_usd) = ''
       OR population IS NULL OR TRIM(population) = ''
       OR life_expectancy IS NULL OR TRIM(life_expectancy) = ''
       OR unemployment_rate IS NULL OR TRIM(unemployment_rate) = ''
       OR co2_emissions_per_capita IS NULL OR TRIM(co2_emissions_per_capita) = ''
       OR access_to_electricity_pct IS NULL OR TRIM(access_to_electricity_pct) = ''
  );

-- Kenya record contains extensive missing data:
-- region, income_group, GDP, population, life expectancy,
-- unemployment rate, CO2 emissions and electricity access.
-- The record cannot provide meaningful analysis.
-- Marked for quarantine rather than estimating missing values.


--
-- INVALID VALUES
--

-- Check negative GDP
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(gdp_usd AS DECIMAL(30,2)) < 0;

-- Check negative population
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(population AS DECIMAL(30,2)) < 0;

-- Check unrealistic life expectancy
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(life_expectancy AS DECIMAL(10,2)) < 0
   OR CAST(life_expectancy AS DECIMAL(10,2)) > 120;

-- Check invalid unemployment rates
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(unemployment_rate AS DECIMAL(10,2)) < 0
   OR CAST(unemployment_rate AS DECIMAL(10,2)) > 100;

-- Check negative CO2 emissions
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(co2_emissions_per_capita AS DECIMAL(10,2)) < 0;

-- Check invalid electricity access
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(access_to_electricity_pct AS DECIMAL(10,2)) < 0
   OR CAST(access_to_electricity_pct AS DECIMAL(10,2)) > 100;
   

-- Replace confirmed impossible values with NULL

UPDATE cleaned_world_bank_data
SET life_expectancy = NULL
WHERE CAST(life_expectancy AS DECIMAL(10,2)) > 120
   OR CAST(life_expectancy AS DECIMAL(10,2)) < 0;

UPDATE cleaned_world_bank_data
SET unemployment_rate = NULL
WHERE CAST(unemployment_rate AS DECIMAL(10,2)) > 100
   OR CAST(unemployment_rate AS DECIMAL(10,2)) < 0;

UPDATE cleaned_world_bank_data
SET co2_emissions_per_capita = NULL
WHERE CAST(co2_emissions_per_capita AS DECIMAL(10,2)) < 0;

UPDATE cleaned_world_bank_data
SET access_to_electricity_pct = NULL
WHERE CAST(access_to_electricity_pct AS DECIMAL(10,2)) > 100
   OR CAST(access_to_electricity_pct AS DECIMAL(10,2)) < 0;
   
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(access_to_electricity_pct AS DECIMAL(10,2)) < 0
   OR CAST(access_to_electricity_pct AS DECIMAL(10,2)) > 100;

-- The value was not updated to NULL for United Kingdom with unemployment rate
SET SQL_SAFE_UPDATES = 0;

UPDATE cleaned_world_bank_data
SET unemployment_rate = NULL
WHERE country_name = 'United Kingdom'
  AND year = '2005'
  AND unemployment_rate = '652.0';

SELECT country_name, year, unemployment_rate
FROM cleaned_world_bank_data
WHERE country_name = 'United Kingdom'
  AND year = '2005';

SET SQL_SAFE_UPDATES = 1;

-- More values were not set to NULL after update so we fixed it
-- We use country codes now so it matches the reference data

SET SQL_SAFE_UPDATES = 0;

-- Egypt: invalid life expectancy
UPDATE cleaned_world_bank_data
SET life_expectancy = NULL
WHERE country_code = 'EGY'
  AND year = '2010'
  AND life_expectancy = '187.4';

-- South Africa: invalid CO2 emissions
UPDATE cleaned_world_bank_data
SET co2_emissions_per_capita = NULL
WHERE country_code = 'ZAF'
  AND year = '2023'
  AND co2_emissions_per_capita = '-6.5';

-- Egypt: invalid electricity access
UPDATE cleaned_world_bank_data
SET access_to_electricity_pct = NULL
WHERE country_code = 'EGY'
  AND year = '2011'
  AND access_to_electricity_pct = '101.02';

SET SQL_SAFE_UPDATES = 1;

-- Verify for the NULL value UPDATE

WITH missing_values AS (

    SELECT country_name, year, 'region' AS column_name
    FROM cleaned_world_bank_data
    WHERE region IS NULL OR TRIM(region) = ''

    UNION ALL

    SELECT country_name, year, 'income_group'
    FROM cleaned_world_bank_data
    WHERE income_group IS NULL OR TRIM(income_group) = ''

    UNION ALL

    SELECT country_name, year, 'gdp_usd'
    FROM cleaned_world_bank_data
    WHERE gdp_usd IS NULL OR TRIM(gdp_usd) = ''

    UNION ALL

    SELECT country_name, year, 'population'
    FROM cleaned_world_bank_data
    WHERE population IS NULL OR TRIM(population) = ''

    UNION ALL

    SELECT country_name, year, 'life_expectancy'
    FROM cleaned_world_bank_data
    WHERE life_expectancy IS NULL OR TRIM(life_expectancy) = ''

    UNION ALL

    SELECT country_name, year, 'unemployment_rate'
    FROM cleaned_world_bank_data
    WHERE unemployment_rate IS NULL OR TRIM(unemployment_rate) = ''

    UNION ALL

    SELECT country_name, year, 'co2_emissions_per_capita'
    FROM cleaned_world_bank_data
    WHERE co2_emissions_per_capita IS NULL
       OR TRIM(co2_emissions_per_capita) = ''

    UNION ALL

    SELECT country_name, year, 'access_to_electricity_pct'
    FROM cleaned_world_bank_data
    WHERE access_to_electricity_pct IS NULL
       OR TRIM(access_to_electricity_pct) = ''
)

SELECT *
FROM missing_values
ORDER BY country_name, year, column_name;

-- 
-- CHECK FOR NON-NUMERIC VALUES AND THOSE IN THE WRONG FORMAT
--

-- GDP
SELECT DISTINCT
    country_name,
    year,
    gdp_usd
FROM cleaned_world_bank_data
WHERE gdp_usd IS NOT NULL
  AND TRIM(gdp_usd) <> ''
  AND (
       gdp_usd LIKE '%,%'
       OR gdp_usd LIKE '%$%'
       OR gdp_usd LIKE '%\%%'
       OR LOWER(TRIM(gdp_usd)) IN ('n/a', 'na', 'unknown', 'null', '..')
  );
  
-- Population
SELECT DISTINCT
    country_name,
    year,
    population
FROM cleaned_world_bank_data
WHERE population IS NOT NULL
  AND TRIM(population) <> ''
  AND (
       population LIKE '%,%'
       OR population LIKE '%$%'
       OR population LIKE '%\%%'
       OR LOWER(TRIM(population)) IN ('n/a', 'na', 'unknown', 'null', '..')
  );

-- Life Expectancy
SELECT DISTINCT
    country_name,
    year,
    life_expectancy
FROM cleaned_world_bank_data
WHERE life_expectancy IS NOT NULL
  AND TRIM(life_expectancy) <> ''
  AND (
       life_expectancy LIKE '%,%'
       OR life_expectancy LIKE '%$%'
       OR life_expectancy LIKE '%\%%'
       OR LOWER(TRIM(life_expectancy)) IN ('n/a', 'na', 'unknown', 'null', '..')
  );

-- Unemployment Rate
SELECT DISTINCT
    country_name,
    year,
    unemployment_rate
FROM cleaned_world_bank_data
WHERE unemployment_rate IS NOT NULL
  AND TRIM(unemployment_rate) <> ''
  AND (
       unemployment_rate LIKE '%,%'
       OR unemployment_rate LIKE '%$%'
       OR unemployment_rate LIKE '%\%%'
       OR LOWER(TRIM(unemployment_rate)) IN ('n/a', 'na', 'unknown', 'null', '..')
  );

-- CO2 Emissions Per Capita
SELECT DISTINCT
    country_name,
    year,
    co2_emissions_per_capita
FROM cleaned_world_bank_data
WHERE co2_emissions_per_capita IS NOT NULL
  AND TRIM(co2_emissions_per_capita) <> ''
  AND (
       co2_emissions_per_capita LIKE '%,%'
       OR co2_emissions_per_capita LIKE '%$%'
       OR co2_emissions_per_capita LIKE '%\%%'
       OR LOWER(TRIM(co2_emissions_per_capita)) IN ('n/a', 'na', 'unknown', 'null', '..')
  );

-- Access to Electricity
SELECT DISTINCT
    country_name,
    year,
    access_to_electricity_pct
FROM cleaned_world_bank_data
WHERE access_to_electricity_pct IS NOT NULL
  AND TRIM(access_to_electricity_pct) <> ''
  AND (
       access_to_electricity_pct LIKE '%,%'
       OR access_to_electricity_pct LIKE '%$%'
       OR access_to_electricity_pct LIKE '%\%%'
       OR LOWER(TRIM(access_to_electricity_pct)) IN ('n/a', 'na', 'unknown', 'null', '..')
  );
  
--
-- Clean and update the formatting errors
--

SET SQL_SAFE_UPDATES = 0;

-- Türkiye 2015: remove $ sign and commas from GDP
UPDATE cleaned_world_bank_data
SET gdp_usd = REPLACE(REPLACE(gdp_usd, '$', ''), ',', '')
WHERE country_name = 'Türkiye'
  AND year = '2015'
  AND gdp_usd = '$763,325,006,735';


-- Canada 2010: "unknown" is not a numeric value
UPDATE cleaned_world_bank_data
SET life_expectancy = NULL
WHERE country_name = 'Canada'
  AND year = '2010'
  AND LOWER(TRIM(life_expectancy)) = 'unknown';


-- India 2021: remove percentage sign
UPDATE cleaned_world_bank_data
SET unemployment_rate = REPLACE(unemployment_rate, '%', '')
WHERE country_name = 'India'
  AND year = '2021'
  AND unemployment_rate = '6.14%';


-- South Africa 2015: change decimal comma to decimal point
UPDATE cleaned_world_bank_data
SET co2_emissions_per_capita =
    REPLACE(co2_emissions_per_capita, ',', '.')
WHERE country_name = 'South Africa'
  AND year = '2015'
  AND co2_emissions_per_capita = '7,86';


-- Norway 2013: ".." represents a missing value
UPDATE cleaned_world_bank_data
SET access_to_electricity_pct = NULL
WHERE country_name = 'Norway'
  AND year = '2013'
  AND access_to_electricity_pct = '..';

SET SQL_SAFE_UPDATES = 1;

-- Make all the blank or empty values as NULL

SET SQL_SAFE_UPDATES = 0;

UPDATE cleaned_world_bank_data
SET
    country_name = NULLIF(TRIM(country_name), ''),
    country_code = NULLIF(TRIM(country_code), ''),
    region = NULLIF(TRIM(region), ''),
    income_group = NULLIF(TRIM(income_group), ''),
    year = NULLIF(TRIM(year), ''),
    gdp_usd = NULLIF(TRIM(gdp_usd), ''),
    population = NULLIF(TRIM(population), ''),
    life_expectancy = NULLIF(TRIM(life_expectancy), ''),
    unemployment_rate = NULLIF(TRIM(unemployment_rate), ''),
    co2_emissions_per_capita = NULLIF(TRIM(co2_emissions_per_capita), ''),
    access_to_electricity_pct = NULLIF(TRIM(access_to_electricity_pct), '');

SET SQL_SAFE_UPDATES = 1;

-- Verify the update
SELECT
    SUM(TRIM(country_name) = '') AS blank_country_name,
    SUM(TRIM(country_code) = '') AS blank_country_code,
    SUM(TRIM(region) = '') AS blank_region,
    SUM(TRIM(income_group) = '') AS blank_income_group,
    SUM(TRIM(year) = '') AS blank_year,
    SUM(TRIM(gdp_usd) = '') AS blank_gdp,
    SUM(TRIM(population) = '') AS blank_population,
    SUM(TRIM(life_expectancy) = '') AS blank_life_expectancy,
    SUM(TRIM(unemployment_rate) = '') AS blank_unemployment,
    SUM(TRIM(co2_emissions_per_capita) = '') AS blank_co2,
    SUM(TRIM(access_to_electricity_pct) = '') AS blank_electricity
FROM cleaned_world_bank_data;

--
-- Remove and handle duplicates (exact and conflicting duplicates)
--

SELECT
    country_name,
    year,
    COUNT(*) AS duplicate_count
FROM cleaned_world_bank_data
GROUP BY country_name, year
HAVING COUNT(*) > 1;
-- Australia, Korea, Vietnam and India have duplicates
-- Australia and India (exact). Korea and Vietnam (conflicting)


-- Rebuild table and remove exact duplicates
CREATE TABLE cleaned_world_bank_data_temp AS
SELECT DISTINCT *
FROM cleaned_world_bank_data;

-- Verify removal of exact duplicates, you should only see Korea and Vietnam
SELECT
    country_name,
    year,
    COUNT(*) AS duplicate_count
FROM cleaned_world_bank_data_temp
GROUP BY country_name, year
HAVING COUNT(*) > 1;


-- Replace old cleaned table with the new updated one without the two duplicates
RENAME TABLE
    cleaned_world_bank_data TO cleaned_world_bank_data_backup,
    cleaned_world_bank_data_temp TO cleaned_world_bank_data;
-- Remove the backup table 
DROP TABLE cleaned_world_bank_data_backup;
-- Exact duplicates were removed.
-- Korea Republic 2000 and Vietnam 2013 contain conflicting values.
-- they are retained for further investigation.


-- 
-- UNRESOLVED RECORDS
-- 

SELECT
    c.country_name,
    c.country_code,
    c.year,
    CASE
        WHEN CAST(c.year AS UNSIGNED) < 2000
          OR CAST(c.year AS UNSIGNED) > 2023
            THEN 'Year outside project scope'

        WHEN r.country_code IS NULL
            THEN 'Country not found in reference table'

        ELSE 'Review record'
    END AS issue
FROM cleaned_world_bank_data c
LEFT JOIN country_reference r
    ON c.country_code = r.country_code
WHERE r.country_code IS NULL
   OR CAST(c.year AS UNSIGNED) < 2000
   OR CAST(c.year AS UNSIGNED) > 2023
ORDER BY c.country_name, c.year;

-- Country codes and Thailand year format can be fixed
SET SQL_SAFE_UPDATES = 0;

-- Correct country codes using the trusted reference table
UPDATE cleaned_world_bank_data c
JOIN country_reference r
    ON c.country_name = r.country_name
SET c.country_code = r.country_code
WHERE c.country_code <> r.country_code;

-- Correct Thailand year formatting
UPDATE cleaned_world_bank_data
SET year = '2013'
WHERE country_name = 'Thailand'
  AND year = 'FY2013';

SET SQL_SAFE_UPDATES = 1;


-- 
-- QUARANTINE UNRESOLVED RECORDS
-- 

CREATE TABLE quarantined_world_bank_data AS
SELECT
    c.*,

    CASE
        WHEN c.country_name = 'Kenya'
             AND c.year = '2024'
            THEN 'Out-of-scope year and extensively incomplete'

        WHEN CAST(c.year AS UNSIGNED) < 2000
          OR CAST(c.year AS UNSIGNED) > 2023
            THEN 'Year outside project scope'

        WHEN r.country_code IS NULL
            THEN 'Country not found in reference table'
    END AS quarantine_reason

FROM cleaned_world_bank_data c
LEFT JOIN country_reference r
    ON c.country_code = r.country_code

WHERE r.country_code IS NULL
   OR CAST(c.year AS UNSIGNED) < 2000
   OR CAST(c.year AS UNSIGNED) > 2023;

SHOW TABLES LIKE 'quarantined_world_bank_data';

SELECT 1;

TRUNCATE TABLE quarantined_world_bank_data;

INSERT INTO quarantined_world_bank_data (
    country_name,
    country_code,
    region,
    income_group,
    year,
    gdp_usd,
    population,
    life_expectancy,
    unemployment_rate,
    co2_emissions_per_capita,
    access_to_electricity_pct,
    source_file,
    ingested_at,
    quarantine_reason
)
SELECT
    c.country_name,
    c.country_code,
    c.region,
    c.income_group,
    c.year,
    c.gdp_usd,
    c.population,
    c.life_expectancy,
    c.unemployment_rate,
    c.co2_emissions_per_capita,
    c.access_to_electricity_pct,
    c.source_file,
    c.ingested_at,

    CASE
        WHEN c.country_name = 'Kenya'
             AND CAST(c.year AS DECIMAL(10,1)) = 2024
            THEN 'Out-of-scope year and extensively incomplete'

        WHEN CAST(c.year AS DECIMAL(10,1)) < 2000
          OR CAST(c.year AS DECIMAL(10,1)) > 2023
            THEN 'Year outside project scope'

        WHEN r.country_code IS NULL
            THEN 'Country not found in reference table'

        ELSE 'Review record'
    END

FROM cleaned_world_bank_data c
LEFT JOIN country_reference r
    ON c.country_code = r.country_code

WHERE r.country_code IS NULL
   OR CAST(c.year AS DECIMAL(10,1)) < 2000
   OR CAST(c.year AS DECIMAL(10,1)) > 2023;
   
SELECT COUNT(*) AS quarantined_rows
FROM quarantined_world_bank_data;

SELECT
    country_name,
    country_code,
    year,
    quarantine_reason
FROM quarantined_world_bank_data
ORDER BY country_name, year;

SET SQL_SAFE_UPDATES = 0;

DELETE c
FROM cleaned_world_bank_data c
LEFT JOIN country_reference r
    ON c.country_code = r.country_code
WHERE r.country_code IS NULL
   OR CAST(c.year AS DECIMAL(10,1)) < 2000
   OR CAST(c.year AS DECIMAL(10,1)) > 2023;

SET SQL_SAFE_UPDATES = 1;

SELECT
    c.country_name,
    c.country_code,
    c.year
FROM cleaned_world_bank_data c
LEFT JOIN country_reference r
    ON c.country_code = r.country_code
WHERE r.country_code IS NULL
   OR CAST(c.year AS DECIMAL(10,1)) < 2000
   OR CAST(c.year AS DECIMAL(10,1)) > 2023;
   
SELECT COUNT(*) AS quarantined_rows
FROM quarantined_world_bank_data;

SELECT DISTINCT year
FROM cleaned_world_bank_data
WHERE year LIKE '%.%';

SET SQL_SAFE_UPDATES = 0;

UPDATE cleaned_world_bank_data
SET year = '2005'
WHERE year = '2005.0';

SET SQL_SAFE_UPDATES = 1;

SELECT DISTINCT year
FROM cleaned_world_bank_data
WHERE year LIKE '%.%';


-- 
-- DATA CLEANING CHECKS AND VERIFICATION
-- 

-- 1. Final row count
SELECT COUNT(*) AS cleaned_rows
FROM cleaned_world_bank_data;

-- 2. Check remaining NULL values
SELECT
    SUM(country_name IS NULL) AS null_country_name,
    SUM(country_code IS NULL) AS null_country_code,
    SUM(region IS NULL) AS null_region,
    SUM(income_group IS NULL) AS null_income_group,
    SUM(year IS NULL) AS null_year,
    SUM(gdp_usd IS NULL) AS null_gdp,
    SUM(population IS NULL) AS null_population,
    SUM(life_expectancy IS NULL) AS null_life_expectancy,
    SUM(unemployment_rate IS NULL) AS null_unemployment,
    SUM(co2_emissions_per_capita IS NULL) AS null_co2,
    SUM(access_to_electricity_pct IS NULL) AS null_electricity
FROM cleaned_world_bank_data;

-- 3. Check for remaining impossible numeric values
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(life_expectancy AS DECIMAL(10,2)) > 120
   OR CAST(life_expectancy AS DECIMAL(10,2)) < 0
   OR CAST(unemployment_rate AS DECIMAL(10,2)) > 100
   OR CAST(unemployment_rate AS DECIMAL(10,2)) < 0
   OR CAST(co2_emissions_per_capita AS DECIMAL(10,2)) < 0
   OR CAST(access_to_electricity_pct AS DECIMAL(10,2)) > 100
   OR CAST(access_to_electricity_pct AS DECIMAL(10,2)) < 0;
   
-- 4. Check that every country belongs to the trusted reference table
SELECT DISTINCT
    c.country_name,
    c.country_code
FROM cleaned_world_bank_data c
LEFT JOIN country_reference r
    ON c.country_code = r.country_code
WHERE r.country_code IS NULL;

-- 5. Check year range
SELECT *
FROM cleaned_world_bank_data
WHERE CAST(year AS DECIMAL(10,1)) < 2000
   OR CAST(year AS DECIMAL(10,1)) > 2023;
   
-- 6. Check remaining duplicate country-year records
SELECT
    country_name,
    year,
    COUNT(*) AS duplicate_count
FROM cleaned_world_bank_data
GROUP BY country_name, year
HAVING COUNT(*) > 1;

-- 7. Verify quarantine table
SELECT COUNT(*) AS quarantined_rows
FROM quarantined_world_bank_data;


-- Data cleaning completed:
-- - Standardised country information using reference data
-- - Corrected country code errors
-- - Standardised blank values to NULL
-- - Replaced impossible values with NULL
-- - Cleaned badly formatted numeric values
-- - Removed exact duplicate records
-- - Retained conflicting duplicates for further investigation
-- - Standardised year formatting
-- - Quarantined 7 out-of-scope/unusable records
-- - Final cleaning checks completed