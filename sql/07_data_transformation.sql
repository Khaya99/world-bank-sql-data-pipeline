-- World Bank SQL Data Pipeline
-- PostgreSQL analytical transformations


-- 
-- 1. Create the analysis-ready view
-- 

CREATE OR REPLACE VIEW analytics.world_bank_indicators AS
SELECT
    s.raw_record_id,
    s.country_code,
    s.country_name,
    s.region,
    s.income_group,
    s.year,
    s.gdp_usd,
    s.population,
    s.life_expectancy,
    s.unemployment_rate,
    s.co2_emissions_per_capita,
    s.access_to_electricity_pct,

    -- GDP per person
    ROUND(
        s.gdp_usd / NULLIF(s.population, 0),
        2
    ) AS gdp_per_capita,

    -- Logarithmic values for statistical analysis
    CASE
        WHEN s.gdp_usd > 0 AND s.population > 0
        THEN ROUND(LN(s.gdp_usd / s.population), 4)
    END AS log_gdp_per_capita,

    CASE
        WHEN s.population > 0
        THEN ROUND(LN(s.population::NUMERIC), 4)
    END AS log_population,

    -- True when all six indicators are available
    NUM_NONNULLS(
        s.gdp_usd,
        s.population,
        s.life_expectancy,
        s.unemployment_rate,
        s.co2_emissions_per_capita,
        s.access_to_electricity_pct
    ) = 6 AS has_complete_indicators,

    s.source_file,
    s.cleaned_at
FROM staging.world_bank_data_clean s;


-- Verify 
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (country_code, year)) AS unique_country_years,
    COUNT(*) FILTER (
        WHERE gdp_per_capita IS NULL
    ) AS gdp_per_capita_nulls,
    COUNT(*) FILTER (
        WHERE NOT has_complete_indicators
    ) AS incomplete_rows
FROM analytics.world_bank_indicators;