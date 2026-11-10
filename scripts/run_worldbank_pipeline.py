"""Download a fresh 2000-2023 snapshot, then run the logged PostgreSQL refresh."""

import argparse
from datetime import datetime, timezone
from pathlib import Path
import subprocess
import sys
import csv
import tempfile
import logging
import time

# Support both running the script directly and importing it in tests.
if __package__:
    from .gmail_alerts import send_email
else:
    from gmail_alerts import send_email

def setup_logging(repo):
    log_directory = repo / "logs"
    log_directory.mkdir(parents=True, exist_ok=True)

    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S_%fZ")
    log_path = log_directory / f"pipeline_{run_id}.log"

    logger = logging.getLogger("worldbank_pipeline")
    logger.setLevel(logging.INFO)
    logger.propagate = False

    # Avoid duplicate messages if setup is called again.
    for handler in list(logger.handlers):
        logger.removeHandler(handler)
        handler.close()

    formatter = logging.Formatter(
        "%(asctime)s UTC | %(levelname)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    formatter.converter = time.gmtime

    file_handler = logging.FileHandler(log_path, encoding="utf-8")
    file_handler.setFormatter(formatter)

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)

    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    logger.info("Logging started | run_id=%s", run_id)
    return logger, log_path

def run_logged(command, *, cwd, stage, stdout=None):
    logger = logging.getLogger("worldbank_pipeline")
    started = time.perf_counter()
    logger.info("Stage started | stage=%s", stage)

    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            stdout=stdout if stdout is not None else subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )

        # When stdout is a CSV file, leave its contents out of the log.
        if stdout is None and result.stdout:
            for line in result.stdout.splitlines():
                logger.info("[%s stdout] %s", stage, line)

        if result.stderr:
            for line in result.stderr.splitlines():
                logger.warning("[%s stderr] %s", stage, line)

        result.check_returncode()

    except Exception:
        logger.exception("Stage failed | stage=%s", stage)
        raise

    logger.info(
        "Stage succeeded | stage=%s | duration_seconds=%.2f",
        stage,
        time.perf_counter() - started,
    )
    return result

def export_analysis(
    repo, psql, host, port, user, database,
    *,
    report_filename="electricity_life_expectancy_changes_2000_2023.csv",
    sql_filename="17_export_official_analysis.sql",
    expected_columns=None,
        logger = logging.getLogger("worldbank_pipeline")
):
    report = repo / "data" / "processed" / report_filename
    export_sql = repo / "sql" / sql_filename
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
            run_logged(
                [
                    str(psql), "-X", "-q",
                    "-h", host, "-p", str(port),
                    "-U", user, "-d", database, "-w",
                    "-v", "ON_ERROR_STOP=1",
                    "-f", str(export_sql),
                ],
                cwd=repo,
                stdout=temporary,
                stage=f"export:{report_filename}",
            )

        with temporary_path.open(encoding="utf-8", newline="") as exported:
            reader = csv.DictReader(exported)
            if expected_columns is None:
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
        logger.info("Report validated and published | path=%s", report)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)

def run_pipeline(repo, psql, host, port, user, database):
    logger = logging.getLogger("worldbank_pipeline")
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
    logger.info("Downloading snapshot | path=%s", snapshot)
    try:
                run_logged(
            [sys.executable, "-B", str(extractor), "--start", "2000",
             "--end", "2023", "--out", str(csv_path)],
            cwd=repo,
            stage="extraction",
        )
    except subprocess.CalledProcessError as error:
        logger.error("Extraction failed; database refresh was not started.")
        return error.returncode or 1

    if not csv_path.is_file() or csv_path.stat().st_size == 0:
        raise RuntimeError("Extraction produced no usable CSV; database refresh was not started.")

    # SQL performs the content validation and commits or rolls back the refresh.
    logger.info("Validating and loading snapshot into PostgreSQL")
    try:
        run_logged(
            [str(psql), "-X", "-h", host, "-p", str(port), "-U", user,
             "-d", database, "-w", "-v", f"snapshot_dir={snapshot.as_posix()}",
             "-f", str(refresh)],
            cwd=repo,
            stage="database_refresh",
        )
    except subprocess.CalledProcessError as error:
        logger.error("Database refresh failed. Inspect this log and pipeline_runs.")
        return error.returncode or 1

    try:
        export_analysis(repo, psql, host, port, user, database)
        export_analysis(
            repo, psql, host, port, user, database,
            report_filename="development_comparison_2023.csv",
            sql_filename="18_export_development_comparison.sql",
            expected_columns=[
                "country_name",
                "country_code",
                "year",
                "gdp_per_capita_current_usd",
                "life_expectancy_years",
                "access_to_electricity_pct",
            ],
        )
    except subprocess.CalledProcessError as error:
        logger.exception(
            "Database refresh succeeded, but a report export failed. "
            "Reports published earlier in this run may already be updated."
        )
        return error.returncode or 1
    except (OSError, RuntimeError, UnicodeError, csv.Error):
        logger.exception(
            "Database refresh succeeded, but a report export failed. "
            "Reports published earlier in this run may already be updated."
        )
        return 1

    logger.info("Pipeline completed | snapshot=%s", csv_path)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--psql",
        type=Path,
        default=Path("C:/Program Files/PostgreSQL/18/bin/psql.exe"),
    )
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--user", default="postgres")
    parser.add_argument("--database", default="world_bank_analytics")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    logger, log_path = setup_logging(repo)
    started = time.perf_counter()

    logger.info("Pipeline started")
    logger.info("Log file: %s", log_path)

    exit_code = 1

    try:
        exit_code = run_pipeline(
            repo,
            args.psql.resolve(),
            args.host,
            args.port,
            args.user,
            args.database,
        )
    except KeyboardInterrupt:
        logger.warning(
            "Pipeline interrupted. Check the last run before restarting."
        )
        exit_code = 130
    except Exception:
        logger.exception("Pipeline stopped because of an unexpected error")
        exit_code = 1
    finally:
        elapsed = time.perf_counter() - started

        if exit_code == 0:
            logger.info("Pipeline succeeded | duration_seconds=%.2f", elapsed)
        else:
            logger.error(
                "Pipeline failed or interrupted | exit_code=%s | "
                "duration_seconds=%.2f",
                exit_code,
                elapsed,
            )

        # Send one email if the pipeline failed or was interrupted.
        if exit_code != 0:
            try:
                send_email(
                    "World Bank Pipeline - Failure Alert",
                    (
                        "Your World Bank pipeline did not finish successfully.\n\n"
                        f"Exit code: {exit_code}\n"
                        f"Duration: {elapsed:.2f} seconds\n"
                        f"Log file on your laptop: {log_path}\n\n"
                        "Open the log file to investigate the problem."
                    ),
                )
                logger.info("Failure alert accepted by Gmail")

            except Exception as alert_error:
                # An email problem must not replace the pipeline's exit code.
                # Log only the error type, without exposing credentials.
                logger.error(
                    "Could not send failure alert | error_type=%s",
                    type(alert_error).__name__,
                )

        # Close the log handlers after attempting the email.
        logging.shutdown()

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
