-- Apply the two documented scale corrections to an existing PostgreSQL build.
-- Open in pgAdmin connected to world_bank_analytics and run the whole file.
-- Raw data remains unchanged. The transaction stops on unexpected inputs.
-- Safe to rerun: corrections use the existing audit uniqueness constraint.
-- Persistent rebuild logic is also saved in 05_data_cleaning.sql.

BEGIN;

CREATE TEMP TABLE expected_scale_fixes (
    country_code TEXT,
    year SMALLINT,
    column_name TEXT,
    issue_type TEXT,
    raw_value TEXT,
    old_clean_value NUMERIC,
    new_clean_value NUMERIC
) ON COMMIT DROP;

INSERT INTO expected_scale_fixes VALUES
    ('BRA', 2022, 'life_expectancy', 'life_expectancy_decimal_corrected',
     '7.5', 7.5, 75.0),
    ('MEX', 2023, 'gdp_usd', 'gdp_unit_corrected',
     '1815091.26', 1815091.26, 1815091260000.00);

-- Lock only the target staging records while applying the correction.
SELECT s.raw_record_id
FROM staging.world_bank_data_clean s
JOIN expected_scale_fixes e USING (country_code, year)
FOR UPDATE OF s;

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM raw.world_bank_data) <> 729
       OR (SELECT COUNT(*) FROM staging.world_bank_data_clean) <> 718 THEN
        RAISE EXCEPTION 'Unexpected dataset counts; stop and review before applying these fixes';
    END IF;

    IF (SELECT COUNT(*)
        FROM expected_scale_fixes e
        JOIN staging.world_bank_data_clean s USING (country_code, year)
        JOIN raw.world_bank_data r ON r.raw_record_id = s.raw_record_id
        WHERE UPPER(BTRIM(r.country_code)) = e.country_code
          AND BTRIM(r.year) = e.year::TEXT
          AND BTRIM(CASE e.column_name WHEN 'life_expectancy'
              THEN r.life_expectancy ELSE r.gdp_usd END) = e.raw_value
          AND CASE e.column_name WHEN 'life_expectancy'
              THEN s.life_expectancy ELSE s.gdp_usd END
              IN (e.old_clean_value, e.new_clean_value)) <> 2 THEN
        RAISE EXCEPTION 'Target records differ from the documented source; no correction applied';
    END IF;
END;
$$;

INSERT INTO audit.data_quality_log (
    raw_record_id, column_name, issue_type,
    original_value, cleaned_value, action_taken
)
SELECT s.raw_record_id, e.column_name, e.issue_type,
       e.raw_value, e.new_clean_value::TEXT, 'corrected'
FROM expected_scale_fixes e
JOIN staging.world_bank_data_clean s USING (country_code, year)
ON CONFLICT (raw_record_id, column_name, issue_type)
DO UPDATE SET original_value = EXCLUDED.original_value,
              cleaned_value = EXCLUDED.cleaned_value,
              action_taken = EXCLUDED.action_taken;

UPDATE staging.world_bank_data_clean s
SET life_expectancy = e.new_clean_value,
    cleaned_at = CURRENT_TIMESTAMP
FROM expected_scale_fixes e
WHERE s.country_code = e.country_code AND s.year = e.year
  AND e.column_name = 'life_expectancy'
  AND s.life_expectancy IS DISTINCT FROM e.new_clean_value;

UPDATE staging.world_bank_data_clean s
SET gdp_usd = e.new_clean_value,
    cleaned_at = CURRENT_TIMESTAMP
FROM expected_scale_fixes e
WHERE s.country_code = e.country_code AND s.year = e.year
  AND e.column_name = 'gdp_usd'
  AND s.gdp_usd IS DISTINCT FROM e.new_clean_value;

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM expected_scale_fixes e
        JOIN staging.world_bank_data_clean s USING (country_code, year)
        JOIN audit.data_quality_log a
          ON a.raw_record_id = s.raw_record_id
         AND a.column_name = e.column_name AND a.issue_type = e.issue_type
        WHERE CASE e.column_name WHEN 'life_expectancy'
            THEN s.life_expectancy ELSE s.gdp_usd END = e.new_clean_value
          AND (CASE WHEN a.cleaned_value ~ '^-?[0-9]+([.][0-9]+)?$' THEN a.cleaned_value::NUMERIC END) = e.new_clean_value
          AND a.action_taken = 'corrected') <> 2 THEN
        RAISE EXCEPTION 'Correction validation failed; transaction must roll back';
    END IF;
END;
$$;

COMMIT;

SELECT country_code, year, life_expectancy, gdp_usd, gdp_per_capita
FROM analytics.world_bank_indicators
WHERE (country_code = 'BRA' AND year = 2022)
   OR (country_code = 'MEX' AND year = 2023)
ORDER BY country_code;

SELECT
    (SELECT COUNT(*) FROM raw.world_bank_data) AS raw_rows,
    (SELECT COUNT(*) FROM staging.world_bank_data_clean) AS cleaned_rows,
    (SELECT COUNT(DISTINCT raw_record_id) FROM audit.data_quality_log
     WHERE action_taken = 'quarantined') AS quarantined_rows,
    (SELECT COUNT(DISTINCT raw_record_id) FROM audit.data_quality_log
     WHERE action_taken = 'excluded_duplicate') AS excluded_duplicates;

-- Next: run 06_data_validation.sql and 08_sql_analysis.sql.
-- If this script fails inside BEGIN/COMMIT, run ROLLBACK before continuing.
