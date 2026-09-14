-- World Bank SQL Data Pipeline
-- PostgreSQL raw-data profiling

-- Read-only queries: this script does not modify data.

-- 
-- 1. Confirm the raw-data baseline
-- 

SELECT
    COUNT(*) AS raw_row_count,
    COUNT(DISTINCT raw_record_id) AS unique_raw_ids,
    COUNT(
        DISTINCT NULLIF(BTRIM(country_code), '')
    ) AS distinct_country_codes,
    COUNT(
        DISTINCT NULLIF(BTRIM(country_name), '')
    ) AS distinct_country_names,
    COUNT(*) FILTER (
        WHERE pipeline_loaded_at IS NULL
    ) AS missing_pipeline_timestamps
FROM raw.world_bank_data;


-- 
-- 2. Find raw entities absent from the country reference
-- 

SELECT
    NULLIF(BTRIM(r.country_code), '') AS country_code,
    NULLIF(BTRIM(r.country_name), '') AS country_name,
    COUNT(*) AS row_count,
    MIN(NULLIF(BTRIM(r.year), '')) AS first_year,
    MAX(NULLIF(BTRIM(r.year), '')) AS last_year
FROM raw.world_bank_data r
LEFT JOIN reference.country_reference c
    ON NULLIF(BTRIM(r.country_code), '') = c.country_code
WHERE c.country_code IS NULL
GROUP BY
    NULLIF(BTRIM(r.country_code), ''),
    NULLIF(BTRIM(r.country_name), '')
ORDER BY
    country_code,
    country_name;


-- 
-- 3. Classify every non-reference record
-- 

SELECT
    r.raw_record_id,
    NULLIF(BTRIM(r.country_code), '') AS raw_country_code,
    NULLIF(BTRIM(r.country_name), '') AS raw_country_name,
    NULLIF(BTRIM(r.year), '') AS raw_year,
    c_by_name.country_code AS expected_country_code,
    CASE
        WHEN UPPER(BTRIM(r.country_code)) IN ('EUU', 'WLD')
            THEN 'aggregate entity'
        WHEN c_by_name.country_code IS NOT NULL
            THEN 'country-code mismatch'
        ELSE 'outside approved reference scope'
    END AS issue_type
FROM raw.world_bank_data r
LEFT JOIN reference.country_reference c_by_code
    ON BTRIM(r.country_code) = c_by_code.country_code
LEFT JOIN reference.country_reference c_by_name
    ON BTRIM(r.country_name) = c_by_name.country_name
WHERE c_by_code.country_code IS NULL
ORDER BY
    raw_country_code,
    raw_year,
    r.raw_record_id;


-- 
-- 4. Check country names against the reference
--

SELECT
    BTRIM(r.country_code) AS country_code,
    NULLIF(BTRIM(r.country_name), '') AS raw_country_name,
    c.country_name AS expected_country_name,
    COUNT(*) AS row_count,
    MIN(NULLIF(BTRIM(r.year), '')) AS first_year,
    MAX(NULLIF(BTRIM(r.year), '')) AS last_year
FROM raw.world_bank_data r
JOIN reference.country_reference c
    ON BTRIM(r.country_code) = c.country_code
WHERE NULLIF(BTRIM(r.country_name), '')
      IS DISTINCT FROM c.country_name
GROUP BY
    BTRIM(r.country_code),
    NULLIF(BTRIM(r.country_name), ''),
    c.country_name
ORDER BY country_code, raw_country_name;


-- 
-- 5. Check regions against the reference
-- 
SELECT
    BTRIM(r.country_code) AS country_code,
    c.country_name,
    NULLIF(BTRIM(r.region), '') AS raw_region,
    c.region AS expected_region,
    COUNT(*) AS row_count
FROM raw.world_bank_data r
JOIN reference.country_reference c
    ON BTRIM(r.country_code) = c.country_code
WHERE NULLIF(BTRIM(r.region), '')
      IS DISTINCT FROM c.region
GROUP BY
    BTRIM(r.country_code),
    c.country_name,
    NULLIF(BTRIM(r.region), ''),
    c.region
ORDER BY country_code, raw_region;


-- 
-- 6. Check income groups against the reference
-- 

SELECT
    BTRIM(r.country_code) AS country_code,
    c.country_name,
    NULLIF(BTRIM(r.income_group), '') AS raw_income_group,
    c.income_group AS expected_income_group,
    COUNT(*) AS row_count
FROM raw.world_bank_data r
JOIN reference.country_reference c
    ON BTRIM(r.country_code) = c.country_code
WHERE NULLIF(BTRIM(r.income_group), '')
      IS DISTINCT FROM c.income_group
GROUP BY
    BTRIM(r.country_code),
    c.country_name,
    NULLIF(BTRIM(r.income_group), ''),
    c.income_group
ORDER BY country_code, raw_income_group;


-- 
-- 7. Count missing or blank values by source column
-- 

SELECT
    v.column_name,
    COUNT(*) AS missing_or_blank_count
FROM raw.world_bank_data r
CROSS JOIN LATERAL (
    VALUES
        (1,  'country_name',                r.country_name),
        (2,  'country_code',                r.country_code),
        (3,  'region',                      r.region),
        (4,  'income_group',                r.income_group),
        (5,  'year',                        r.year),
        (6,  'gdp_usd',                     r.gdp_usd),
        (7,  'population',                  r.population),
        (8,  'life_expectancy',             r.life_expectancy),
        (9,  'unemployment_rate',           r.unemployment_rate),
        (10, 'co2_emissions_per_capita',    r.co2_emissions_per_capita),
        (11, 'access_to_electricity_pct',   r.access_to_electricity_pct),
        (12, 'source_file',                 r.source_file),
        (13, 'ingested_at',                 r.ingested_at)
) AS v(column_order, column_name, column_value)
WHERE NULLIF(BTRIM(v.column_value), '') IS NULL
GROUP BY
    v.column_order,
    v.column_name
ORDER BY v.column_order;


-- 
-- 8. Identify records and columns containing missing values
-- 

SELECT
    r.raw_record_id,
    r.country_code,
    r.country_name,
    r.year,
    STRING_AGG(
        v.column_name,
        ', ' ORDER BY v.column_order
    ) AS missing_columns
FROM raw.world_bank_data r
CROSS JOIN LATERAL (
    VALUES
        (1,  'country_name',                r.country_name),
        (2,  'country_code',                r.country_code),
        (3,  'region',                      r.region),
        (4,  'income_group',                r.income_group),
        (5,  'year',                        r.year),
        (6,  'gdp_usd',                     r.gdp_usd),
        (7,  'population',                  r.population),
        (8,  'life_expectancy',             r.life_expectancy),
        (9,  'unemployment_rate',           r.unemployment_rate),
        (10, 'co2_emissions_per_capita',    r.co2_emissions_per_capita),
        (11, 'access_to_electricity_pct',   r.access_to_electricity_pct),
        (12, 'source_file',                 r.source_file),
        (13, 'ingested_at',                 r.ingested_at)
) AS v(column_order, column_name, column_value)
WHERE NULLIF(BTRIM(v.column_value), '') IS NULL
GROUP BY
    r.raw_record_id,
    r.country_code,
    r.country_name,
    r.year
ORDER BY r.raw_record_id;


-- 
-- 9. Check year format and range
-- 

SELECT
    raw_record_id,
    country_code,
    country_name,
    year AS raw_year,
    CASE
        WHEN NULLIF(BTRIM(year), '') IS NULL
            THEN 'missing year'
        WHEN BTRIM(year) !~ '^[0-9]{4}$'
            THEN 'invalid year format'
        ELSE 'outside 2000-2023 range'
    END AS issue_type
FROM raw.world_bank_data
WHERE CASE
    WHEN NULLIF(BTRIM(year), '') ~ '^[0-9]{4}$'
        THEN BTRIM(year)::INTEGER NOT BETWEEN 2000 AND 2023
    ELSE TRUE
END
ORDER BY raw_record_id;


-- 
-- 10. Find non-numeric indicator values
-- 

SELECT
    r.raw_record_id,
    r.country_code,
    r.country_name,
    r.year,
    v.column_name,
    BTRIM(v.raw_value) AS raw_value
FROM raw.world_bank_data r
CROSS JOIN LATERAL (
    VALUES
        ('gdp_usd',                   r.gdp_usd),
        ('population',                r.population),
        ('life_expectancy',           r.life_expectancy),
        ('unemployment_rate',         r.unemployment_rate),
        ('co2_emissions_per_capita',  r.co2_emissions_per_capita),
        ('access_to_electricity_pct', r.access_to_electricity_pct)
) AS v(column_name, raw_value)
WHERE NULLIF(BTRIM(v.raw_value), '') IS NOT NULL
  AND BTRIM(v.raw_value) !~
      '^[+-]?[0-9]+([.][0-9]+)?$'
ORDER BY r.raw_record_id, v.column_name;


-- 
-- 11. Find numeric values outside acceptable ranges
-- 

SELECT
    r.raw_record_id,
    r.country_code,
    r.country_name,
    r.year,
    v.column_name,
    BTRIM(v.raw_value) AS raw_value,
    v.minimum_allowed,
    v.maximum_allowed
FROM raw.world_bank_data r
CROSS JOIN LATERAL (
    VALUES
        ('gdp_usd',                   r.gdp_usd,                    0::NUMERIC, NULL::NUMERIC),
        ('population',                r.population,                 0::NUMERIC, NULL::NUMERIC),
        ('life_expectancy',           r.life_expectancy,            0::NUMERIC, 120::NUMERIC),
        ('unemployment_rate',         r.unemployment_rate,          0::NUMERIC, 100::NUMERIC),
        ('co2_emissions_per_capita',  r.co2_emissions_per_capita,   0::NUMERIC, NULL::NUMERIC),
        ('access_to_electricity_pct', r.access_to_electricity_pct,  0::NUMERIC, 100::NUMERIC)
) AS v(column_name, raw_value, minimum_allowed, maximum_allowed)
WHERE CASE
    WHEN NULLIF(BTRIM(v.raw_value), '') ~
         '^[+-]?[0-9]+([.][0-9]+)?$'
    THEN
        BTRIM(v.raw_value)::NUMERIC < v.minimum_allowed
        OR (
            v.maximum_allowed IS NOT NULL
            AND BTRIM(v.raw_value)::NUMERIC > v.maximum_allowed
        )
    ELSE FALSE
END
ORDER BY r.raw_record_id, v.column_name;


-- 
-- 12. Find exact duplicate source records
-- 

SELECT
    country_code,
    country_name,
    year,
    COUNT(*) AS duplicate_count,
    ARRAY_AGG(
        raw_record_id ORDER BY raw_record_id
    ) AS raw_record_ids
FROM raw.world_bank_data
GROUP BY
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
    ingested_at
HAVING COUNT(*) > 1
ORDER BY country_code, year;


-- 
-- 13. Find all duplicate country-year combinations
-- 

SELECT
    NULLIF(BTRIM(country_code), '') AS country_code,
    NULLIF(BTRIM(year), '') AS year,
    STRING_AGG(
        DISTINCT NULLIF(BTRIM(country_name), ''),
        ' | '
    ) AS country_names,
    COUNT(*) AS record_count,
    ARRAY_AGG(
        raw_record_id ORDER BY raw_record_id
    ) AS raw_record_ids
FROM raw.world_bank_data
GROUP BY
    NULLIF(BTRIM(country_code), ''),
    NULLIF(BTRIM(year), '')
HAVING COUNT(*) > 1
ORDER BY country_code, year;


-- 
-- 14. Inspect conflicting duplicate records
-- 

SELECT *
FROM raw.world_bank_data
WHERE (BTRIM(country_code) = 'KOR' AND BTRIM(year) = '2000')
   OR (BTRIM(country_code) = 'VNM' AND BTRIM(year) = '2013')
ORDER BY country_code, year, raw_record_id;

-- Inspect the duplicates further
SELECT
    raw_record_id,
    country_code,
    year,
    gdp_usd,
    population,
    life_expectancy,
    unemployment_rate,
    co2_emissions_per_capita,
    access_to_electricity_pct,
    source_file
FROM raw.world_bank_data
WHERE (BTRIM(country_code) = 'KOR' AND BTRIM(year) = '2000')
   OR (BTRIM(country_code) = 'VNM' AND BTRIM(year) = '2013')
ORDER BY country_code, year, raw_record_id;


-- 
-- 15. Find missing expected country-year records
-- 

SELECT
    c.country_code,
    c.country_name,
    y.expected_year AS missing_year
FROM reference.country_reference c
CROSS JOIN generate_series(2000, 2023) AS y(expected_year)
LEFT JOIN raw.world_bank_data r
    ON BTRIM(r.country_code) = c.country_code
   AND BTRIM(r.year) = y.expected_year::TEXT
WHERE r.raw_record_id IS NULL
ORDER BY c.country_code, y.expected_year;