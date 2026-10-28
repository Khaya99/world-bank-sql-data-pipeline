# Monthly World Bank pipeline schedule

Windows Task Scheduler runs the API-to-PostgreSQL pipeline on the first day of
each month at 09:00 (9 AM) South Africa Standard Time (Africa/Johannesburg, UTC+02:00).
The extraction covers 30 countries and the fixed 2000-2023 period; it refreshes
those observations.

## Task settings

| Setting | Value |
| --- | --- |
| Task name | World Bank Monthly Pipeline |
| User | The Windows account used to configure and test the pipeline |
| Security option | Run only when user is logged on |
| Highest privileges | Unchecked |
| Trigger | Monthly, all months, day 1, 09:00; enabled |
| Run on demand | Enabled |
| Missed start | Run as soon as possible after a scheduled start is missed |
| Automatic task restart on failure | Disabled |
| Maximum runtime | 30 minutes |
| Force stop if the task does not end when requested | Enabled |
| Existing instance | Do not start a new instance |
| Require idle computer | Disabled |
| Start only on AC power | Enabled |
| Wake the computer | Disabled |

The user must be logged in, the computer awake and connected to AC power, and
PostgreSQL and the internet available. The missed-start setting permits catch-up
when the task is eligible; it does not make the computer run while powered off.
The extractor retains its bounded request retries; the scheduler does not retry
the entire pipeline automatically.

## Action

Choose **Start a program** and use these fields for the current installation.
Update the paths if the project is moved.

**Program/script:**

```text
C:\Users\mpume\Downloads\world-bank-sql-data-pipeline\.venv\Scripts\python.exe
```

**Add arguments:**

```text
-B "C:\Users\mpume\Downloads\world-bank-sql-data-pipeline\scripts\run_worldbank_pipeline.py"
```

**Start in** (without quotation marks):

```text
C:\Users\mpume\Downloads\world-bank-sql-data-pipeline
```

The virtual environment needs `pandas` and `requests`. PostgreSQL authentication
uses the task user's `%APPDATA%\postgresql\pgpass.conf`, outside the repository.
The runner uses `-w` so an authentication error fails instead of requesting a
password. Do not put credentials in task arguments or commit the password file.

## Verification

On 22 October 2026, an on-demand launch through Task Scheduler completed with
Last Run Result `0x0`. The corresponding database log showed:

| Field | Observed result |
| --- | --- |
| Run ID | 11 |
| Status | succeeded |
| Start time displayed in pgAdmin | 2026-10-22 09:47:40 |
| Staging rows | 720 |
| Typed rows | 720 |
| Error message | NULL |

This verifies an on-demand execution through Task Scheduler. A future monthly
calendar-triggered execution has not yet been observed.

After a run, compare Task Scheduler's Last Run Time and Last Run Result with the
latest database entry; an older successful entry is not evidence of a new run.

```sql
SELECT run_id, status, started_at, finished_at,
       staging_rows, typed_rows, error_message
FROM worldbank.pipeline_runs
WHERE pipeline_name = 'worldbank_refresh_and_upsert'
ORDER BY run_id DESC
LIMIT 1;
```

## Current limits

The database log covers the refresh step, not extraction. Extraction failures can
occur before any database log entry exists. Task output is not currently captured
in a persistent console log. A forced stop or connection loss may leave a
`running` log entry requiring investigation. See [run logging](run_logging.md).

Snapshots use UTC timestamps in their folder names. Downloads remain on disk;
automatic retention cleanup is not configured. The scheduled task updates local
data and PostgreSQL only: it does not commit or push changes to GitHub.

### Verification after adding the report export

On 28 October 2026, the existing monthly task was started manually through Windows Task Scheduler at 11:56:48. It completed with Last Run Result `0x0`. The report CSV was updated at 11:57:05, and the working Tableau workbook refreshed without an error.

This confirms that an on-demand run of the scheduled task includes the report CSV export. The first calendar-triggered monthly run remains to be verified; the next scheduled run is 1 November 2026 at 09:00 South Africa time.