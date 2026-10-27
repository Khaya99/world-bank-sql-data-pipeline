"""Download a fresh 2000-2023 snapshot, then run the logged PostgreSQL refresh."""

import argparse
from datetime import datetime, timezone
from pathlib import Path
import subprocess
import sys
import csv
import tempfile

def export_analysis(repo, psql, host, port, user, database):
    report = (
        repo / "data" / "processed"
        / "electricity_life_expectancy_changes_2000_2023.csv"
    )
    export_sql = repo / "sql" / "17_export_official_analysis.sql"
    report.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = None

    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            dir=report.parent,
            suffix=".tmp",
            delete=False,
        ) as temporary:
            temporary_path = Path(temporary.name)
            subprocess.run(
                [
                    str(psql), "-X", "-q",
                    "-h", host, "-p", str(port),
                    "-U", user, "-d", database, "-w",
                    "-v", "ON_ERROR_STOP=1",
                    "-f", str(export_sql),
                ],
                cwd=repo,
                stdout=temporary,
                check=True,
            )

        with temporary_path.open(
            encoding="utf-8", newline=""
        ) as exported:
            reader = csv.DictReader(exported)
            expected_columns = [
                "country_name",
                "country_code",
                "electricity_change_pp",
                "life_expectancy_change_years",
            ]
            if reader.fieldnames != expected_columns:
                raise RuntimeError("Unexpected report CSV columns.")
            rows = list(reader)

        if len(rows) != 30 or len({row["country_code"] for row in rows}) != 30:
            raise RuntimeError("Expected 30 unique countries in the report.")

        temporary_path.replace(report)
        print(f"Analysis CSV updated: {report}", flush=True)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)

def run_pipeline(repo, psql, host, port, user, database):
    extractor = repo / "scripts/fetch_worldbank.py"
    refresh = repo / "sql/13_refresh_and_upsert_worldbank.sql"
    helper = repo / "sql/maintenance/log_refresh_failure.sql"
    for required in (psql, extractor, refresh, helper):
        if not required.is_file():
            raise FileNotFoundError(f"Required file not found: {required}")

    # A unique folder prevents a failed extraction from reusing an old CSV.
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d_%H%M%S_%fZ")
    snapshot = repo / "data/official" / stamp
    snapshot.mkdir(parents=True, exist_ok=False)
    csv_path = snapshot / "world_bank_indicators.csv"
    print(f"1/2: Downloading the snapshot to {snapshot}", flush=True)
    try:
        subprocess.run(
            [sys.executable, "-B", str(extractor), "--start", "2000",
             "--end", "2023", "--out", str(csv_path)],
            cwd=repo, check=True,
        )
    except subprocess.CalledProcessError as error:
        print("Extraction failed; database refresh was not started.", file=sys.stderr)
        return error.returncode or 1

    if not csv_path.is_file() or csv_path.stat().st_size == 0:
        raise RuntimeError("Extraction produced no usable CSV; database refresh was not started.")

    # SQL performs the content validation and commits or rolls back the refresh.
    print("2/2: Loading this snapshot using saved PostgreSQL credentials.", flush=True)
    try:
        subprocess.run(
            [str(psql), "-X", "-h", host, "-p", str(port), "-U", user,
             "-d", database, "-w", "-v", f"snapshot_dir={snapshot.as_posix()}",
             "-f", str(refresh)],
            cwd=repo, check=True,
        )
    except subprocess.CalledProcessError as error:
        print("Database refresh failed. Inspect the terminal errors and pipeline_runs.", file=sys.stderr)
        return error.returncode or 1

    try:
        export_analysis(repo, psql, host, port, user, database)
    except subprocess.CalledProcessError as error:
        print(
            "Database refresh succeeded, but the report export failed. "
            "The previous report CSV was preserved.",
            file=sys.stderr,
        )
        return error.returncode or 1
    except (OSError, RuntimeError, UnicodeError, csv.Error) as error:
        print(
            f"Database refresh succeeded, but the report export failed: {error}",
            file=sys.stderr,
        )
        return 1

    print(f"Pipeline completed. Snapshot: {csv_path}", flush=True)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--psql", type=Path, default=Path("C:/Program Files/PostgreSQL/18/bin/psql.exe"))
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--user", default="postgres")
    parser.add_argument("--database", default="world_bank_analytics")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    try:
        return run_pipeline(repo, args.psql.resolve(), args.host, args.port, args.user, args.database)
    except (OSError, RuntimeError) as error:
        print(f"Pipeline stopped: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Pipeline interrupted. Check the last run before restarting.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
