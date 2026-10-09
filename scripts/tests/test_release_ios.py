"""Release gate tests with synthetic Xcode settings and bundle products."""

import importlib.util
import json
import plistlib
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("release_ios", SCRIPTS / "release-ios.py")
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


def settings(target, derived, *, version="1.0", build="1", team="", group=None):
    return {"CONFIGURATION": "Release", "PRODUCT_BUNDLE_IDENTIFIER":
            release.APP_ID if target == "Yarms" else release.SHARE_ID,
            "MARKETING_VERSION": version, "CURRENT_PROJECT_VERSION": build,
            "DEVELOPMENT_TEAM": team, "CODE_SIGN_STYLE": "Automatic",
            "ENABLE_TESTABILITY": "NO", "SWIFT_OPTIMIZATION_LEVEL": "-O",
            "YARMS_KEYCHAIN_GROUP": group or release.SHARED_GROUP_SUFFIX,
            "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
            "TARGET_BUILD_DIR": str(derived / "Build" / "Products" / "Release-iphonesimulator"),
            "FULL_PRODUCT_NAME": "Yarms.app", "APPLICATION_EXTENSION_API_ONLY": "YES",
            "SKIP_INSTALL": "YES"}


def make_bundle(app, *, version, build, marker=None, bad_share=False):
    share = app / "PlugIns" / "YarmsShare.appex"
    share.mkdir(parents=True)
    for path, bundle_id, executable in ((app, release.APP_ID, "Yarms"),
                                        (share, release.SHARE_ID if not bad_share else "wrong.share", "YarmsShare")):
        info = {"CFBundleIdentifier": bundle_id, "CFBundleShortVersionString": version,
                "CFBundleVersion": build, "MinimumOSVersion": "18.0",
                "CFBundleExecutable": executable}
        if path == share:
            info["NSExtension"] = {"NSExtensionPointIdentifier": "com.apple.share-services"}
        with (path / "Info.plist").open("wb") as handle:
            plistlib.dump(info, handle)
        (path / executable).write_bytes(b"MachO release payload" + (marker or b""))


class FakeExecutor:
    def __init__(self, *, team="", bad_share=False, marker=None, build_failure=False,
                 signed=True, settings_mutator=None, timeout=False, interrupt=False,
                 default_group=True, test_bundle=False):
        self.commands = []
        self.team = team
        self.bad_share = bad_share
        self.marker = marker
        self.build_failure = build_failure
        self.signed = signed
        self.settings_mutator = settings_mutator
        self.timeout = timeout
        self.interrupt = interrupt
        self.default_group = default_group
        self.test_bundle = test_bundle

    def run(self, command, timeout, log=None):
        self.commands.append(list(command))
        if command[:3] == ["git", "rev-parse", "HEAD"]:
            return 0, "a" * 40 + "\n"
        if command[:3] == ["git", "status", "--porcelain"]:
            return 0, " M files\n"
        if command[0] == "xcodebuild":
            if "-derivedDataPath" in command:
                self.derived = Path(command[command.index("-derivedDataPath") + 1])
            derived = self.derived
            version = next((x.split("=", 1)[1] for x in command if x.startswith("MARKETING_VERSION=")), "1.0")
            build = next((x.split("=", 1)[1] for x in command if x.startswith("CURRENT_PROJECT_VERSION=")), "1")
            if "-showBuildSettings" in command:
                target = command[command.index("-target") + 1] if "-target" in command else "Yarms"
                values = settings(target, derived, version=version, build=build, team=self.team)
                if self.settings_mutator:
                    self.settings_mutator(target, values)
                return 0, json.dumps([{"target": target,
                                       "buildSettings": values}])
            if log:
                Path(log).write_text("synthetic xcodebuild log\n")
            if self.timeout:
                raise release.CommandTimeout("synthetic timeout")
            if self.interrupt:
                raise release.InterruptedRun("synthetic interrupt")
            if self.build_failure:
                return 65, "build failure"
            if "archive" in command:
                root = Path(command[command.index("-archivePath") + 1])
                app = root / "Products" / "Applications" / "Yarms.app"
                root.mkdir(parents=True)
                with (root / "Info.plist").open("wb") as handle:
                    plistlib.dump({"ApplicationProperties": {"ApplicationPath": "Applications/Yarms.app"}}, handle)
            else:
                app = derived / "Build" / "Products" / "Release-iphonesimulator" / "Yarms.app"
            make_bundle(app, version=version, build=build, bad_share=self.bad_share, marker=self.marker)
            if self.test_bundle:
                (app / "PlugIns" / "YarmsShare.appex" / "Injected.xctest").mkdir()
            return 0, ""
        if command[0] == "codesign":
            if not self.signed:
                return 1, "invalid signature"
            bundle = release.SHARE_ID if command[-1].endswith(".appex") else release.APP_ID
            if "--verify" in command:
                return 0, ""
            if "-dv" in command:
                return 0, f"Identifier={bundle}\nTeamIdentifier={self.team}\n"
            if "--entitlements" in command:
                plist = {"application-identifier": f"{self.team}.{bundle}",
                         "keychain-access-groups": (["WRONG.default"] if not self.default_group else [])
                         + [f"{self.team}.{release.SHARED_GROUP_SUFFIX}"]}
                return 0, plistlib.dumps(plist).decode("utf-8")
        raise AssertionError(command)


class ReleaseCLITests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_check_builds_unsigned_release_and_retains_report(self):
        fake = FakeExecutor()
        args = release.parse_args(["check"])
        report = release.execute(args, fake, self.root)
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["signing"]["status"], "unchecked")
        self.assertFalse(report["signing"]["distribution_ready"])
        self.assertTrue(Path(report["run_directory"], "report.json").is_file())
        self.assertTrue(Path(report["log"]).is_file())
        self.assertFalse((Path(report["run_directory"]) / "DerivedData").exists())
        xcodes = [c for c in fake.commands if c[0] == "xcodebuild"]
        self.assertEqual(len([c for c in xcodes if "-showBuildSettings" in c]), 2)
        share_query = [c for c in xcodes if "-target" in c][0]
        self.assertNotIn("-destination", share_query)
        self.assertNotIn("-derivedDataPath", share_query)
        self.assertEqual(share_query[share_query.index("-sdk") + 1], "iphonesimulator")
        self.assertEqual([c[-1] for c in xcodes if c[-1] == "build"], ["build"])
        self.assertIn("CODE_SIGNING_ALLOWED=NO", xcodes[-1])
        self.assertNotIn("simctl", str(fake.commands))

    def test_archive_uses_cli_versions_and_verifies_both_signatures(self):
        fake = FakeExecutor(team="UNBNJA6WRF")
        args = release.parse_args(["archive", "--version", "1.2.3", "--build-number", "7",
                                   "--team", "UNBNJA6WRF"])
        report = release.execute(args, fake, self.root)
        self.assertEqual(report["status"], "passed", report["error"])
        self.assertEqual(report["signing"]["status"], "verified")
        self.assertFalse(report["signing"]["distribution_ready"])
        self.assertEqual(set(report["signing"]["targets"]), {"app", "share_extension"})
        self.assertTrue(Path(report["artifact"]["archive"]).is_dir())
        self.assertFalse((Path(report["run_directory"]) / "DerivedData").exists())
        build_command = [c for c in fake.commands if c and c[-1] == "archive"][0]
        share_query = [c for c in fake.commands if "-target" in c][0]
        self.assertEqual(share_query[share_query.index("-sdk") + 1], "iphoneos")
        self.assertIn("MARKETING_VERSION=1.2.3", build_command)
        self.assertIn("CURRENT_PROJECT_VERSION=7", build_command)
        self.assertIn("DEVELOPMENT_TEAM=UNBNJA6WRF", build_command)
        self.assertFalse(any(x.startswith("SKIP_INSTALL=") for x in build_command))
        self.assertFalse(any(x == "-allowProvisioningUpdates" for x in build_command))

    def test_unsigned_archive_states_limit_explicitly(self):
        report = release.execute(release.parse_args(["archive", "--version", "1.0.0",
                                                      "--build-number", "2", "--unsigned"]),
                                 FakeExecutor(), self.root)
        self.assertEqual(report["status"], "passed", report["error"])
        self.assertEqual(report["signing"]["status"], "unchecked")
        self.assertIn("not distribution-ready", Path(report["run_directory"], "release-notes.md").read_text())

    def test_rejects_debug_settings_and_mismatched_versions(self):
        args = release.parse_args(["check"])
        derived = self.root / "DerivedData"
        both = {name: settings(name, derived) for name in ("Yarms", "YarmsShare")}
        both["Yarms"]["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
        with self.assertRaisesRegex(release.RunError, "DEBUG"):
            release.validate_settings(both, args)
        both["Yarms"].pop("SWIFT_ACTIVE_COMPILATION_CONDITIONS")
        both["YarmsShare"]["CURRENT_PROJECT_VERSION"] = "2"
        with self.assertRaisesRegex(release.RunError, "CURRENT_PROJECT_VERSION"):
            release.validate_settings(both, args)

    def test_rejects_release_flags_that_restore_testability_or_debug_optimization(self):
        args = release.parse_args(["check"])
        for flag in ("-enable-testing", "-Onone"):
            with self.subTest(flag=flag):
                both = {name: settings(name, self.root / "DerivedData")
                        for name in ("Yarms", "YarmsShare")}
                both["YarmsShare"]["OTHER_SWIFT_FLAGS"] = "$(inherited) " + flag
                with self.assertRaisesRegex(release.RunError, "testability or unoptimized"):
                    release.validate_settings(both, args)

    def test_rejects_share_metadata_and_debug_sentinel(self):
        for fake, expected in ((FakeExecutor(bad_share=True), "CFBundleIdentifier"),
                               (FakeExecutor(marker=b"-YarmsUITestStoreID"), "debug-only"),
                               (FakeExecutor(test_bundle=True), "test bundle")):
            with self.subTest(expected=expected):
                report = release.execute(release.parse_args(["check"]), fake, self.root)
                self.assertEqual(report["status"], "failed")
                self.assertIn(expected, report["error"])
                self.assertTrue(Path(report["run_directory"], "report.json").is_file())

    def test_xcode_failure_keeps_failure_report_and_log(self):
        report = release.execute(release.parse_args(["check"]), FakeExecutor(build_failure=True), self.root)
        self.assertEqual(report["status"], "failed")
        self.assertIn("exited 65", report["error"])
        self.assertTrue(Path(report["log"]).exists())

    def test_early_configuration_failure_keeps_readable_failure_report(self):
        report = release.execute(release.parse_args(["archive", "--version", "1.0.0",
                                                      "--build-number", "2"]),
                                 FakeExecutor(), self.root)
        self.assertEqual(report["status"], "failed")
        self.assertIn("pass --team", report["error"])
        notes = Path(report["run_directory"], "release-notes.md").read_text()
        self.assertIn("Release validation: failed", notes)
        self.assertEqual(json.loads(Path(report["run_directory"], "report.json").read_text())["status"],
                         "failed")

    def test_timeout_and_interrupt_keep_failure_report(self):
        for fake, expected in ((FakeExecutor(timeout=True), "timeout"),
                               (FakeExecutor(interrupt=True), "interrupt")):
            with self.subTest(expected=expected):
                report = release.execute(release.parse_args(["check"]), fake, self.root)
                self.assertEqual(report["status"], "failed")
                self.assertIn(expected, report["error"])
                self.assertFalse((Path(report["run_directory"]) / "DerivedData").exists())

    def test_signed_archive_requires_valid_default_shared_group(self):
        args = release.parse_args(["archive", "--version", "1.0.0", "--build-number", "2",
                                   "--team", "UNBNJA6WRF"])
        report = release.execute(args, FakeExecutor(team="UNBNJA6WRF", default_group=False), self.root)
        self.assertEqual(report["status"], "failed")
        self.assertIn("default resolved shared Keychain", report["error"])

    def test_inconsistent_effective_signing_team_fails_before_build(self):
        def mutate(target, values):
            if target == "YarmsShare":
                values["DEVELOPMENT_TEAM"] = "OTHERTEAM1"
        fake = FakeExecutor(team="UNBNJA6WRF", settings_mutator=mutate)
        args = release.parse_args(["archive", "--version", "1.0.0", "--build-number", "2",
                                   "--team", "UNBNJA6WRF"])
        report = release.execute(args, fake, self.root)
        self.assertEqual(report["status"], "failed")
        self.assertIn("DEVELOPMENT_TEAM", report["error"])
        self.assertFalse(any(command[-1] == "archive" for command in fake.commands))

    def test_bad_archive_inputs_are_rejected_before_build(self):
        for option in (["--version", "1.0", "--build-number", "2"],
                       ["--version", "1.0.0", "--build-number", "0"],
                       ["--version", "1.0.0", "--build-number", "2", "--team", "invalid"]):
            with self.subTest(option=option), self.assertRaises(SystemExit):
                release.parse_args(["archive"] + option)

    def test_xcode_warning_text_around_settings_json_is_accepted(self):
        payload = json.dumps([{"target": "Yarms", "buildSettings": {"CONFIGURATION": "Release"}}])
        actual = release.parse_target_json("[MT] DVT warning\n" + payload + "\nNote: cached SDK\n", "Yarms")
        self.assertEqual(actual[0]["target"], "Yarms")

    def test_duplicate_or_malformed_xcode_settings_json_is_rejected(self):
        payload = json.dumps([{"target": "Yarms", "buildSettings": {"CONFIGURATION": "Release"}}])
        with self.assertRaisesRegex(release.RunError, "ambiguous"):
            release.parse_target_json(payload + "\n" + payload, "Yarms")
        with self.assertRaisesRegex(release.RunError, "invalid"):
            release.parse_target_json("[MT] warning\n[{bad JSON]\n", "Yarms")


if __name__ == "__main__":
    unittest.main()
