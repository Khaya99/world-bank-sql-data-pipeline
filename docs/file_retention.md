# Log and snapshot retention

Cleanup is optional. Existing scheduled tasks keep their current behaviour until
`--cleanup-old-files` is added to the pipeline command.

## Policy

- Logs: older than 90 days, with the newest three matching logs always retained.
- Snapshots: older than 180 days, with the newest three matching folders retained.
- Age comes from the UTC timestamp in the generated name, not modification time.
- Committed files are preserved. Git must be installed and available to the task;
  a failed Git check stops cleanup before any removal.
- Only `logs/pipeline_YYYYMMDDTHHMMSS_microsecondsZ.log` and generated
  `data/official/YYYY-MM-DD_HHMMSS_microsecondsZ/` folders are considered.
- A snapshot folder must contain only `world_bank_indicators.csv`. Unexpected
  files, nested directories, symlinks and Windows junctions are skipped.
- Database rows, processed reports, source files and credentials are outside scope.

## Preview first

From the repository root in PowerShell:

```powershell
python scripts/cleanup_pipeline_files.py
```

This prints candidates without removing them. No candidates is a normal result
when the pipeline is new. Retained newest files are not necessarily successful
snapshots; retention uses age and names, not data quality or pipeline status.

## Apply manually

Back up any history you need. The following command permanently removes the
eligible files; it does not move them to the Recycle Bin:

```powershell
python scripts/cleanup_pipeline_files.py --apply
```

Run cleanup while no other pipeline instance or file-management operation is
running. Preview and apply each recalculate candidates. Keep the repository and
its output directories under the control of your own account.

## Optional automatic cleanup

After reviewing the preview, append `--cleanup-old-files` to the existing
pipeline arguments in Task Scheduler (keep your other arguments intact):

```powershell
python scripts/run_worldbank_pipeline.py --cleanup-old-files
```

Cleanup runs only after pipeline success. Failed runs retain their files for
investigation. Cleanup errors are logged and do not change the pipeline exit
code or send a pipeline failure email; inspect the log for cleanup errors.
Remove the flag to disable automatic cleanup.

## Offline checks

```powershell
python -m unittest discover -s tests -p "test_pipeline*.py" -v
```

The 18 tests cover orchestration, email alerts and retention. Retention tests use
disposable temporary files, never the real snapshots. Windows symlink testing
may be skipped when the account cannot create symlinks. CI runs on Windows;
local development verification may run on another operating system.
