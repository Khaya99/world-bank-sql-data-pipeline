-- World Bank SQL Data Pipeline
-- PostgreSQL country-reference table

-- Contains approved country-level entities only.
-- Aggregates such as WLD and EUU are intentionally excluded.

BEGIN;

CREATE TABLE IF NOT EXISTS reference.country_reference (
    country_code TEXT PRIMARY KEY,
    country_name TEXT NOT NULL UNIQUE,
    region TEXT NOT NULL,
    income_group TEXT NOT NULL,
    reference_loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT country_reference_code_format
        CHECK (country_code ~ '^[A-Z]{3}$')
);

COMMENT ON TABLE reference.country_reference IS
    'Approved country-level reference data; aggregate entities are excluded.';

COMMENT ON COLUMN reference.country_reference.reference_loaded_at IS
    'Timestamp when the reference record was loaded into PostgreSQL.';

COMMIT;

-- Verify the table structure
SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'reference'
  AND table_name = 'country_reference'
ORDER BY ordinal_position;


-- Verify imported reference data
SELECT
    COUNT(*) AS reference_row_count,
    COUNT(DISTINCT country_code) AS unique_country_codes,
    COUNT(DISTINCT country_name) AS unique_country_names,
    COUNT(*) FILTER (
        WHERE reference_loaded_at IS NULL
    ) AS missing_load_timestamps
FROM reference.country_reference;