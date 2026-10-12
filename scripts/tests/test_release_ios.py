"""Release gate tests with synthetic Xcode settings and bundle products."""

import importlib.util
import io
import json
import os
import plistlib
import signal
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock


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
            "CODE_SIGN_ENTITLEMENTS": ("YarmsApp/Yarms.entitlements" if target == "Yarms"
                                       else "YarmsShare/Yarms.entitlements"),
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
                 default_group=True, test_bundle=False, create_derived_data=False):
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
        self.create_derived_data = create_derived_data

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
            if self.create_derived_data:
                derived.mkdir(parents=True, exist_ok=True)
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
        for target in ("YarmsApp", "YarmsShare"):
            directory = self.root / target
            directory.mkdir()
            with (directory / "Yarms.entitlements").open("wb") as handle:
                plistlib.dump({"keychain-access-groups": ["$(YARMS_KEYCHAIN_GROUP)"]}, handle)

    def run_release(self, args, fake):
        return release.execute(args, fake, self.root, source_root=self.root)

    def run_main(self, fake):
        validate = release.validate_settings
        def validate_fixture(settings, args, source_root=release.ROOT):
            return validate(settings, args, self.root)
        output = io.StringIO()
        with mock.patch.object(release, "validate_settings", side_effect=validate_fixture):
            with redirect_stdout(output):
                exit_code = release.main(["check"], fake, self.root)
        return exit_code, json.loads(output.getvalue())

    def assert_interrupted_report(self, result):
        report = json.loads(Path(result["report"]).read_text())
        notes = Path(result["report"]).with_name("release-notes.md").read_text()
        self.assertEqual(report["status"], "failed")
        self.assertEqual(result["status"], "failed")
        self.assertIn("Interrupted by signal", report["error"])
        self.assertIn("Release validation: failed", notes)
        self.assertIn("Interrupted by signal", notes)
        self.assertFalse((Path(report["run_directory"]) / "DerivedData").exists())
        self.assertFalse(report["derived_data_retained"])
        return report, notes

    def test_check_builds_unsigned_release_and_retains_report(self):
        fake = FakeExecutor()
        args = release.parse_args(["check"])
        report = self.run_release(args, fake)
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
        report = self.run_release(args, fake)
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
        report = self.run_release(release.parse_args(["archive", "--version", "1.0.0",
                                                      "--build-number", "2", "--unsigned"]),
                                  FakeExecutor())
        self.assertEqual(report["status"], "passed", report["error"])
        self.assertEqual(report["signing"]["status"], "unchecked")
        self.assertIn("not distribution-ready", Path(report["run_directory"], "release-notes.md").read_text())

    def test_rejects_debug_settings_and_mismatched_versions(self):
        args = release.parse_args(["check"])
        derived = self.root / "DerivedData"
        both = {name: settings(name, derived) for name in ("Yarms", "YarmsShare")}
        both["Yarms"]["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
        with self.assertRaisesRegex(release.RunError, "DEBUG"):
            release.validate_settings(both, args, self.root)
        both["Yarms"].pop("SWIFT_ACTIVE_COMPILATION_CONDITIONS")
        both["YarmsShare"]["CURRENT_PROJECT_VERSION"] = "2"
        with self.assertRaisesRegex(release.RunError, "CURRENT_PROJECT_VERSION"):
            release.validate_settings(both, args, self.root)

    def test_rejects_release_flags_that_restore_testability_or_debug_optimization(self):
        args = release.parse_args(["check"])
        for flag in ("-enable-testing", "-Onone"):
            with self.subTest(flag=flag):
                both = {name: settings(name, self.root / "DerivedData")
                        for name in ("Yarms", "YarmsShare")}
                both["YarmsShare"]["OTHER_SWIFT_FLAGS"] = "$(inherited) " + flag
                with self.assertRaisesRegex(release.RunError, "testability or unoptimized"):
                    release.validate_settings(both, args, self.root)

    def test_relative_and_absolute_entitlement_paths_are_accepted_for_both_targets(self):
        args = release.parse_args(["check"])
        for absolute_target in (None, "Yarms", "YarmsShare"):
            with self.subTest(absolute_target=absolute_target):
                both = {name: settings(name, self.root / "DerivedData")
                        for name in ("Yarms", "YarmsShare")}
                if absolute_target:
                    both[absolute_target]["CODE_SIGN_ENTITLEMENTS"] = str(
                        self.root / both[absolute_target]["CODE_SIGN_ENTITLEMENTS"])
                metadata = release.validate_settings(both, args, self.root)
                self.assertEqual(metadata["entitlement_files"], {
                    "Yarms": "YarmsApp/Yarms.entitlements",
                    "YarmsShare": "YarmsShare/Yarms.entitlements"})

    def test_invalid_entitlements_fail_before_build_for_both_targets(self):
        args = release.parse_args(["check"])
        redirected = self.root / "other.entitlements"
        redirected.write_bytes(b"invalid plist; must not be read")
        original = plistlib.dumps({"keychain-access-groups": ["$(YARMS_KEYCHAIN_GROUP)"]})
        cases = ("missing_setting", "blank_setting", "unresolved_setting", "redirected_setting",
                 "missing_file", "malformed_file", "wrong_group", "extra_default_group", "app_groups")
        expected_errors = {
            "missing_setting": "CODE_SIGN_ENTITLEMENTS",
            "blank_setting": "CODE_SIGN_ENTITLEMENTS",
            "unresolved_setting": "unresolved CODE_SIGN_ENTITLEMENTS",
            "redirected_setting": "must use",
            "missing_file": "missing or invalid CODE_SIGN_ENTITLEMENTS path",
            "malformed_file": "invalid",
            "wrong_group": "wrong keychain-access-groups",
            "extra_default_group": "wrong keychain-access-groups",
            "app_groups": "App Groups",
        }
        for target in ("Yarms", "YarmsShare"):
            path = self.root / ("YarmsApp" if target == "Yarms" else "YarmsShare") / "Yarms.entitlements"
            for case in cases:
                with self.subTest(target=target, case=case):
                    path.write_bytes(original)
                    def mutate(name, values):
                        if name != target:
                            return
                        if case == "missing_setting":
                            values.pop("CODE_SIGN_ENTITLEMENTS")
                        elif case == "blank_setting":
                            values["CODE_SIGN_ENTITLEMENTS"] = "   "
                        elif case == "unresolved_setting":
                            values["CODE_SIGN_ENTITLEMENTS"] = "$(SRCROOT)/" + values["CODE_SIGN_ENTITLEMENTS"]
                        elif case == "redirected_setting":
                            values["CODE_SIGN_ENTITLEMENTS"] = str(redirected)
                        elif case == "missing_file":
                            path.unlink()
                        elif case == "malformed_file":
                            path.write_bytes(b"not a plist")
                        else:
                            groups = (["$(YARMS_KEYCHAIN_GROUP)"] if case == "app_groups"
                                      else ["WRONG.group"] if case == "wrong_group"
                                      else ["DEFAULT.group", "$(YARMS_KEYCHAIN_GROUP)"])
                            content = {"keychain-access-groups": groups}
                            if case == "app_groups":
                                content["com.apple.security.application-groups"] = []
                            path.write_bytes(plistlib.dumps(content))
                    fake = FakeExecutor(settings_mutator=mutate)
                    report = self.run_release(args, fake)
                    self.assertEqual(report["status"], "failed")
                    self.assertIn(target, report["error"])
                    self.assertIn(expected_errors[case], report["error"])
                    self.assertFalse(any(command[-1] == "build" for command in fake.commands))
            path.write_bytes(original)

    def test_rejects_share_metadata_and_debug_sentinel(self):
        for fake, expected in ((FakeExecutor(bad_share=True), "CFBundleIdentifier"),
                               (FakeExecutor(marker=b"-YarmsUITestStoreID"), "debug-only"),
                               (FakeExecutor(test_bundle=True), "test bundle")):
            with self.subTest(expected=expected):
                report = self.run_release(release.parse_args(["check"]), fake)
                self.assertEqual(report["status"], "failed")
                self.assertIn(expected, report["error"])
                self.assertTrue(Path(report["run_directory"], "report.json").is_file())

    def test_xcode_failure_keeps_failure_report_and_log(self):
        report = self.run_release(release.parse_args(["check"]), FakeExecutor(build_failure=True))
        self.assertEqual(report["status"], "failed")
        self.assertIn("exited 65", report["error"])
        self.assertTrue(Path(report["log"]).exists())

    def test_primary_and_cleanup_failures_are_both_retained_in_report_and_notes(self):
        fake = FakeExecutor(build_failure=True, create_derived_data=True)
        with mock.patch.object(release.shutil, "rmtree",
                               side_effect=PermissionError("fixture cleanup denied")) as remove:
            report = self.run_release(release.parse_args(["check"]), fake)
        remove.assert_called_once()
        self.assertEqual(report["status"], "failed")
        self.assertTrue(report["derived_data_retained"])
        self.assertTrue((Path(report["run_directory"]) / "DerivedData").is_dir())
        self.assertIn("xcodebuild exited 65", report["error"])
        self.assertIn("Could not clean owned DerivedData: fixture cleanup denied", report["error"])
        self.assertLess(report["error"].index("xcodebuild exited 65"),
                        report["error"].index("Could not clean owned DerivedData"))
        saved = json.loads(Path(report["run_directory"], "report.json").read_text())
        self.assertEqual(saved["error"], report["error"])
        self.assertTrue(saved["derived_data_retained"])
        notes = Path(report["run_directory"], "release-notes.md").read_text()
        self.assertIn("xcodebuild exited 65", notes)
        self.assertIn("Could not clean owned DerivedData: fixture cleanup denied", notes)

    def test_cleanup_only_failure_is_reported_clearly(self):
        fake = FakeExecutor(create_derived_data=True)
        with mock.patch.object(release.shutil, "rmtree",
                               side_effect=PermissionError("fixture cleanup denied")) as remove:
            report = self.run_release(release.parse_args(["check"]), fake)
        remove.assert_called_once()
        self.assertEqual(report["status"], "failed")
        self.assertTrue(report["derived_data_retained"])
        self.assertEqual(report["error"], "Could not clean owned DerivedData: fixture cleanup denied")
        self.assertEqual(json.loads(Path(report["run_directory"], "report.json").read_text())["error"],
                         report["error"])
        self.assertIn(report["error"], Path(report["run_directory"], "release-notes.md").read_text())

    def test_sigint_during_cleanup_finishes_and_fails_release(self):
        original_handlers = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
        original_remove = release.shutil.rmtree
        def interrupt_during_cleanup(path):
            if hasattr(signal, "pthread_sigmask"):
                active = signal.pthread_sigmask(signal.SIG_BLOCK, set())
                self.assertTrue({signal.SIGINT, signal.SIGTERM}.issubset(active))
            os.kill(os.getpid(), signal.SIGINT)
            return original_remove(path)
        with mock.patch.object(release.shutil, "rmtree", side_effect=interrupt_during_cleanup) as remove:
            exit_code, result = self.run_main(FakeExecutor(create_derived_data=True))
        self.assertEqual(exit_code, 1)
        remove.assert_called_once()
        self.assert_interrupted_report(result)
        self.assertEqual({sig: signal.getsignal(sig) for sig in original_handlers}, original_handlers)

    def test_sigterm_during_first_final_report_write_rewrites_failure(self):
        original_handlers = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
        original_write = release._write_json_atomic
        written_statuses = []
        def interrupt_during_report(path, value):
            written_statuses.append(value["status"])
            if len(written_statuses) == 2:
                if hasattr(signal, "pthread_sigmask"):
                    active = signal.pthread_sigmask(signal.SIG_BLOCK, set())
                    self.assertTrue({signal.SIGINT, signal.SIGTERM}.issubset(active))
                os.kill(os.getpid(), signal.SIGTERM)
            return original_write(path, value)
        with mock.patch.object(release, "_write_json_atomic", side_effect=interrupt_during_report):
            exit_code, result = self.run_main(FakeExecutor(create_derived_data=True))
        self.assertEqual(exit_code, 1)
        self.assertEqual(written_statuses, ["running", "passed", "failed"])
        self.assert_interrupted_report(result)
        self.assertEqual({sig: signal.getsignal(sig) for sig in original_handlers}, original_handlers)

    def test_signal_during_cleanup_keeps_prior_build_failure(self):
        original_handlers = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
        original_remove = release.shutil.rmtree
        def interrupt_during_cleanup(path):
            os.kill(os.getpid(), signal.SIGTERM)
            return original_remove(path)
        with mock.patch.object(release.shutil, "rmtree", side_effect=interrupt_during_cleanup):
            exit_code, result = self.run_main(FakeExecutor(build_failure=True, create_derived_data=True))
        self.assertEqual(exit_code, 1)
        report, notes = self.assert_interrupted_report(result)
        self.assertIn("xcodebuild exited 65", report["error"])
        self.assertIn("xcodebuild exited 65", notes)
        self.assertEqual({sig: signal.getsignal(sig) for sig in original_handlers}, original_handlers)

    def test_early_configuration_failure_keeps_readable_failure_report(self):
        report = self.run_release(release.parse_args(["archive", "--version", "1.0.0",
                                                      "--build-number", "2"]), FakeExecutor())
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
                report = self.run_release(release.parse_args(["check"]), fake)
                self.assertEqual(report["status"], "failed")
                self.assertIn(expected, report["error"])
                self.assertFalse((Path(report["run_directory"]) / "DerivedData").exists())

    def test_signed_archive_requires_valid_default_shared_group(self):
        args = release.parse_args(["archive", "--version", "1.0.0", "--build-number", "2",
                                   "--team", "UNBNJA6WRF"])
        report = self.run_release(args, FakeExecutor(team="UNBNJA6WRF", default_group=False))
        self.assertEqual(report["status"], "failed")
        self.assertIn("default resolved shared Keychain", report["error"])

    def test_inconsistent_effective_signing_team_fails_before_build(self):
        def mutate(target, values):
            if target == "YarmsShare":
                values["DEVELOPMENT_TEAM"] = "OTHERTEAM1"
        fake = FakeExecutor(team="UNBNJA6WRF", settings_mutator=mutate)
        args = release.parse_args(["archive", "--version", "1.0.0", "--build-number", "2",
                                   "--team", "UNBNJA6WRF"])
        report = self.run_release(args, fake)
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
