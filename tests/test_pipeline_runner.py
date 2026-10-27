"""Offline checks for orchestration; no API requests or database writes."""

import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts/run_worldbank_pipeline.py"
spec = importlib.util.spec_from_file_location("runner", MODULE_PATH)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


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
        with patch.object(runner.subprocess, "run", side_effect=fail) as process:
            self.assertEqual(self.run_pipeline(), 1)
            self.assertEqual(process.call_count, 1)

    def test_missing_csv_never_starts_database(self):
        with patch.object(runner.subprocess, "run") as process:
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

        def execute(command, **kwargs):
            if "--out" in command:
                self.write_csv(command)
            elif "stdout" in kwargs:
                kwargs["stdout"].write(report_csv.encode("utf-8"))

        with patch.object(
            runner.subprocess, "run", side_effect=execute
        ) as process:
            self.assertEqual(self.run_pipeline(), 0)
            self.assertEqual(process.call_count, 3)

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

    def test_database_failure_is_propagated_without_retry(self):
        def execute(command, **kwargs):
            if "--out" in command:
                self.write_csv(command)
            else:
                raise subprocess.CalledProcessError(3, command)
        with patch.object(runner.subprocess, "run", side_effect=execute) as process:
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
            runner.subprocess, "run", side_effect=execute
        ) as process:
            self.assertEqual(self.run_pipeline(), 3)
            self.assertEqual(process.call_count, 3)

        self.assertEqual(len(reports), 1)
        self.assertEqual(reports[0].read_bytes(), original)
        self.assertEqual(list(reports[0].parent.glob("*.tmp")), [])

    def test_missing_psql_stops_before_any_download(self):
        self.psql.unlink()
        with patch.object(runner.subprocess, "run") as process:
            with self.assertRaises(FileNotFoundError):
                self.run_pipeline()
            process.assert_not_called()


if __name__ == "__main__":
    unittest.main()
