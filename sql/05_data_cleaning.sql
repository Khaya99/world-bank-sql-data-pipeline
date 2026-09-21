-- 
-- World Bank SQL Data Pipeline
-- PostgreSQL data cleaning
-- 

-- Cleaning rules:
-- 1. raw.world_bank_data remains unchanged.
-- 2. Recoverable problems are corrected in staging.
-- 3. Unrecoverable records are excluded and logged.
-- 4. Every action remains traceable through raw_record_id.


-- 
-- 1. Create the data-quality audit log
-- 

BEGIN;

CREATE TABLE IF NOT EXISTS audit.data_quality_log (
    issue_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    raw_record_id BIGINT NOT NULL
        REFERENCES raw.world_bank_data(raw_record_id),
    column_name TEXT NOT NULL DEFAULT 'row',
    issue_type TEXT NOT NULL,
    original_value TEXT,
    cleaned_value TEXT,
    action_taken TEXT NOT NULL,
    logged_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (raw_record_id, column_name, issue_type)
);

COMMIT;


-- Verify that the audit table exists
SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'audit'
  AND table_name = 'data_quality_log';


-- 
-- 2. Create the cleaned staging table
-- 

CREATE TABLE IF NOT EXISTS staging.world_bank_data_clean (
    raw_record_id BIGINT PRIMARY KEY
        REFERENCES raw.world_bank_data(raw_record_id),

    country_code TEXT NOT NULL
        REFERENCES reference.country_reference(country_code),
    country_name TEXT NOT NULL,
    region TEXT NOT NULL,
    income_group TEXT NOT NULL,
    year SMALLINT NOT NULL CHECK (year BETWEEN 2000 AND 2023),

    gdp_usd NUMERIC(20, 2) CHECK (gdp_usd >= 0),
    population BIGINT CHECK (population >= 0),
    life_expectancy NUMERIC(5, 2)
        CHECK (life_expectancy BETWEEN 0 AND 120),
    unemployment_rate NUMERIC(5, 2)
        CHECK (unemployment_rate BETWEEN 0 AND 100),
    co2_emissions_per_capita NUMERIC(10, 4)
        CHECK (co2_emissions_per_capita >= 0),
    access_to_electricity_pct NUMERIC(5, 2)
        CHECK (access_to_electricity_pct BETWEEN 0 AND 100),

    source_file TEXT NOT NULL,
    ingested_at TIMESTAMP NOT NULL,
    pipeline_loaded_at TIMESTAMPTZ NOT NULL,
    cleaned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (country_code, year)
);


-- Verify the table structure
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'staging'
  AND table_name = 'world_bank_data_clean'
ORDER BY ordinal_position;


-- 
-- 3. Quarantine unusable records
-- 

-- Entities outside the approved reference scope
INSERT INTO audit.data_quality_log (
    raw_record_id,
    column_name,
    issue_type,
    original_value,
    action_taken
)
SELECT
    r.raw_record_id,
    'row',
    'outside_reference_scope',
    CONCAT_WS(' | ', BTRIM(r.country_code), BTRIM(r.country_name)),
    'quarantined'
FROM raw.world_bank_data r
WHERE NOT EXISTS (
    SELECT 1
    FROM reference.country_reference c
    WHERE c.country_code = UPPER(BTRIM(r.country_code))
       OR c.country_name = BTRIM(r.country_name)
)
ON CONFLICT (raw_record_id, column_name, issue_type) DO NOTHING;


-- Numeric years outside 2000–2023
INSERT INTO audit.data_quality_log (
    raw_record_id,
    column_name,
    issue_type,
    original_value,
    action_taken
)
SELECT
    raw_record_id,
    'year',
    'year_out_of_range',
    BTRIM(year),
    'quarantined'
FROM raw.world_bank_data
WHERE BTRIM(year) ~ '^[0-9]{4}$'
  AND BTRIM(year) NOT BETWEEN '2000' AND '2023'
ON CONFLICT (raw_record_id, column_name, issue_type) DO NOTHING;


-- Verify quarantined records
SELECT
    q.raw_record_id,
    r.country_code,
    r.country_name,
    r.year,
    q.issue_type
FROM audit.data_quality_log q
JOIN raw.world_bank_data r
    ON r.raw_record_id = q.raw_record_id
WHERE q.action_taken = 'quarantined'
ORDER BY q.raw_record_id;


-- 
-- 4. Log safe code and year corrections
-- 

-- Correct country codes by matching the country name
INSERT INTO audit.data_quality_log (
    raw_record_id,
    column_name,
    issue_type,
    original_value,
    cleaned_value,
    action_taken
)
SELECT
    r.raw_record_id,
    'country_code',
    'country_code_standardized',
    r.country_code,
    c.country_code,
    'corrected'
FROM raw.world_bank_data r
JOIN reference.country_reference c
    ON BTRIM(r.country_name) = c.country_name
WHERE BTRIM(r.country_code) IS DISTINCT FROM c.country_code
ON CONFLICT (raw_record_id, column_name, issue_type) DO NOTHING;


-- Correct safely recoverable year formats
INSERT INTO audit.data_quality_log (
    raw_record_id,
    column_name,
    issue_type,
    original_value,
    cleaned_value,
    action_taken
)
SELECT
    raw_record_id,
    'year',
    'year_format_standardized',
    year,
    CASE
        WHEN BTRIM(year) ~ '^FY[0-9]{4}$'
            THEN RIGHT(BTRIM(year), 4)
        WHEN BTRIM(year) ~ '^[0-9]{4}\.0$'
            THEN SPLIT_PART(BTRIM(year), '.', 1)
    END,
    'corrected'
FROM raw.world_bank_data
WHERE BTRIM(year) ~ '^FY[0-9]{4}$'
   OR BTRIM(year) ~ '^[0-9]{4}\.0$'
ON CONFLICT (raw_record_id, column_name, issue_type) DO NOTHING;


-- Verify the corrections
SELECT
    raw_record_id,
    column_name,
    original_value,
    cleaned_value,
    action_taken
FROM audit.data_quality_log
WHERE issue_type IN (
    'country_code_standardized',
    'year_format_standardized'
)
ORDER BY raw_record_id;


-- 
-- 5. Log reference-value standardization
-- 

INSERT INTO audit.data_quality_log (
    raw_record_id,
    column_name,
    issue_type,
    original_value,
    cleaned_value,
    action_taken
)
SELECT
    r.raw_record_id,
    'reference_fields',
    'reference_values_standardized',
    CONCAT_WS(
        ' | ',
        NULLIF(BTRIM(r.country_name), ''),
        NULLIF(BTRIM(r.region), ''),
        NULLIF(BTRIM(r.income_group), '')
    ),
    CONCAT_WS(
        ' | ',
        c.country_name,
        c.region,
        c.income_group
    ),
    'corrected'
FROM raw.world_bank_data r
JOIN reference.country_reference c
    ON c.country_code = UPPER(BTRIM(r.country_code))
    OR c.country_name = BTRIM(r.country_name)
WHERE NULLIF(BTRIM(r.country_name), '') IS DISTINCT FROM c.country_name
   OR NULLIF(BTRIM(r.region), '') IS DISTINCT FROM c.region
   OR NULLIF(BTRIM(r.income_group), '') IS DISTINCT FROM c.income_group
ON CONFLICT (raw_record_id, column_name, issue_type) DO NOTHING;


-- Verify the recorded corrections
SELECT
    raw_record_id,
    original_value,
    cleaned_value,
    action_taken
FROM audit.data_quality_log
WHERE issue_type = 'reference_values_standardized'
ORDER BY raw_record_id;


-- 
-- 6. Log recoverable numeric-format corrections
-- 

INSERT INTO audit.data_quality_log (
    raw_record_id,
    column_name,
    issue_type,
    original_value,
    cleaned_value,
    action_taken
)

-- Decimal comma: 7,86 → 7.86
SELECT
    raw_record_id,
    'co2_emissions_per_capita',
    'numeric_format_standardized',
    co2_emissions_per_capita,
    REPLACE(BTRIM(co2_emissions_per_capita), ',', '.'),
    'corrected'
FROM raw.world_bank_data
WHERE BTRIM(co2_emissions_per_capita) ~ '^[0-9]+,[0-9]+$'

UNION ALL

-- Percentage sign: 6.14% → 6.14
SELECT
    raw_record_id,
    'unemployment_rate',
    'numeric_format_standardized',
    unemployment_rate,
    REPLACE(BTRIM(unemployment_rate), '%', ''),
    'corrected'
FROM raw.world_bank_data
WHERE BTRIM(unemployment_rate) ~ '^[0-9]+([.][0-9]+)?%$'

UNION ALL

-- Currency formatting: remove $ and commas
SELECT
    raw_record_id,
    'gdp_usd',
    'numeric_format_standardized',
    gdp_usd,
    REPLACE(REPLACE(BTRIM(gdp_usd), '$', ''), ',', ''),
    'corrected'
FROM raw.world_bank_data
WHERE BTRIM(gdp_usd) ~ '^[$][0-9,]+([.][0-9]+)?$'

ON CONFLICT (raw_record_id, column_name, issue_type) DO NOTHING;


-- Verify the corrections
SELECT
    raw_record_id,
    column_name,
    original_value,
    cleaned_value
FROM audit.data_quality_log
WHERE issue_type = 'numeric_format_standardized'
ORDER BY raw_record_id;


-- 
-- 7. Log numeric values that must become NULL
-- 

INSERT INTO audit.data_quality_log (
    raw_record_id,
    column_name,
    issue_type,
    original_value,
    cleaned_value,
    action_taken
)
SELECT
    r.raw_record_id,
    v.column_name,
    CASE
        WHEN NULLIF(BTRIM(v.raw_value), '') IS NULL
            THEN 'missing_numeric_value'
        ELSE 'invalid_numeric_value'
    END,
    v.raw_value,
    NULL,
    'set_to_null'
FROM raw.world_bank_data r
CROSS JOIN LATERAL (
    VALUES
        ('gdp_usd', r.gdp_usd),
        ('population', r.population),
        ('life_expectancy', r.life_expectancy),
        ('unemployment_rate', r.unemployment_rate),
        ('co2_emissions_per_capita', r.co2_emissions_per_capita),
        ('access_to_electricity_pct', r.access_to_electricity_pct)
) AS v(column_name, raw_value)
WHERE NULLIF(BTRIM(v.raw_value), '') IS NULL
   OR (
        BTRIM(v.raw_value) !~ '^-?[0-9]+([.][0-9]+)?$'
        AND BTRIM(v.raw_value) !~ '^[0-9]+,[0-9]+$'
        AND BTRIM(v.raw_value) !~ '^[0-9]+([.][0-9]+)?%$'
        AND BTRIM(v.raw_value) !~ '^[$][0-9,]+([.][0-9]+)?$'
   )
ON CONFLICT (raw_record_id, column_name, issue_type) DO NOTHING;


-- Verify the results
SELECT
    raw_record_id,
    column_name,
    COALESCE(
        NULLIF(BTRIM(original_value), ''),
        '[missing]'
    ) AS original_value,
    issue_type
FROM audit.data_quality_log
WHERE issue_type IN (
    'missing_numeric_value',
    'invalid_numeric_value'
)
ORDER BY raw_record_id, column_name;


-- 
-- 8. Log numeric values outside acceptable ranges
-- 

INSERT INTO audit.data_quality_log (
    raw_record_id,
    column_name,
    issue_type,
    original_value,
    cleaned_value,
    action_taken
)
SELECT
    r.raw_record_id,
    v.column_name,
    'numeric_out_of_range',
    v.raw_value,
    NULL,
    'set_to_null'
FROM raw.world_bank_data r
CROSS JOIN LATERAL (
    VALUES
        ('gdp_usd', r.gdp_usd, 0::NUMERIC, NULL::NUMERIC),
        ('population', r.population, 0, NULL),
        ('life_expectancy', r.life_expectancy, 0, 120),
        ('unemployment_rate', r.unemployment_rate, 0, 100),
        ('co2_emissions_per_capita',
            r.co2_emissions_per_capita, 0, NULL),
        ('access_to_electricity_pct',
            r.access_to_electricity_pct, 0, 100)
) AS v(column_name, raw_value, min_value, max_value)
WHERE CASE
    WHEN BTRIM(v.raw_value) ~ '^-?[0-9]+([.][0-9]+)?$'
    THEN
        BTRIM(v.raw_value)::NUMERIC < v.min_value
        OR (
            v.max_value IS NOT NULL
            AND BTRIM(v.raw_value)::NUMERIC > v.max_value
        )
    ELSE FALSE
END
ON CONFLICT (raw_record_id, column_name, issue_type) DO NOTHING;


-- Verify the results
SELECT
    raw_record_id,
    column_name,
    original_value
FROM audit.data_quality_log
WHERE issue_type = 'numeric_out_of_range'
ORDER BY raw_record_id;


-- 
-- 9. Log duplicate records to exclude
-- Newest source wins; lowest raw ID breaks ties
-- 

WITH ranked_records AS (
    SELECT
        r.*,
        ROW_NUMBER() OVER (
            PARTITION BY
                UPPER(BTRIM(r.country_code)),
                BTRIM(r.year)
            ORDER BY
                BTRIM(r.source_file) DESC,
                r.raw_record_id
        ) AS duplicate_rank
    FROM raw.world_bank_data r
    WHERE NOT EXISTS (
        SELECT 1
        FROM audit.data_quality_log q
        WHERE q.raw_record_id = r.raw_record_id
          AND q.action_taken = 'quarantined'
    )
)

INSERT INTO audit.data_quality_log (
    raw_record_id,
    column_name,
    issue_type,
    original_value,
    cleaned_value,
    action_taken
)
SELECT
    raw_record_id,
    'row',
    'duplicate_country_year',
    CONCAT_WS(
        ' | ',
        BTRIM(country_code),
        BTRIM(year),
        BTRIM(source_file)
    ),
    NULL,
    'excluded_duplicate'
FROM ranked_records
WHERE duplicate_rank > 1
ON CONFLICT (raw_record_id, column_name, issue_type) DO NOTHING;


-- Verify excluded duplicates
SELECT
    q.raw_record_id,
    r.country_code,
    r.country_name,
    r.year,
    r.source_file,
    q.action_taken
FROM audit.data_quality_log q
JOIN raw.world_bank_data r
    ON r.raw_record_id = q.raw_record_id
WHERE q.issue_type = 'duplicate_country_year'
ORDER BY q.raw_record_id;


-- 
-- 10. Create a reusable numeric-cleaning function
-- 

CREATE OR REPLACE FUNCTION staging.clean_numeric(
    raw_value TEXT,
    min_value NUMERIC DEFAULT NULL,
    max_value NUMERIC DEFAULT NULL
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    cleaned_value TEXT := BTRIM(raw_value);
    numeric_value NUMERIC;
BEGIN
    IF cleaned_value IS NULL OR cleaned_value = '' THEN
        RETURN NULL;
    END IF;

    -- Remove supported formatting
    IF LEFT(cleaned_value, 1) = '$' THEN
        cleaned_value :=
            REPLACE(REPLACE(cleaned_value, '$', ''), ',', '');
    ELSIF RIGHT(cleaned_value, 1) = '%' THEN
        cleaned_value := REPLACE(cleaned_value, '%', '');
    ELSIF cleaned_value ~ '^-?[0-9]+,[0-9]+$' THEN
        cleaned_value := REPLACE(cleaned_value, ',', '.');
    END IF;

    -- Reject remaining text values
    IF cleaned_value !~ '^-?[0-9]+([.][0-9]+)?$' THEN
        RETURN NULL;
    END IF;

    numeric_value := cleaned_value::NUMERIC;

    -- Reject values outside the allowed range
    IF (min_value IS NOT NULL AND numeric_value < min_value)
       OR (max_value IS NOT NULL AND numeric_value > max_value)
    THEN
        RETURN NULL;
    END IF;

    RETURN numeric_value;
END;
$$;


-- Test the function
SELECT
    staging.clean_numeric('7,86', 0, NULL) AS decimal_comma,
    staging.clean_numeric('6.14%', 0, 100) AS percentage,
    staging.clean_numeric('$1,234.50', 0, NULL) AS currency,
    staging.clean_numeric('unknown', 0, 120) AS invalid_text,
    staging.clean_numeric('652.0', 0, 100) AS out_of_range;


--
-- 11. Log the Korea population correction
--

BEGIN;

INSERT INTO audit.data_quality_log (
    raw_record_id,
    column_name,
    issue_type,
    original_value,
    cleaned_value,
    action_taken
)
SELECT
    raw_record_id,
    'population',
    'population_scale_corrected',
    BTRIM(population),
    '51484000',
    'corrected'
FROM raw.world_bank_data
WHERE raw_record_id = 159
ON CONFLICT (raw_record_id, column_name, issue_type)
DO UPDATE SET
    original_value = EXCLUDED.original_value,
    cleaned_value = EXCLUDED.cleaned_value,
    action_taken = EXCLUDED.action_taken;


-- Correct the two documented source defects without changing raw values.
-- BRA-2022: the generator divided life expectancy by 10.
-- MEX-2023: GDP is expressed in millions of USD, rounded to two decimals.
-- Source: docs/dirt_manifest.csv and scripts/generate_dataset.py.
INSERT INTO audit.data_quality_log (
    raw_record_id, column_name, issue_type,
    original_value, cleaned_value, action_taken
)
SELECT
    r.raw_record_id, fix.column_name, fix.issue_type,
    fix.original_value, fix.cleaned_value, 'corrected'
FROM raw.world_bank_data r
JOIN (
    VALUES
        ('BRA', '2022', 'life_expectancy', 'life_expectancy_decimal_corrected',
         '7.5', '75.0'),
        ('MEX', '2023', 'gdp_usd', 'gdp_unit_corrected',
         '1815091.26', '1815091260000.00')
) AS fix(country_code, year, column_name, issue_type, original_value, cleaned_value)
    ON UPPER(BTRIM(r.country_code)) = fix.country_code
   AND BTRIM(r.year) = fix.year
   AND BTRIM(CASE fix.column_name
       WHEN 'life_expectancy' THEN r.life_expectancy
       WHEN 'gdp_usd' THEN r.gdp_usd
   END) = fix.original_value
ON CONFLICT (raw_record_id, column_name, issue_type)
DO UPDATE SET
    original_value = EXCLUDED.original_value,
    cleaned_value = EXCLUDED.cleaned_value,
    action_taken = EXCLUDED.action_taken;


-- 
-- 12. Load the cleaned staging table
-- 

TRUNCATE TABLE staging.world_bank_data_clean;

INSERT INTO staging.world_bank_data_clean (
    raw_record_id,
    country_code,
    country_name,
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
    ingested_at,
    pipeline_loaded_at
)
SELECT
    r.raw_record_id,
    c.country_code,
    c.country_name,
    c.region,
    c.income_group,
    COALESCE(
        year_fix.cleaned_value,
        BTRIM(r.year)
    )::SMALLINT,
    staging.clean_numeric(COALESCE(gdp_fix.cleaned_value, r.gdp_usd), 0),
    staging.clean_numeric(
        COALESCE(population_fix.cleaned_value, r.population),
        0
    )::BIGINT,
    staging.clean_numeric(
        COALESCE(life_expectancy_fix.cleaned_value, r.life_expectancy), 0, 120
    ),
    staging.clean_numeric(r.unemployment_rate, 0, 100),
    staging.clean_numeric(r.co2_emissions_per_capita, 0),
    staging.clean_numeric(r.access_to_electricity_pct, 0, 100),
    BTRIM(r.source_file),
    BTRIM(r.ingested_at)::TIMESTAMP,
    r.pipeline_loaded_at
FROM raw.world_bank_data r

LEFT JOIN audit.data_quality_log code_fix
    ON code_fix.raw_record_id = r.raw_record_id
   AND code_fix.issue_type = 'country_code_standardized'

LEFT JOIN audit.data_quality_log year_fix
    ON year_fix.raw_record_id = r.raw_record_id
   AND year_fix.issue_type = 'year_format_standardized'

LEFT JOIN audit.data_quality_log population_fix
    ON population_fix.raw_record_id = r.raw_record_id
   AND population_fix.issue_type = 'population_scale_corrected'

LEFT JOIN audit.data_quality_log gdp_fix
    ON gdp_fix.raw_record_id = r.raw_record_id
   AND gdp_fix.column_name = 'gdp_usd'
   AND gdp_fix.issue_type = 'gdp_unit_corrected'

LEFT JOIN audit.data_quality_log life_expectancy_fix
    ON life_expectancy_fix.raw_record_id = r.raw_record_id
   AND life_expectancy_fix.column_name = 'life_expectancy'
   AND life_expectancy_fix.issue_type = 'life_expectancy_decimal_corrected'

JOIN reference.country_reference c
    ON c.country_code = COALESCE(
        code_fix.cleaned_value,
        UPPER(BTRIM(r.country_code))
    )

WHERE NOT EXISTS (
    SELECT 1
    FROM audit.data_quality_log excluded
    WHERE excluded.raw_record_id = r.raw_record_id
      AND excluded.action_taken IN (
          'quarantined',
          'excluded_duplicate'
      )
);

COMMIT;


-- Verify the staging load
SELECT
    COUNT(*) AS cleaned_row_count,
    COUNT(DISTINCT (country_code, year)) AS unique_country_years
FROM staging.world_bank_data_clean;


-- Verify the Korea population correction
SELECT
    raw_record_id,
    country_code,
    country_name,
    year,
    population,
    ROUND(
        gdp_usd / NULLIF(population, 0),
        2
    ) AS gdp_per_capita
FROM staging.world_bank_data_clean
WHERE country_code = 'KOR'
  AND year = 2018;


-- Verify the audit entry
SELECT
    raw_record_id,
    column_name,
    issue_type,
    original_value,
    cleaned_value,
    action_taken
FROM audit.data_quality_log
WHERE issue_type = 'population_scale_corrected';


-- 
-- 13. Final cleaning verification
-- 

SELECT
    (SELECT COUNT(*) FROM raw.world_bank_data) AS raw_rows,
    (
        SELECT COUNT(*)
        FROM staging.world_bank_data_clean
    ) AS cleaned_rows,
    (
        SELECT COUNT(DISTINCT raw_record_id)
        FROM audit.data_quality_log
        WHERE action_taken = 'quarantined'
    ) AS quarantined_rows,
    (
        SELECT COUNT(DISTINCT raw_record_id)
        FROM audit.data_quality_log
        WHERE action_taken = 'excluded_duplicate'
    ) AS excluded_duplicates;


-- Confirm that no duplicates remain
SELECT
    country_code,
    year,
    COUNT(*) AS duplicate_count
FROM staging.world_bank_data_clean
GROUP BY country_code, year
HAVING COUNT(*) > 1;