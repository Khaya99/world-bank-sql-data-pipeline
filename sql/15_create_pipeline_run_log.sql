-- Record the outcome of each pipeline execution.
CREATE TABLE worldbank.pipeline_runs (
    run_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pipeline_name TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    finished_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'running'
        CHECK (status IN ('running', 'succeeded', 'failed')),
    staging_rows BIGINT CHECK (staging_rows >= 0),
    typed_rows BIGINT CHECK (typed_rows >= 0),
    error_message TEXT
);

-- View the most recent runs.
SELECT *
FROM worldbank.pipeline_runs
ORDER BY run_id DESC
LIMIT 10;