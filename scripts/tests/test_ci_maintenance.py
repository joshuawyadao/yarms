"""Fast checks for conservative CI selection and opt-in local pruning."""

import importlib.util
import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path

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
