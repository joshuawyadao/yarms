"""Fast checks for conservative CI selection and opt-in local pruning."""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).resolve().parents[1] / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


scope = load("ci_scope", "ci-scope.py")
prune = load("prune_runs", "prune-local-runs.py")
SHA = "a" * 40


class CIScopeTests(unittest.TestCase):
    def test_docs_only(self):
        self.assertFalse(scope.classify("pull_request", SHA, SHA, b"docs/Development.md\0"))

    def test_unknown_and_source_are_full(self):
        for diff in (b"", b"docs/Guide.md\0YarmsApp/App.swift\0", b"strange\0"):
            self.assertTrue(scope.classify("pull_request", SHA, SHA, diff))
        self.assertTrue(scope.classify("push", SHA, SHA, b"docs/Guide.md\0"))
        self.assertTrue(scope.classify("pull_request", "bad", SHA, b"docs/Guide.md\0"))

    def test_source_renamed_to_docs_requires_full_checks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            def git(*arguments):
                return subprocess.check_output(["git", "-C", str(root), *arguments],
                                               stderr=subprocess.DEVNULL).decode().strip()

            git("init", "--quiet")
            git("config", "user.name", "CI Scope Test")
            git("config", "user.email", "ci-scope@example.invalid")
            git("config", "commit.gpgsign", "false")
            git("config", "core.hooksPath", "/dev/null")
            git("config", "diff.renames", "true")
            (root / "YarmsApp").mkdir()
            (root / "docs").mkdir()
            (root / "YarmsApp" / "Player.swift").write_text("import SwiftUI\nstruct Player {}\n")
            git("add", ".")
            git("commit", "--quiet", "-m", "Add player")
            base = git("rev-parse", "HEAD")
            git("mv", "YarmsApp/Player.swift", "docs/Player.md")
            git("commit", "--quiet", "-m", "Move source into docs")
            head = git("rev-parse", "HEAD")
            self.assertEqual(git("diff", "--name-only", f"{base}...{head}"), "docs/Player.md")
            check_output = subprocess.check_output

            def from_temporary_repository(command, **options):
                return check_output([command[0], "-C", str(root), *command[1:]], **options)

            with mock.patch.object(scope.subprocess, "check_output", from_temporary_repository):
                self.assertTrue(scope.classify("pull_request", base, head))


class PruningTests(unittest.TestCase):
    def test_preserves_recent_failure_archive_and_symlink(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "releases"
            root.mkdir()
            old = time.time() - 30 * 86400
            for name, status, mode in (
                ("check-20260901T000000Z-aaaaaaaa", "passed", "check"),
                ("check-20260902T000000Z-bbbbbbbb", "failed", "check"),
                ("1.0.0-2-20260903T000000Z-cccccccc", "passed", "archive"),
            ):
                child = root / name
                child.mkdir()
                (child / "report.json").write_text(json.dumps({"status": status, "mode": mode}))
                os.utime(child, (old, old))
            (root / "link").symlink_to(root / "check-20260901T000000Z-aaaaaaaa")
            selected = prune.candidates(root, "releases", 14, 0)
            self.assertEqual([path.name for path in selected], ["check-20260901T000000Z-aaaaaaaa"])
            self.assertEqual(len(prune.candidates(root, "releases", 14, 1)), 0)


if __name__ == "__main__":
    unittest.main()
