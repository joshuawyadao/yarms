#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

cd "$PROJECT_ROOT"

PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote

root = Path.cwd()
required = (
    "README.md",
    "LICENSE",
    "CODE_OF_CONDUCT.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    ".gitignore",
    ".github/ISSUE_TEMPLATE/bug_report.yml",
    ".github/ISSUE_TEMPLATE/feature_request.yml",
    ".github/ISSUE_TEMPLATE/config.yml",
    ".github/pull_request_template.md",
    ".github/workflows/ci.yml",
)
errors = [f"Missing {name}" for name in required if not (root / name).is_file()]

files = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"]
).decode().split("\0")
for name in filter(None, files):
    path = Path(name)
    lower = name.lower()
    if lower.endswith((".p8", ".p12", ".pem", ".key", ".mobileprovision", ".sqlite", ".sqlite3", ".db", ".mp4", ".mov")):
        errors.append(f"Private or generated file present: {name}")
    if path.suffix != ".md":
        continue
    text = (root / path).read_text(encoding="utf-8")
    for target in re.findall(r"(?<!!)\[[^]]+\]\(([^)]+)\)", text):
        target = target.split("#", 1)[0]
        if not target or target.startswith(("https://", "http://", "mailto:")):
            continue
        resolved = root / path.parent / unquote(target)
        if not resolved.exists():
            errors.append(f"Broken local link in {name}: {target}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    raise SystemExit(1)
print("Public repository files and local links: OK")
PY

git diff --check
git diff --cached --check
printf 'Yarms repository verification: OK\n'
