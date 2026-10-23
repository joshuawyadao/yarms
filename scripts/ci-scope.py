#!/usr/bin/env python3
"""Conservatively skip macOS work for pull requests changing only prose docs."""

import os
import re
import subprocess
import sys


def classify(event, base, head, diff=None):
    if event != "pull_request":
        return True
    if not all(re.fullmatch(r"[0-9a-fA-F]{40}", value or "") for value in (base, head)):
        return True
    if diff is None:
        try:
            diff = subprocess.check_output(
                ["git", "diff", "--name-only", "-z", f"{base}...{head}"],
                stderr=subprocess.DEVNULL, timeout=30,
            )
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            return True
    try:
        paths = [name.decode("utf-8") for name in diff.split(b"\0") if name]
    except UnicodeDecodeError:
        return True
    # Empty or unrecognized changes fail toward the full check.
    if not paths:
        return True
    return not all(path.startswith("docs/") and path.endswith(".md")
                   or path in ("README.md", "CONTRIBUTING.md")
                   for path in paths)


if __name__ == "__main__":
    full = classify(os.getenv("EVENT_NAME"), os.getenv("BASE_SHA"), os.getenv("HEAD_SHA"))
    sys.stdout.write(f"full={'true' if full else 'false'}\n")
