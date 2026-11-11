"""Preview old pipeline files; use --apply to permanently remove candidates."""

import argparse
from datetime import datetime, timedelta, timezone
import logging
from pathlib import Path
import re
import stat
import subprocess

LOGGER = logging.getLogger("worldbank_pipeline")


def ordinary(path, directory=False):
    """Reject symbolic links and Windows junctions/reparse points."""
    info = path.lstat()
    if stat.S_ISLNK(info.st_mode):
        return False
    if getattr(info, "st_file_attributes", 0) & 0x400:
        return False
    return stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)


def candidates(repo, now=None):
    """Use generated UTC names, never file modification times, to determine age."""
    now = now or datetime.now(timezone.utc)
    # Preserve committed reference snapshots; fail closed if Git is unavailable.
    tracked = subprocess.run(
        ["git", "ls-files", "-z", "--", "logs", "data/official"],
        cwd=repo, check=True, capture_output=True, text=True, timeout=15,
    ).stdout.split("\0")
    protected = {Path(repo) / name for name in tracked if name}
    groups = (
        (Path(repo) / "logs", r"pipeline_(\d{8}T\d{6}_\d{6}Z)\.log",
         "%Y%m%dT%H%M%S_%fZ", 90, False),
        (Path(repo) / "data" / "official", r"(\d{4}-\d{2}-\d{2}_\d{6}_\d{6}Z)",
         "%Y-%m-%d_%H%M%S_%fZ", 180, True),
    )
    result = []
    for folder, pattern, date_format, days, is_directory in groups:
        # Refuse redirected parents as well as redirected entries.
        if not folder.exists() or any(
            not ordinary(parent, directory=True)
            for parent in (folder, *folder.parents)
        ):
            continue
        entries = []
        for path in folder.iterdir():
            match = re.fullmatch(pattern, path.name)
            if not match or not ordinary(path, directory=is_directory):
                continue
            try:
                timestamp = datetime.strptime(match[1], date_format).replace(tzinfo=timezone.utc)
            except ValueError:
                continue
            entries.append((timestamp, path))
        # Retain the three newest matching entries even if they are old.
        for timestamp, path in sorted(entries, reverse=True)[3:]:
            if path in protected or any(path in item.parents for item in protected):
                continue
            if timestamp >= now - timedelta(days=days):
                continue
            if is_directory:
                children = list(path.iterdir())
                # Never recursively delete a directory: only a known snapshot CSV.
                if len(children) != 1 or children[0].name != "world_bank_indicators.csv":
                    continue
                if not ordinary(children[0]):
                    continue
            result.append(path)
    return result


def cleanup(repo, apply=False, now=None):
    """Preview by default; return failures without changing pipeline exit codes."""
    failures = 0
    for path in candidates(repo, now=now):
        LOGGER.info("Cleanup %s | path=%s", "remove" if apply else "preview", path)
        if not apply:
            continue
        try:
            if ordinary(path, directory=True):
                (path / "world_bank_indicators.csv").unlink()
                path.rmdir()
            elif ordinary(path):
                path.unlink()
        except OSError:
            failures += 1
            LOGGER.exception("Cleanup could not remove | path=%s", path)
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Permanently remove eligible files")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s | %(message)s")
    repo = Path(__file__).resolve().parents[1]
    LOGGER.info("Retention: logs 90 days; snapshots 180 days; keep newest three of each")
    failures = cleanup(repo, apply=args.apply)
    LOGGER.info("Cleanup finished | mode=%s | failures=%s", "apply" if args.apply else "preview", failures)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
