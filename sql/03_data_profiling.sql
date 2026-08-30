USE world_bank_project;

-- 1. Total number of rows
SELECT COUNT(*) AS total_rows
FROM raw_world_bank_data;

-- 2. Preview the first few rows
SELECT *
FROM raw_world_bank_data
LIMIT 10;

-- 3. Check the year range
SELECT 
    MIN(year) AS earliest_year,
    MAX(year) AS latest_year
FROM raw_world_bank_data;

-- 4. Count unique countries
SELECT COUNT(DISTINCT country_name) AS total_countries
FROM raw_world_bank_data;

-- 5. Check unique regions
SELECT DISTINCT region
FROM raw_world_bank_data
ORDER BY region;

-- 6. Check unique income groups
SELECT DISTINCT income_group
FROM raw_world_bank_data
ORDER BY income_group;

-- 7. Check missing and blank values

SELECT
    SUM(country_name IS NULL OR TRIM(country_name) = '') AS missing_country_name,
    SUM(country_code IS NULL OR TRIM(country_code) = '') AS missing_country_code,
    SUM(region IS NULL OR TRIM(region) = '') AS missing_region,
    SUM(income_group IS NULL OR TRIM(income_group) = '') AS missing_income_group,
    SUM(year IS NULL OR TRIM(year) = '') AS missing_year,
    SUM(gdp_usd IS NULL OR TRIM(gdp_usd) = '') AS missing_gdp,
    SUM(population IS NULL OR TRIM(population) = '') AS missing_population,
    SUM(life_expectancy IS NULL OR TRIM(life_expectancy) = '') AS missing_life_expectancy,
    SUM(unemployment_rate IS NULL OR TRIM(unemployment_rate) = '') AS missing_unemployment,
    SUM(co2_emissions_per_capita IS NULL OR TRIM(co2_emissions_per_capita) = '') AS missing_co2,
    SUM(access_to_electricity_pct IS NULL OR TRIM(access_to_electricity_pct) = '') AS missing_electricity
FROM raw_world_bank_data;

-- 8. Check duplicate country-year records

SELECT
    country_name,
    year,
    COUNT(*) AS duplicate_count
FROM raw_world_bank_data
GROUP BY country_name, year
HAVING COUNT(*) > 1;

-- Check impossible numeric values

-- 9. Check for invalid year values

SELECT *
FROM raw_world_bank_data
WHERE year < '2000'
   OR year > '2023';

-- 10. Check for invalid GDP values

SELECT *
FROM raw_world_bank_data
WHERE gdp_usd < 0;

-- 11. Check for invalid population values

SELECT *
FROM raw_world_bank_data
WHERE population < 0;

-- 12. Check for invalid life expectancy values

SELECT *
FROM raw_world_bank_data
WHERE life_expectancy < 0
   OR life_expectancy > 120;

-- 13. Check for invalid unemployment values

SELECT *
FROM raw_world_bank_data
WHERE unemployment_rate < 0
   OR unemployment_rate > 100;

-- 14. Check invalid CO2 emission values

SELECT *
FROM raw_world_bank_data
WHERE co2_emissions_per_capita < 0;

-- 15. Check for invalid access to electricity values

SELECT *
FROM raw_world_bank_data
WHERE access_to_electricity_pct < 0
   OR access_to_electricity_pct > 100;