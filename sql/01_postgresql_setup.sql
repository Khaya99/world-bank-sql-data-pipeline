-- World Bank SQL Data Pipeline
-- PostgreSQL schema setup

BEGIN;

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS reference;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS analytics;

COMMENT ON SCHEMA raw IS
    'Immutable source data loaded as received.';

COMMENT ON SCHEMA reference IS
    'Reference data used to validate and standardise records.';

COMMENT ON SCHEMA staging IS
    'Cleaned and correctly typed country-level data.';

COMMENT ON SCHEMA audit IS
    'Excluded records and their data-quality reasons.';

COMMENT ON SCHEMA analytics IS
    'Analysis-ready views and tables used for SQL, Tableau, and later applications.';

COMMIT;

-- Verify that all five schemas exist
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN (
    'raw',
    'reference',
    'staging',
    'audit',
    'analytics'
)
ORDER BY schema_name;