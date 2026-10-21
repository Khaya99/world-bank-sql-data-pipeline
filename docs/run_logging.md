# Refresh run logging

Run `sql/15_create_pipeline_run_log.sql` once to create the log table before
running script 13. Run script 13 with psql, not the pgAdmin Query Tool.

Each refresh creates a committed `running` entry. Successful refreshes commit
the data, `succeeded` status, finish time and table row counts together.
The failure helper rolls back a rejected refresh and saves its error separately.
The calling script then raises an error so psql returns exit code 3.

This refresh reads the saved CSV snapshot; its duration does not include an API
download. Interrupted processes or lost connections can leave a `running` entry
requiring investigation. Logging does not yet provide automatic recovery.

## Verified behavior

- A normal refresh logged success with 720 staging and 720 typed rows.
- The failure test injected a 101% unemployment value into the uncommitted batch.
  Validation rejected it, both tables matched their complete pre-test contents,
  the failed log entry retained the validation error, and psql returned code 3.
- A normal refresh after the error-handling correction succeeded again.

Run the test from the repository root in PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\tests\test_worldbank_failure_logging.ps1
```

It prompts for the database password three times and creates a distinctly named
test log entry. It uses a temporary copy of script 13 and does not edit the source
CSV. Avoid concurrent data changes during the comparison. The test covers a
validation failure, not every possible import, database or connection failure.
The executable location and CSV path currently reflect the local Windows setup.
