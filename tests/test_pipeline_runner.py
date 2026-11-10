"""Offline checks for orchestration and alerts; no external services."""

from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

from scripts import run_worldbank_pipeline as runner


class PipelineRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.psql = self.repo / "psql.exe"
        for relative in ("psql.exe", "scripts/fetch_worldbank.py",
                         "sql/13_refresh_and_upsert_worldbank.sql",
                         "sql/maintenance/log_refresh_failure.sql"):
            path = self.repo / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()

    def run_pipeline(self):
        return runner.run_pipeline(self.repo, self.psql, "localhost", 5432,
                                   "postgres", "world_bank_analytics")

    @staticmethod
    def write_csv(command, **kwargs):
        path = Path(command[command.index("--out") + 1])
        path.write_text("country_code,year\nZAF,2023\n", encoding="utf-8")

    def test_failed_extraction_never_starts_database_even_with_partial_csv(self):
        def fail(command, **kwargs):
            self.write_csv(command)
            raise subprocess.CalledProcessError(1, command)
        with patch.object(runner, "run_logged", side_effect=fail) as process:
            self.assertEqual(self.run_pipeline(), 1)
            self.assertEqual(process.call_count, 1)

    def test_missing_csv_never_starts_database(self):
        with patch.object(runner, "run_logged") as process:
            with self.assertRaisesRegex(RuntimeError, "no usable CSV"):
                self.run_pipeline()
            self.assertEqual(process.call_count, 1)

    def test_success_passes_exact_new_snapshot_and_uses_same_python(self):
        report_csv = (
            "country_name,country_code,electricity_change_pp,"
            "life_expectancy_change_years\n"
            + "".join(
                f"Test country {i},T{i:02d},10.00,5.00\n"
                for i in range(30)
            )
        )

        comparison_csv = (
            "country_name,country_code,year,"
            "gdp_per_capita_current_usd,life_expectancy_years,"
            "access_to_electricity_pct\n"
            + "".join(
                f"Test country {i},T{i:02d},2023,5000.00,70.00,90.00\n"
                for i in range(30)
            )
        )

        def execute(command, **kwargs):
            if "--out" in command:
                self.write_csv(command)
            elif "stdout" in kwargs:
                sql_name = Path(command[command.index("-f") + 1]).name
                if sql_name == "17_export_official_analysis.sql":
                    output = report_csv
                elif sql_name == "18_export_development_comparison.sql":
                    output = comparison_csv
                else:
                    raise AssertionError(f"Unexpected export: {sql_name}")
                kwargs["stdout"].write(output.encode("utf-8"))

        with patch.object(
            runner, "run_logged", side_effect=execute
        ) as process:
            self.assertEqual(self.run_pipeline(), 0)
            self.assertEqual(process.call_count, 4)

            extract = process.call_args_list[0].args[0]
            load = process.call_args_list[1].args[0]
            export_call = process.call_args_list[2]
            export = export_call.args[0]

            self.assertEqual(extract[0], runner.sys.executable)
            csv_path = Path(extract[extract.index("--out") + 1])
            self.assertIn(
                f"snapshot_dir={csv_path.parent.as_posix()}", load
            )
            self.assertIn("-w", load)
            self.assertIn("-w", export)
            self.assertIn("ON_ERROR_STOP=1", export)
            self.assertEqual(
                Path(export[export.index("-f") + 1]).name,
                "17_export_official_analysis.sql",
            )

            report = (
                Path(export_call.kwargs["cwd"])
                / "data" / "processed"
                / "electricity_life_expectancy_changes_2000_2023.csv"
            )
            self.assertEqual(report.read_text(encoding="utf-8"), report_csv)
            self.assertEqual(list(report.parent.glob("*.tmp")), [])

            comparison_call = process.call_args_list[3]
            comparison_command = comparison_call.args[0]

            self.assertIn("-w", comparison_command)
            self.assertIn("ON_ERROR_STOP=1", comparison_command)
            self.assertEqual(
                Path(
                    comparison_command[comparison_command.index("-f") + 1]
                ).name,
                "18_export_development_comparison.sql",
            )

            comparison_report = (
                Path(comparison_call.kwargs["cwd"])
                / "data"
                / "processed"
                / "development_comparison_2023.csv"
            )
            self.assertEqual(
                comparison_report.read_text(encoding="utf-8"),
                comparison_csv,
            )
            self.assertEqual(
                list(comparison_report.parent.glob("*.tmp")),
                [],
            )

    def test_database_failure_is_propagated_without_retry(self):
        def execute(command, **kwargs):
            if "--out" in command:
                self.write_csv(command)
            else:
                raise subprocess.CalledProcessError(3, command)
        with patch.object(runner, "run_logged", side_effect=execute) as process:
            self.assertEqual(self.run_pipeline(), 3)
            self.assertEqual(process.call_count, 2)
    def test_failed_export_preserves_previous_report(self):
        reports = []
        original = b"previous report contents\n"

        def execute(command, **kwargs):
            if "--out" in command:
                self.write_csv(command)
                report = (
                    Path(kwargs["cwd"])
                    / "data" / "processed"
                    / "electricity_life_expectancy_changes_2000_2023.csv"
                )
                report.parent.mkdir(parents=True, exist_ok=True)
                report.write_bytes(original)
                reports.append(report)
            elif "stdout" in kwargs:
                kwargs["stdout"].write(b"partial export\n")
                raise subprocess.CalledProcessError(3, command)

        with patch.object(
            runner, "run_logged", side_effect=execute
        ) as process:
            self.assertEqual(self.run_pipeline(), 3)
            self.assertEqual(process.call_count, 3)

        self.assertEqual(len(reports), 1)
        self.assertEqual(reports[0].read_bytes(), original)
        self.assertEqual(list(reports[0].parent.glob("*.tmp")), [])

    def test_missing_psql_stops_before_any_download(self):
        self.psql.unlink()
        with patch.object(runner, "run_logged") as process:
            with self.assertRaises(FileNotFoundError):
                self.run_pipeline()
            process.assert_not_called()

class PipelineAlertTests(unittest.TestCase):
    def setUp(self):
        # A fake logger records messages without creating log files.
        self.logger = Mock()
        self.log_path = Path("test-logs") / "pipeline_test.log"

        # Replace external work before each test.
        # addCleanup restores the real functions after each test,
        # even when a test fails.
        replacements = {
            "setup_logging": {
                "return_value": (self.logger, self.log_path)
            },
            "run_pipeline": {"return_value": 0},
            "send_email": {},
        }

        for name, options in replacements.items():
            patcher = patch.object(runner, name, **options)
            fake = patcher.start()
            self.addCleanup(patcher.stop)
            setattr(self, name, fake)

        # Prevent argparse from reading unittest's command arguments.
        argv_patch = patch.object(
            runner.sys, "argv", ["run_worldbank_pipeline.py"]
        )
        argv_patch.start()
        self.addCleanup(argv_patch.stop)

        # Avoid closing other log handlers during the tests.
        shutdown_patch = patch.object(runner.logging, "shutdown")
        shutdown_patch.start()
        self.addCleanup(shutdown_patch.stop)

    def assert_failure_email(self, expected_code):
        # Exactly one attempt should be made.
        self.send_email.assert_called_once()

        subject, body = self.send_email.call_args.args
        self.assertEqual(
            subject, "World Bank Pipeline - Failure Alert"
        )
        self.assertIn(f"Exit code: {expected_code}\n", body)
        self.assertIn(str(self.log_path), body)

    def test_success_does_not_send_failure_email(self):
        # Simulate a successful pipeline.
        self.run_pipeline.return_value = 0

        result = runner.main()

        self.assertEqual(result, 0)
        self.run_pipeline.assert_called_once()
        self.send_email.assert_not_called()

    def test_pipeline_failure_sends_one_email(self):
        # Use 3 to check that the actual failure code is preserved.
        self.run_pipeline.return_value = 3

        result = runner.main()

        self.assertEqual(result, 3)
        self.assert_failure_email(3)

    def test_email_failure_preserves_pipeline_failure_code(self):
        self.run_pipeline.return_value = 3

        # Simulate Gmail being unreachable without contacting it.
        self.send_email.side_effect = OSError("Simulated network failure")

        result = runner.main()

        self.assertEqual(result, 3)
        self.assert_failure_email(3)
        self.logger.error.assert_any_call(
            "Could not send failure alert | error_type=%s",
            "OSError",
        )

    def test_unexpected_pipeline_error_sends_failure_email(self):
        # This covers errors like the missing-psql test you ran manually.
        self.run_pipeline.side_effect = FileNotFoundError(
            "Simulated missing executable"
        )

        result = runner.main()

        self.assertEqual(result, 1)
        self.assert_failure_email(1)
        self.logger.exception.assert_called_once_with(
            "Pipeline stopped because of an unexpected error"
        )

if __name__ == "__main__":
    unittest.main()
