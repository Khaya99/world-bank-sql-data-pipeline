-- Explore electricity access and life expectancy in official data.
SELECT
    COUNT(*) AS paired_observations,
    ROUND(
        CORR(access_to_electricity_pct, life_expectancy)::NUMERIC,
        3
    ) AS correlation
FROM worldbank.indicators_typed
WHERE access_to_electricity_pct IS NOT NULL
  AND life_expectancy IS NOT NULL;


-- Compare electricity access and life expectancy within each year.
SELECT
    year,
    COUNT(*) AS paired_observations,
    ROUND(
        CORR(access_to_electricity_pct, life_expectancy)::NUMERIC,
        3
    ) AS correlation
FROM worldbank.indicators_typed
WHERE access_to_electricity_pct IS NOT NULL
  AND life_expectancy IS NOT NULL
GROUP BY year
ORDER BY year;


-- Compare changes in electricity access and life expectancy, 2000–2023.
WITH changes AS (
    SELECT
        a.country_code,
        b.access_to_electricity_pct
            - a.access_to_electricity_pct AS electricity_change,
        b.life_expectancy
            - a.life_expectancy AS life_expectancy_change
    FROM worldbank.indicators_typed AS a
    JOIN worldbank.indicators_typed AS b
      ON a.country_code = b.country_code
    WHERE a.year = 2000
      AND b.year = 2023
)
SELECT
    COUNT(*) AS paired_countries,
    ROUND(
        CORR(electricity_change, life_expectancy_change)::NUMERIC,
        3
    ) AS change_correlation
FROM changes
WHERE electricity_change IS NOT NULL
  AND life_expectancy_change IS NOT NULL;


-- Compare each country's changes between 2000 and 2023.
SELECT
    a.country_name,
    a.country_code,
    ROUND(
        b.access_to_electricity_pct - a.access_to_electricity_pct,
        2
    ) AS electricity_change_pp,
    ROUND(
        b.life_expectancy - a.life_expectancy,
        2
    ) AS life_expectancy_change_years
FROM worldbank.indicators_typed AS a
JOIN worldbank.indicators_typed AS b
    ON a.country_code = b.country_code
WHERE a.year = 2000
  AND b.year = 2023
ORDER BY electricity_change_pp DESC NULLS LAST;