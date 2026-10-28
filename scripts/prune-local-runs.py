#!/usr/bin/env python3
"""Preview old successful local evidence; opt in to removal with --apply."""

import argparse
import json
import re
import shutil
import time
from pathlib import Path

from xcode_support import ROOT


def candidates(root, kind, days, keep, include_failures=False, include_archives=False, now=None):
    root = Path(root)
    if root.is_symlink() or not root.is_dir():
        return []
    entries = []
    for child in root.iterdir():
        if child.is_symlink() or not child.is_dir():
            continue
        if kind == "test-runs":
            owned_name = re.fullmatch(r"\d{8}T\d{6}Z-[0-9a-f]{32}", child.name)
        else:
            owned_name = re.fullmatch(
                r"(?:check-|\d+\.\d+\.\d+-[1-9]\d*-)"
                r"\d{8}T\d{6}Z-[0-9a-f]{8}", child.name)
        if not owned_name:
            continue
        report = child / "report.json"
        if report.is_symlink() or not report.is_file():
            continue
        try:
            data = json.loads(report.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if data.get("status") not in ("passed", "failed"):
            continue
        if data["status"] == "failed" and not include_failures:
            continue
        if kind == "releases" and data.get("mode") == "archive" and not include_archives:
            continue
        entries.append((child.stat().st_mtime, child))
    entries.sort(reverse=True)
    cutoff = (time.time() if now is None else now) - days * 86400
    return [path for index, (modified, path) in enumerate(entries)
            if index >= keep and modified < cutoff]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="delete selected owned runs")
    parser.add_argument("--days", type=int, default=14)
    parser.add_argument("--keep", type=int, default=5)
    parser.add_argument("--include-failures", action="store_true")
    parser.add_argument("--include-archives", action="store_true")
    args = parser.parse_args(argv)
    if args.days < 0 or args.keep < 0:
        parser.error("--days and --keep must be nonnegative")
    base = ROOT / ".build"
    if base.is_symlink():
        parser.error("refusing a symlinked .build directory")
    for kind in ("test-runs", "releases"):
        root = base / kind
        for path in candidates(root, kind, args.days, args.keep,
                               args.include_failures, args.include_archives):
            # Recheck ownership before deletion in case a path changed after enumeration.
            if path.parent != root or path.is_symlink() or not path.is_dir():
                continue
            print(f"{'remove' if args.apply else 'would remove'} {path}")
            if args.apply:
                shutil.rmtree(path)


if __name__ == "__main__":
    main()
