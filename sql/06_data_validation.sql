-- World Bank SQL Data Pipeline
-- PostgreSQL data validation
-- This file verifies the cleaned staging data without changing it.


-- 
-- 1. Validate row-count reconciliation
-- 

WITH row_counts AS (
    SELECT
        (SELECT COUNT(*) FROM raw.world_bank_data) AS raw_rows,
        (SELECT COUNT(*) FROM staging.world_bank_data_clean) AS cleaned_rows,
        (
            SELECT COUNT(DISTINCT raw_record_id)
            FROM audit.data_quality_log
            WHERE action_taken = 'quarantined'
        ) AS quarantined_rows,
        (
            SELECT COUNT(DISTINCT raw_record_id)
            FROM audit.data_quality_log
            WHERE action_taken = 'excluded_duplicate'
        ) AS excluded_duplicates
)
SELECT
    *,
    raw_rows = cleaned_rows
             + quarantined_rows
             + excluded_duplicates AS passed
FROM row_counts;


-- 
-- 2. Validate country reference data
-- 

SELECT
    s.raw_record_id,
    s.country_code,
    s.country_name,
    s.region,
    s.income_group
FROM staging.world_bank_data_clean s
LEFT JOIN reference.country_reference c
    ON s.country_code = c.country_code
WHERE c.country_code IS NULL
   OR s.country_name IS DISTINCT FROM c.country_name
   OR s.region IS DISTINCT FROM c.region
   OR s.income_group IS DISTINCT FROM c.income_group
ORDER BY s.raw_record_id;


-- 
-- 3. Validate year and numeric ranges
-- 

SELECT
    raw_record_id,
    country_code,
    year,
    gdp_usd,
    population,
    life_expectancy,
    unemployment_rate,
    co2_emissions_per_capita,
    access_to_electricity_pct
FROM staging.world_bank_data_clean
WHERE year NOT BETWEEN 2000 AND 2023
   OR gdp_usd < 0
   OR population < 0
   OR life_expectancy NOT BETWEEN 0 AND 120
   OR unemployment_rate NOT BETWEEN 0 AND 100
   OR co2_emissions_per_capita < 0
   OR access_to_electricity_pct NOT BETWEEN 0 AND 100
ORDER BY raw_record_id;


-- 
-- 4. Validate required fields
-- 

SELECT
    raw_record_id,
    country_code,
    country_name,
    region,
    income_group,
    year,
    source_file
FROM staging.world_bank_data_clean
WHERE raw_record_id IS NULL
   OR NULLIF(BTRIM(country_code), '') IS NULL
   OR NULLIF(BTRIM(country_name), '') IS NULL
   OR NULLIF(BTRIM(region), '') IS NULL
   OR NULLIF(BTRIM(income_group), '') IS NULL
   OR year IS NULL
   OR NULLIF(BTRIM(source_file), '') IS NULL
   OR ingested_at IS NULL
   OR pipeline_loaded_at IS NULL;


-- 
-- 5. Validate unique records
-- 

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT raw_record_id) AS unique_record_ids,
    COUNT(DISTINCT (country_code, year)) AS unique_country_years,
    COUNT(*) = COUNT(DISTINCT raw_record_id)
    AND COUNT(*) = COUNT(DISTINCT (country_code, year)) AS passed
FROM staging.world_bank_data_clean;


-- 
-- 6. Confirm excluded records are absent from staging
-- 

SELECT
    s.raw_record_id,
    s.country_code,
    s.year,
    a.issue_type,
    a.action_taken
FROM staging.world_bank_data_clean s
JOIN audit.data_quality_log a
    ON s.raw_record_id = a.raw_record_id
WHERE a.action_taken IN (
    'quarantined',
    'excluded_duplicate'
)
ORDER BY s.raw_record_id;


-- 
-- 7. Validate PostgreSQL data types
-- 

SELECT
    PG_TYPEOF(raw_record_id) AS record_id_type,
    PG_TYPEOF(year) AS year_type,
    PG_TYPEOF(gdp_usd) AS gdp_type,
    PG_TYPEOF(population) AS population_type,
    PG_TYPEOF(life_expectancy) AS life_expectancy_type,
    PG_TYPEOF(unemployment_rate) AS unemployment_type,
    PG_TYPEOF(co2_emissions_per_capita) AS co2_type,
    PG_TYPEOF(access_to_electricity_pct) AS electricity_type
FROM staging.world_bank_data_clean
LIMIT 1;


-- 
-- 8. Summarize retained NULL indicator values
-- 

SELECT
    COUNT(*) FILTER (WHERE gdp_usd IS NULL) AS gdp_nulls,
    COUNT(*) FILTER (WHERE population IS NULL) AS population_nulls,
    COUNT(*) FILTER (WHERE life_expectancy IS NULL) AS life_expectancy_nulls,
    COUNT(*) FILTER (WHERE unemployment_rate IS NULL) AS unemployment_nulls,
    COUNT(*) FILTER (
        WHERE co2_emissions_per_capita IS NULL
    ) AS co2_nulls,
    COUNT(*) FILTER (
        WHERE access_to_electricity_pct IS NULL
    ) AS electricity_nulls
FROM staging.world_bank_data_clean;




-- 9. Verify the documented Brazil and Mexico corrections
-- Both rows must return passed = true; raw values remain unchanged.
WITH expected(country_code, year, column_name, issue_type, raw_value, clean_value) AS (
    VALUES
        ('BRA', 2022, 'life_expectancy', 'life_expectancy_decimal_corrected',
         '7.5', 75.0::NUMERIC),
        ('MEX', 2023, 'gdp_usd', 'gdp_unit_corrected',
         '1815091.26', 1815091260000.00::NUMERIC)
)
SELECT
    e.country_code, e.year, e.column_name,
    CASE e.column_name WHEN 'life_expectancy' THEN r.life_expectancy
        ELSE r.gdp_usd END AS raw_value,
    CASE e.column_name WHEN 'life_expectancy' THEN s.life_expectancy
        ELSE s.gdp_usd END AS cleaned_value,
    COALESCE(
        BTRIM(CASE e.column_name WHEN 'life_expectancy' THEN r.life_expectancy
            ELSE r.gdp_usd END) = e.raw_value
        AND CASE e.column_name WHEN 'life_expectancy' THEN s.life_expectancy
            ELSE s.gdp_usd END = e.clean_value
        AND a.original_value = e.raw_value
        AND (CASE WHEN a.cleaned_value ~ '^-?[0-9]+([.][0-9]+)?$' THEN a.cleaned_value::NUMERIC END) = e.clean_value
        AND a.action_taken = 'corrected', FALSE
    ) AS passed
FROM expected e
LEFT JOIN staging.world_bank_data_clean s
    ON s.country_code = e.country_code AND s.year = e.year
LEFT JOIN raw.world_bank_data r ON r.raw_record_id = s.raw_record_id
LEFT JOIN audit.data_quality_log a
    ON a.raw_record_id = s.raw_record_id
   AND a.column_name = e.column_name AND a.issue_type = e.issue_type
ORDER BY e.country_code;
