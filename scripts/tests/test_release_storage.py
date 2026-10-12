"""Compile the real inbox source to verify UI-test storage stays Debug-only."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SWIFT_SOURCES = [
    ROOT / "YarmsCore" / "TikTokLink.swift",
    ROOT / "YarmsCore" / "SharedInbox.swift",
]

HARNESS = r"""
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 5 else { fatalError("Missing harness arguments") }
let support = URL(fileURLWithPath: arguments[1], isDirectory: true)
let temporary = URL(fileURLWithPath: arguments[2], isDirectory: true)
let buildMode = arguments[3]
let scenario = arguments[4]
let identifier = UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!

let requested = SharedInbox.isUITestStoreRequested
let expectedRequested = buildMode == "debug" && scenario != "normal"
guard requested == expectedRequested else {
    fatalError("UI-test store request was \(requested), expected \(expectedRequested)")
}

let actual = SharedInbox.container(
    arguments: ["Yarms"] + Array(arguments.dropFirst(5)),
    applicationSupport: support,
    temporaryDirectory: temporary
)
let expected: URL?
if buildMode == "debug" && scenario == "valid" {
    expected = temporary
        .appendingPathComponent("YarmsUITests", isDirectory: true)
        .appendingPathComponent(identifier.uuidString, isDirectory: true)
} else if buildMode == "debug" && scenario != "normal" {
    expected = nil
} else {
    expected = support.appendingPathComponent("Yarms", isDirectory: true)
}
guard actual == expected else {
    fatalError("Container was \(String(describing: actual)), expected \(String(describing: expected))")
}
"""


@unittest.skipUnless(shutil.which("swiftc"), "swiftc is unavailable")
class ReleaseStorageTests(unittest.TestCase):
    def test_ui_test_storage_control_is_debug_only(self):
        with tempfile.TemporaryDirectory(prefix="yarms-release-storage-") as directory:
            root = Path(directory)
            harness = root / "main.swift"
            harness.write_text(HARNESS)
            support = root / "support"
            temporary = root / "temporary"
            module_cache = root / "module-cache"
            module_cache.mkdir()
            compiler_environment = os.environ.copy()
            compiler_environment["CLANG_MODULE_CACHE_PATH"] = str(module_cache)
            marker = "-YarmsUITestStoreID"
            identifier = "12345678-1234-1234-1234-123456789abc"
            scenarios = {
                "normal": [],
                "valid": [marker, identifier],
                "invalid": [marker, "invalid"],
                "missing": [marker],
            }

            for mode, compiler_flags in (("debug", ["-D", "DEBUG"]), ("release", ["-O"])):
                with self.subTest(mode=mode):
                    executable = root / mode
                    compile_result = subprocess.run(
                        ["swiftc", *compiler_flags, *map(str, SWIFT_SOURCES), str(harness), "-o", str(executable)],
                        cwd=ROOT,
                        capture_output=True,
                        text=True,
                        timeout=120,
                        env=compiler_environment,
                    )
                    self.assertEqual(compile_result.returncode, 0, compile_result.stderr)

                    for scenario, extra_arguments in scenarios.items():
                        with self.subTest(mode=mode, scenario=scenario):
                            result = subprocess.run(
                                [str(executable), str(support), str(temporary), mode, scenario, *extra_arguments],
                                cwd=root,
                                capture_output=True,
                                text=True,
                                timeout=10,
                            )
                            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
