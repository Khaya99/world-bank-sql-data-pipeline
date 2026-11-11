"""Retention checks using disposable files only."""
from datetime import datetime, timezone
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
from scripts import cleanup_pipeline_files as retention
from scripts import run_worldbank_pipeline as runner


class RetentionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.now = datetime(2027, 1, 1, tzinfo=timezone.utc)
        patcher = patch.object(retention.subprocess, 'run', return_value=Mock(stdout=''))
        self.git = patcher.start()
        self.addCleanup(patcher.stop)
        self.logs = []
        self.snapshots = []
        for day in range(1, 6):
            log = self.repo / 'logs' / f'pipeline_2026010{day}T000000_000000Z.log'
            log.parent.mkdir(exist_ok=True)
            log.write_text('log')
            self.logs.append(log)
            folder = self.repo / 'data/official' / f'2026-01-0{day}_000000_000000Z'
            folder.mkdir(parents=True)
            (folder / 'world_bank_indicators.csv').write_text('csv')
            self.snapshots.append(folder)

    def test_preview_changes_nothing(self):
        self.assertEqual(len(retention.candidates(self.repo, self.now)), 4)
        retention.cleanup(self.repo, now=self.now)
        self.assertTrue(all(p.exists() for p in self.logs + self.snapshots))

    def test_apply_preserves_newest_three(self):
        retention.cleanup(self.repo, apply=True, now=self.now)
        self.assertFalse(self.logs[0].exists())
        self.assertFalse(self.snapshots[0].exists())
        self.assertTrue(all(p.exists() for p in self.logs[2:] + self.snapshots[2:]))

    def test_recent_files_are_retained(self):
        self.assertEqual(retention.candidates(self.repo, datetime(2026, 2, 1, tzinfo=timezone.utc)), [])

    def test_unknown_contents_and_tracked_snapshots_are_preserved(self):
        (self.snapshots[0] / 'notes.txt').write_text('keep')
        relative = (self.snapshots[1] / 'world_bank_indicators.csv').relative_to(self.repo)
        self.git.return_value.stdout = relative.as_posix() + '\0'
        retention.cleanup(self.repo, apply=True, now=self.now)
        self.assertTrue(all(p.exists() for p in self.snapshots))

    def test_git_failure_prevents_cleanup(self):
        self.git.side_effect = OSError('no git')
        with self.assertRaises(OSError):
            retention.cleanup(self.repo, apply=True, now=self.now)
        self.assertTrue(all(p.exists() for p in self.logs))

    def test_symlink_is_preserved(self):
        self.logs[0].unlink()
        target = self.repo / 'keep.txt'
        target.write_text('keep')
        try:
            self.logs[0].symlink_to(target)
        except OSError:
            self.skipTest('Symlinks unavailable for this Windows account')
        retention.cleanup(self.repo, apply=True, now=self.now)
        self.assertEqual(target.read_text(), 'keep')
        self.assertTrue(self.logs[0].is_symlink())

    def test_pipeline_cleanup_only_on_success_and_opt_in(self):
        for flag, code, expected in [(False, 0, False), (True, 3, False), (True, 0, True)]:
            with self.subTest(flag=flag, code=code), patch.object(runner, 'setup_logging', return_value=(Mock(), Path('log'))), patch.object(runner, 'run_pipeline', return_value=code), patch.object(runner, 'send_email'), patch.object(runner.logging, 'shutdown'), patch.object(runner, 'cleanup') as clean, patch.object(runner.sys, 'argv', ['runner'] + (['--cleanup-old-files'] if flag else [])):
                self.assertEqual(runner.main(), code)
                self.assertEqual(clean.called, expected)

    def test_cleanup_failure_preserves_success_code(self):
        with patch.object(runner, 'setup_logging', return_value=(Mock(), Path('log'))), patch.object(runner, 'run_pipeline', return_value=0), patch.object(runner.logging, 'shutdown'), patch.object(runner, 'cleanup', side_effect=OSError('locked')), patch.object(runner.sys, 'argv', ['runner', '--cleanup-old-files']):
            self.assertEqual(runner.main(), 0)
