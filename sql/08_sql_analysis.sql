-- World Bank SQL Data Pipeline
-- PostgreSQL statistical analysis


-- 
-- 1. Dataset overview
-- 

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT country_code) AS countries,
    MIN(year) AS first_year,
    MAX(year) AS last_year,
    COUNT(*) FILTER (
        WHERE has_complete_indicators
    ) AS complete_records,
    COUNT(*) FILTER (
        WHERE NOT has_complete_indicators
    ) AS incomplete_records,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE has_complete_indicators
        ) / COUNT(*),
        2
    ) AS completeness_pct
FROM analytics.world_bank_indicators;


-- 
-- 2. Average indicator trends by year
-- 

SELECT
    year,
    COUNT(*) AS country_records,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy,
    ROUND(AVG(co2_emissions_per_capita), 2) AS avg_co2_per_capita,
    ROUND(AVG(unemployment_rate), 2) AS avg_unemployment_rate,
    ROUND(AVG(access_to_electricity_pct), 2) AS avg_electricity_access,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita,
    ROUND(AVG(population) / 1000000, 2) AS avg_population_millions
FROM analytics.world_bank_indicators
GROUP BY year
ORDER BY year;

-- Compare each indicator with life expectancy
SELECT
    ROUND(CORR(life_expectancy, co2_emissions_per_capita)::numeric, 3) AS co2_correlation,
    ROUND(CORR(life_expectancy, unemployment_rate)::numeric, 3) AS unemployment_correlation,
    ROUND(CORR(life_expectancy, access_to_electricity_pct)::numeric, 3) AS electricity_correlation,
    ROUND(CORR(life_expectancy, gdp_per_capita)::numeric, 3) AS gdp_per_capita_correlation,
    ROUND(CORR(life_expectancy, population)::numeric, 3) AS population_correlation
FROM analytics.world_bank_indicators;

-- Compare by income group
SELECT
    income_group,
    COUNT(*) AS country_years,
    ROUND(AVG(life_expectancy), 2) AS avg_life_expectancy,
    ROUND(AVG(access_to_electricity_pct), 2) AS avg_electricity_access,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita
FROM analytics.world_bank_indicators
GROUP BY income_group
ORDER BY avg_life_expectancy DESC;


-- Correlate country-level changes from 2000 to 2023
-- Correlate 2000–2023 indicator changes with life expectancy change
SELECT
    ROUND(CORR(
        e.life_expectancy - b.life_expectancy,
        e.access_to_electricity_pct - b.access_to_electricity_pct
    )::numeric, 3) AS electricity_change_correlation,

    ROUND(CORR(
        e.life_expectancy - b.life_expectancy,
        e.co2_emissions_per_capita - b.co2_emissions_per_capita
    )::numeric, 3) AS co2_change_correlation,

    ROUND(CORR(
        e.life_expectancy - b.life_expectancy,
        e.unemployment_rate - b.unemployment_rate
    )::numeric, 3) AS unemployment_change_correlation,

    ROUND(CORR(
        e.life_expectancy - b.life_expectancy,
        e.gdp_per_capita - b.gdp_per_capita
    )::numeric, 3) AS gdp_change_correlation
FROM analytics.world_bank_indicators b
JOIN analytics.world_bank_indicators e
    ON e.country_code = b.country_code
WHERE b.year = 2000
  AND e.year = 2023;

-- Inspect the largest GDP per capita changes, 2000–2023
SELECT
    b.country_name,
    ROUND(e.gdp_per_capita - b.gdp_per_capita, 2) AS gdp_per_capita_change,
    ROUND(e.life_expectancy - b.life_expectancy, 2) AS life_expectancy_change
FROM analytics.world_bank_indicators b
JOIN analytics.world_bank_indicators e
    ON e.country_code = b.country_code
WHERE b.year = 2000
  AND e.year = 2023
ORDER BY ABS(e.gdp_per_capita - b.gdp_per_capita) DESC
LIMIT 10;

-- Inspect starting life expectancy for the largest GDP gains
SELECT
    b.country_name,
    b.life_expectancy AS life_expectancy_2000,
    ROUND(e.life_expectancy - b.life_expectancy, 2) AS life_expectancy_change,
    ROUND(e.gdp_per_capita - b.gdp_per_capita, 2) AS gdp_per_capita_change
FROM analytics.world_bank_indicators b
JOIN analytics.world_bank_indicators e
    ON e.country_code = b.country_code
WHERE b.year = 2000
  AND e.year = 2023
ORDER BY ABS(e.gdp_per_capita - b.gdp_per_capita) DESC
LIMIT 10;

-- The largest GDP per capita gains were mostly in countries that already
-- Their life expectancy gains were smaller.
-- This may explain the negative correlation between the two changes.


-- Compare GDP per capita with CO₂, unemployment, and electricity access
SELECT
    ROUND(CORR(gdp_per_capita, co2_emissions_per_capita)::numeric, 3)
        AS co2_correlation,
    ROUND(CORR(gdp_per_capita, unemployment_rate)::numeric, 3)
        AS unemployment_correlation,
    ROUND(CORR(gdp_per_capita, access_to_electricity_pct)::numeric, 3)
        AS electricity_correlation
FROM analytics.world_bank_indicators;

-- Compare population with CO₂, unemployment, and electricity access
SELECT
    ROUND(CORR(population, co2_emissions_per_capita)::numeric, 3)
        AS co2_correlation,
    ROUND(CORR(population, unemployment_rate)::numeric, 3)
        AS unemployment_correlation,
    ROUND(CORR(population, access_to_electricity_pct)::numeric, 3)
        AS electricity_correlation
FROM analytics.world_bank_indicators;

-- Population has little linear association with CO₂ emissions per capita,
-- unemployment rate, or electricity access in this dataset.

