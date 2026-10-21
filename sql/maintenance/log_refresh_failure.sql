-- Included immediately after each refresh statement by script 13.
-- The start log is already committed; failure is saved after rollback.
\if :ERROR
    -- Set before recovery so even a logging error stops the caller.
    \set refresh_failed true
    \set failure_message :LAST_ERROR_MESSAGE
    \set ON_ERROR_STOP on
    ROLLBACK;

    UPDATE worldbank.pipeline_runs
    SET status = 'failed',
        finished_at = clock_timestamp(),
        error_message = :'failure_message'
    WHERE run_id = :logged_run_id
      AND status = 'running';

\endif
