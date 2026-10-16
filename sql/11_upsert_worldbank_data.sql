-- Insert new country-year records or update existing ones from staging.
-- Run the staging validation checks before loading new data.

BEGIN;

INSERT INTO worldbank.indicators_typed AS target (
    country_name, country_code, region, income_group, year,
    gdp_usd, population, life_expectancy, unemployment_rate,
    co2_emissions_per_capita, access_to_electricity_pct,
    source_file, ingested_at
)
SELECT
    country_name,
    country_code,
    region,
    income_group,
    year::INTEGER,
    gdp_usd::NUMERIC,
    population::NUMERIC::BIGINT,
    life_expectancy::NUMERIC,
    unemployment_rate::NUMERIC,
    co2_emissions_per_capita::NUMERIC,
    access_to_electricity_pct::NUMERIC,
    source_file,
    ingested_at::TIMESTAMP AT TIME ZONE 'UTC'
FROM worldbank.indicators_staging

ON CONFLICT (country_code, year)
DO UPDATE SET
    country_name = EXCLUDED.country_name,
    region = EXCLUDED.region,
    income_group = EXCLUDED.income_group,
    gdp_usd = EXCLUDED.gdp_usd,
    population = EXCLUDED.population,
    life_expectancy = EXCLUDED.life_expectancy,
    unemployment_rate = EXCLUDED.unemployment_rate,
    co2_emissions_per_capita = EXCLUDED.co2_emissions_per_capita,
    access_to_electricity_pct = EXCLUDED.access_to_electricity_pct,
    source_file = EXCLUDED.source_file,
    ingested_at = EXCLUDED.ingested_at;

COMMIT;

SELECT COUNT(*) AS total_rows
FROM worldbank.indicators_typed;