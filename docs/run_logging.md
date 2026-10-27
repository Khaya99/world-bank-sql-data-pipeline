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

## Choosing a snapshot

Script 13 accepts `-v snapshot_dir="C:/path/to/snapshot/folder"` on the psql
command line. The folder must contain `world_bank_indicators.csv` for the same
30 countries and 2000-2023 period. It defaults to the local
`data/official/2026-10-22_001046` snapshot when the variable is omitted.

The script changes psql's client directory before starting the refresh and reads
the CSV from there. Helper includes remain relative to the SQL script. An invalid
directory stops before a run entry is created. This parameter only selects an
existing download; it does not fetch fresh API data.

## Download and refresh with one command

From the repository root:

```powershell
.\.venv\Scripts\python.exe scripts/run_worldbank_pipeline.py
```

The runner uses that same Python environment for the extractor, which requires
`pandas` and `requests`. It creates a unique UTC-stamped snapshot directory,
downloads the fixed 2000-2023 period, and passes that directory to script 13.
An extraction error or absent/empty output stops before PostgreSQL is invoked.
SQL retains responsibility for validating all row contents and coverage.

The runner uses psql's lowercase `-w` option, so authentication fails instead
of waiting for a password prompt. On Windows, configure the matching connection
in `%APPDATA%\postgresql\pgpass.conf` under the Windows account running the
pipeline. Keep that plaintext credential file outside this repository and do
not commit it. The runner itself does not store a password.

The runner does not retry whole pipeline runs. The extractor's existing request
retries remain unchanged. A monthly Windows task is configured and its on-demand
execution has been verified. See [task settings and verification](monthly_schedule.md).

The database log still covers only the refresh step. Extraction errors appear
in the terminal and do not create a database run entry. Downloaded files are
retained for inspection, including partial files when extraction fails.

The one-command flow was verified with a fresh API download: database run 8
completed successfully with 720 staging rows and 720 typed rows. Five offline
runner tests also passed, covering extraction failures, missing output, exact
snapshot selection, database exit-code propagation, and missing psql.

After switching to noninteractive authentication, the five offline tests passed
again and database run 9 succeeded with 720 rows in each table, without a password
prompt.

Run the offline orchestration tests with:

```powershell
.\.venv\Scripts\python.exe -B -m unittest discover -s tests -p test_pipeline_runner.py
```

## Automatic analysis CSV export

After a successful PostgreSQL refresh, the Python runner automatically exports the electricity-access and life-expectancy changes for 2000–2023 to the report CSV.

The export uses UTF-8 encoding and checks the expected column names and 30 unique countries before replacing the previous CSV. A test verifies that a failed export preserves the previous report and removes its temporary file.

The updated runner was verified with database refresh run 12 and an overall exit code of 0. The database run log records the database refresh; report-export failures are reported separately through the runner’s error message and exit code.

The Tableau workbook and GitHub dashboard image remain saved snapshots and require separate updates.
