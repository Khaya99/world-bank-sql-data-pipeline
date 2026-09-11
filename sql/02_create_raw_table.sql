-- World Bank SQL Data Pipeline
-- PostgreSQL raw-layer table

-- Source values remain as TEXT so malformed values can be loaded, ingested and cleaned downstream


BEGIN;

CREATE TABLE IF NOT EXISTS raw.world_bank_data (
    raw_record_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    country_name TEXT,
    country_code TEXT,
    region TEXT,
    income_group TEXT,
    year TEXT,
    gdp_usd TEXT,
    population TEXT,
    life_expectancy TEXT,
    unemployment_rate TEXT,
    co2_emissions_per_capita TEXT,
    access_to_electricity_pct TEXT,
    source_file TEXT,
    ingested_at TEXT,

    pipeline_loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE raw.world_bank_data IS
    'Immutable raw World Bank-style records loaded without cleaning or type conversion.';

COMMENT ON COLUMN raw.world_bank_data.raw_record_id IS
    'PostgreSQL-generated identifier used to trace each source record.';

COMMENT ON COLUMN raw.world_bank_data.ingested_at IS
    'Original source-provided ingestion timestamp preserved as text.';

COMMENT ON COLUMN raw.world_bank_data.pipeline_loaded_at IS
    'Timestamp when the record was loaded into this PostgreSQL pipeline.';

COMMIT;

-- Verify the table structure
SELECT
    ordinal_position,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'raw'
  AND table_name = 'world_bank_data'
ORDER BY ordinal_position;