USE world_bank_project;

-- 
-- SQL ANALYSIS
-- 


-- SECTION 1: OVERALL DATASET OVERVIEW

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT country_code) AS total_countries,
    MIN(year) AS earliest_year,
    MAX(year) AS latest_year
FROM analysis_world_bank_data;

SELECT
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy,
    ROUND(AVG(unemployment_rate), 2) AS avg_unemployment_rate,
    ROUND(AVG(co2_emissions_per_capita), 2) AS avg_co2_emissions,
    ROUND(AVG(access_to_electricity_pct), 2) AS avg_electricity_access
FROM analysis_world_bank_data;

SELECT
    income_group,
    COUNT(DISTINCT country_code) AS number_of_countries
FROM analysis_world_bank_data
GROUP BY income_group
ORDER BY number_of_countries DESC;

-- 
-- SECTION 2: COUNTRY AND INCOME GROUP COMPARISON
-- 

SELECT
    income_group,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy,
    ROUND(AVG(unemployment_rate), 2) AS avg_unemployment_rate,
    ROUND(AVG(co2_emissions_per_capita), 2) AS avg_co2_emissions,
    ROUND(AVG(access_to_electricity_pct), 2) AS avg_electricity_access
FROM analysis_world_bank_data
WHERE NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
)
GROUP BY income_group
ORDER BY avg_gdp_per_capita DESC;

SELECT
    country_name,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy,
    ROUND(AVG(unemployment_rate), 2) AS avg_unemployment_rate,
    ROUND(AVG(co2_emissions_per_capita), 2) AS avg_co2_emissions,
    ROUND(AVG(access_to_electricity_pct), 2) AS avg_electricity_access
FROM analysis_world_bank_data
WHERE NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
)
GROUP BY country_name
ORDER BY avg_gdp_per_capita DESC;

-- Compare latest data to understand the current situation
SELECT
    country_name,
    income_group,
    gdp_per_capita,
    life_expectancy,
    unemployment_rate,
    co2_emissions_per_capita,
    access_to_electricity_pct
FROM analysis_world_bank_data
WHERE year = 2023
ORDER BY gdp_per_capita DESC;

-- 
-- SECTION 3: GDP PER CAPITA VS LIFE EXPECTANCY
-- 

-- Compare average GDP per capita and life expectancy by country
SELECT
    country_name,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy
FROM analysis_world_bank_data
WHERE gdp_per_capita IS NOT NULL
  AND life_expectancy IS NOT NULL
  AND NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
  )
GROUP BY country_name
ORDER BY avg_gdp_per_capita DESC;

-- Compare life expectancy across GDP per capita groups
SELECT
    CASE
        WHEN gdp_per_capita < 5000 THEN 'Below $5,000'
        WHEN gdp_per_capita < 15000 THEN '$5,000 - $14,999'
        WHEN gdp_per_capita < 30000 THEN '$15,000 - $29,999'
        ELSE '$30,000+'
    END AS gdp_per_capita_group,

    COUNT(*) AS observations,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy

FROM analysis_world_bank_data

WHERE gdp_per_capita IS NOT NULL
  AND life_expectancy IS NOT NULL
  AND NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
  )

GROUP BY gdp_per_capita_group
ORDER BY avg_gdp_per_capita;

-- GDP per capita vs life expectancy in 2023
SELECT
    country_name,
    gdp_per_capita,
    life_expectancy
FROM analysis_world_bank_data
WHERE year = 2023
  AND gdp_per_capita IS NOT NULL
  AND life_expectancy IS NOT NULL
ORDER BY gdp_per_capita DESC;

-- 
-- SECTION 4: ELECTRICITY ACCESS VS LIFE EXPECTANCY
-- 

-- Compare electricity access and life expectancy by country
SELECT
    country_name,
    ROUND(AVG(access_to_electricity_pct), 2) AS avg_electricity_access,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy
FROM analysis_world_bank_data
WHERE access_to_electricity_pct IS NOT NULL
  AND life_expectancy IS NOT NULL
  AND NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
  )
GROUP BY country_name
ORDER BY avg_electricity_access DESC;

-- Group electricity access to ranges
SELECT
    CASE
        WHEN access_to_electricity_pct < 50 THEN 'Below 50%'
        WHEN access_to_electricity_pct < 75 THEN '50% - 74.99%'
        WHEN access_to_electricity_pct < 90 THEN '75% - 89.99%'
        ELSE '90%+'
    END AS electricity_access_group,

    COUNT(*) AS observations,
    ROUND(AVG(access_to_electricity_pct), 2) AS avg_electricity_access,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy

FROM analysis_world_bank_data

WHERE access_to_electricity_pct IS NOT NULL
  AND life_expectancy IS NOT NULL
  AND NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
  )

GROUP BY electricity_access_group
ORDER BY avg_electricity_access;

-- 2023 data for later scatter plot use
SELECT
    country_name,
    access_to_electricity_pct,
    life_expectancy
FROM analysis_world_bank_data
WHERE year = 2023
  AND access_to_electricity_pct IS NOT NULL
  AND life_expectancy IS NOT NULL
ORDER BY access_to_electricity_pct DESC;

-- 
-- SECTION 5: UNEMPLOYMENT VS LIFE EXPECTANCY
-- 

-- Compare average unemployment and life expectancy by country
SELECT
    country_name,
    ROUND(AVG(unemployment_rate), 2) AS avg_unemployment_rate,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy
FROM analysis_world_bank_data
WHERE unemployment_rate IS NOT NULL
  AND life_expectancy IS NOT NULL
  AND NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
  )
GROUP BY country_name
ORDER BY avg_unemployment_rate;

-- Group unemployment rates
SELECT
    CASE
        WHEN unemployment_rate < 5 THEN 'Below 5%'
        WHEN unemployment_rate < 10 THEN '5% - 9.99%'
        WHEN unemployment_rate < 15 THEN '10% - 14.99%'
        ELSE '15%+'
    END AS unemployment_group,

    COUNT(*) AS observations,
    ROUND(AVG(unemployment_rate), 2) AS avg_unemployment_rate,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy

FROM analysis_world_bank_data

WHERE unemployment_rate IS NOT NULL
  AND life_expectancy IS NOT NULL
  AND NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
  )

GROUP BY unemployment_group
ORDER BY avg_unemployment_rate;

-- 2023 Data for future use
SELECT
    country_name,
    unemployment_rate,
    life_expectancy
FROM analysis_world_bank_data
WHERE year = 2023
  AND unemployment_rate IS NOT NULL
  AND life_expectancy IS NOT NULL
ORDER BY unemployment_rate;

-- 
-- SECTION 6: CO2 EMISSIONS VS LIFE EXPECTANCY
-- 

-- Compare average CO2 emissions and life expectancy by country
SELECT
    country_name,
    ROUND(AVG(co2_emissions_per_capita), 2) AS avg_co2_emissions,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy
FROM analysis_world_bank_data
WHERE co2_emissions_per_capita IS NOT NULL
  AND life_expectancy IS NOT NULL
  AND NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
  )
GROUP BY country_name
ORDER BY avg_co2_emissions;

-- Group by the CO2 ranges
SELECT
    CASE
        WHEN co2_emissions_per_capita < 2 THEN 'Below 2'
        WHEN co2_emissions_per_capita < 5 THEN '2 - 4.99'
        WHEN co2_emissions_per_capita < 10 THEN '5 - 9.99'
        ELSE '10+'
    END AS co2_group,

    COUNT(*) AS observations,
    ROUND(AVG(co2_emissions_per_capita), 2) AS avg_co2_emissions,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy

FROM analysis_world_bank_data

WHERE co2_emissions_per_capita IS NOT NULL
  AND life_expectancy IS NOT NULL
  AND NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
  )

GROUP BY co2_group
ORDER BY avg_co2_emissions;

-- 2023 Data for future use
SELECT
    country_name,
    co2_emissions_per_capita,
    life_expectancy
FROM analysis_world_bank_data
WHERE year = 2023
  AND co2_emissions_per_capita IS NOT NULL
  AND life_expectancy IS NOT NULL
ORDER BY co2_emissions_per_capita;

-- 
-- SECTION 7: TRENDS AND FINAL COMPARISONS
-- 

-- Average over the years
SELECT
    year,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy,
    ROUND(AVG(unemployment_rate), 2) AS avg_unemployment_rate,
    ROUND(AVG(co2_emissions_per_capita), 2) AS avg_co2_emissions,
    ROUND(AVG(access_to_electricity_pct), 2) AS avg_electricity_access
FROM analysis_world_bank_data
WHERE NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
)
GROUP BY year
ORDER BY year;

-- Rank countries by Life Expectancy
SELECT
    country_name,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy
FROM analysis_world_bank_data
WHERE life_expectancy IS NOT NULL
  AND NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
  )
GROUP BY country_name
ORDER BY avg_life_expectancy DESC;

-- Rank by average GDP
SELECT
    country_name,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita
FROM analysis_world_bank_data
WHERE gdp_per_capita IS NOT NULL
  AND NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
  )
GROUP BY country_name
ORDER BY avg_gdp_per_capita DESC;

-- Comparing income groups
SELECT
    income_group,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy,
    ROUND(AVG(unemployment_rate), 2) AS avg_unemployment_rate,
    ROUND(AVG(co2_emissions_per_capita), 2) AS avg_co2_emissions,
    ROUND(AVG(access_to_electricity_pct), 2) AS avg_electricity_access
FROM analysis_world_bank_data
WHERE NOT (
       (country_name = 'Korea, Rep.' AND year = 2000)
    OR (country_name = 'Vietnam' AND year = 2013)
)
GROUP BY income_group
ORDER BY avg_gdp_per_capita DESC;


-- 
-- PHASE 7 SUMMARY
-- 

-- SQL analysis completed:
-- - Compared countries and income groups
-- - Analysed GDP per capita vs life expectancy
-- - Analysed electricity access vs life expectancy
-- - Analysed unemployment vs life expectancy
-- - Analysed CO2 emissions vs life expectancy
-- - Compared trends over time
-- - Ranked countries by GDP per capita and life expectancy
--
-- Main findings:
-- - Higher GDP per capita is associated with higher life expectancy
-- - Higher electricity access is strongly associated with higher life expectancy
-- - Unemployment has a weaker and less consistent relationship with life expectancy
-- - CO2 emissions are positively associated with life expectancy up to a point,
--   likely reflecting broader economic development rather than a direct benefit
-- - Results show association, not proof of causation
