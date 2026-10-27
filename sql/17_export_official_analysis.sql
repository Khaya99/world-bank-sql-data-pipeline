-- Export country-level changes for the Tableau report.
COPY (
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
    ORDER BY electricity_change_pp DESC NULLS LAST,
             a.country_code
) TO STDOUT WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');