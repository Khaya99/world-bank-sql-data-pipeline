-- Export three development indicators for the 2023 country comparison.
COPY (
    SELECT
        country_name,
        country_code,
        year,
        ROUND(
            gdp_usd / NULLIF(population, 0),
            2
        ) AS gdp_per_capita_current_usd,
        life_expectancy AS life_expectancy_years,
        access_to_electricity_pct
    FROM worldbank.indicators_typed
    WHERE year = 2023
    ORDER BY country_code
) TO STDOUT WITH (
    FORMAT CSV,
    HEADER TRUE,
    ENCODING 'UTF8'
);