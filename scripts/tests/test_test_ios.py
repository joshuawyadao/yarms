import argparse
import contextlib
import importlib.util
import io
import json
import os
import signal
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SPEC = importlib.util.spec_from_file_location("test_ios_runner", Path(__file__).resolve().parents[1] / "test-ios.py")
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)

RUNTIME_18 = "com.apple.CoreSimulator.SimRuntime.iOS-18-0"
RUNTIME_27 = "com.apple.CoreSimulator.SimRuntime.iOS-27-0"
IPHONE = "com.apple.CoreSimulator.SimDeviceType.iPhone-17"
IPAD = "com.apple.CoreSimulator.SimDeviceType.iPad-17"
SIM_ID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
CATALOG = {
    "runtimes": [
        {"identifier": RUNTIME_18, "version": "18.0", "isAvailable": True,
         "supportedDeviceTypes": [{"identifier": IPHONE}]},
        {"identifier": RUNTIME_27, "version": "27.0", "isAvailable": True,
         "supportedDeviceTypes": [{"identifier": IPHONE}, {"identifier": IPAD}]},
        {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-99-0", "version": "99.0",
         "isAvailable": False, "supportedDeviceTypes": [{"identifier": IPHONE}]},
    ],
    "devicetypes": [
        {"identifier": IPHONE, "productFamily": "iPhone", "isAvailable": True},
        {"identifier": IPAD, "productFamily": "iPad", "isAvailable": True},
    ],
}


class FakeExecutor:
    def __init__(self, *, test_code=0, passed=4, failed=0, timeout=False,
                 interrupt=False, cleanup_failure=False, summary=True,
                 create_timeout=False, create_output=None, recover_created=True,
                 shutdown_failure=False, device_state="Booted", listed_name=None,
                 list_devices_failure=False, ambiguous_owned=False, owned_id=SIM_ID,
                 launch_failure=False):
        self.commands = []
        self.test_code = test_code
        self.passed = passed
        self.failed = failed
        self.timeout = timeout
        self.interrupt = interrupt
        self.cleanup_failure = cleanup_failure
        self.summary = summary
        self.create_timeout = create_timeout
        self.create_output = create_output
        self.recover_created = recover_created
        self.shutdown_failure = shutdown_failure
        self.device_state = device_state
        self.listed_name = listed_name
        self.list_devices_failure = list_devices_failure
        self.ambiguous_owned = ambiguous_owned
        self.owned_id = owned_id
        self.launch_failure = launch_failure
        self.created_name = None
        self.shutdown_attempted = False

    def run(self, command, timeout, log=None):
        self.commands.append(command)
        if command == ["xcode-select", "-p"]:
            return 0, "/Applications/Xcode.app/Contents/Developer\n"
        if command[:3] == ["open", "-g", "-a"]:
            return (1, "DeviceHub launch failed") if self.launch_failure else (0, "")
        if command[:4] == ["xcrun", "simctl", "list", "--json"]:
            if command == ["xcrun", "simctl", "list", "--json", "devices"]:
                if self.list_devices_failure and self.shutdown_attempted:
                    return 1, "device listing failed"
                devices = [{"name": "Personal iPhone", "udid": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}]
                if self.created_name and self.recover_created:
                    devices.append({"name": (self.listed_name if self.shutdown_attempted else None) or self.created_name,
                                    "udid": self.owned_id, "state": self.device_state})
                    if self.ambiguous_owned:
                        devices.append({"name": self.created_name,
                                        "udid": "cccccccc-cccc-cccc-cccc-cccccccccccc", "state": "Shutdown"})
                return 0, json.dumps({"devices": {RUNTIME_27: devices}})
            if command == ["xcrun", "simctl", "list", "--json"]:
                return 0, json.dumps(CATALOG)
            return 2, "simctl list accepts at most one filter"
        if command[:3] == ["xcrun", "simctl", "create"]:
            self.created_name = command[3]
            if self.create_timeout:
                raise runner.CommandTimeout("Create timed out")
            return 0, (self.create_output or SIM_ID) + "\n"
        if command[0] == "xcodebuild":
            if log:
                Path(log).write_text("fake xcodebuild output\n")
            if self.timeout:
                raise runner.CommandTimeout("Xcodebuild timed out")
            if self.interrupt:
                raise KeyboardInterrupt()
            if self.summary:
                Path(command[command.index("-resultBundlePath") + 1]).mkdir()
            return self.test_code, ""
        if command[:3] == ["xcrun", "xcresulttool", "get"]:
            return 0, json.dumps({"passedTests": self.passed, "failedTests": self.failed,
                                  "skippedTests": 1, "totalTestCount": self.passed + self.failed + 1})
        if self.cleanup_failure and command[:3] == ["xcrun", "simctl", "delete"]:
            return 1, "delete failed"
        if self.shutdown_failure and command[:3] == ["xcrun", "simctl", "shutdown"]:
            self.shutdown_attempted = True
            return 149, "Unable to shutdown device in current state: Shutdown"
        if command[:3] == ["xcrun", "simctl", "shutdown"]:
            self.shutdown_attempted = True
        return 0, ""


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.console = io.StringIO()
        self.redirect = contextlib.redirect_stdout(self.console)
        self.redirect.__enter__()
        self.addCleanup(self.redirect.__exit__, None, None, None)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.args = argparse.Namespace(suite="full", appearance="light", runtime=None,
                                       device_type=None, timeout_seconds=1500)

    def run_case(self, fake, **kwargs):
        code = self.execute_case(self.args, fake, self.base, **kwargs)
        roots = list(self.base.iterdir())
        self.assertEqual(len(roots), 1)
        report = json.loads((roots[0] / "report.json").read_text())
        return code, report, roots[0]

    def execute_case(self, args, fake, base, **kwargs):
        app_probe = kwargs.pop("app_probe", lambda _path: False)
        return runner.execute(args, fake, base, host="Darwin", app_probe=app_probe, **kwargs)

    def test_discovery_chooses_latest_available_compatible_iphone(self):
        self.assertEqual(runner.select_profile(CATALOG), (RUNTIME_27, IPHONE))
        self.assertEqual(runner.select_profile(CATALOG, RUNTIME_18), (RUNTIME_18, IPHONE))
        for runtime, device in (("bad", None), (RUNTIME_27, IPAD),
                                (RUNTIME_18, "bad"),
                                ("com.apple.CoreSimulator.SimRuntime.iOS-99-0", None)):
            with self.subTest(runtime=runtime, device=device), self.assertRaises(runner.RunError):
                runner.select_profile(CATALOG, runtime, device)
        catalog = json.loads(json.dumps(CATALOG))
        catalog["runtimes"][1]["supportedDeviceTypes"] = [{"identifier": IPAD}]
        with self.assertRaises(runner.RunError):
            runner.select_profile(catalog)

    def test_discovery_uses_supported_unfiltered_list_grammar(self):
        fake = FakeExecutor()
        with self.assertRaises(runner.RunError):
            runner.require_command(fake, ["xcrun", "simctl", "list", "--json", "runtimes", "devicetypes"], 30)
        code, report, _ = self.run_case(fake)
        self.assertEqual(code, 0)
        self.assertEqual(report["status"], "passed")
        self.assertIn(["xcrun", "simctl", "list", "--json"], fake.commands)
        self.assertEqual(sum(command == ["xcrun", "simctl", "list", "--json"]
                             for command in fake.commands), 1)

    def test_voiceover_frontend_launches_before_simulator_creation(self):
        checked = []
        fake = FakeExecutor()
        expected = Path("/Applications/Xcode.app/Contents/Applications/DeviceHub.app")
        code, report, _ = self.run_case(fake, app_probe=lambda path: checked.append(path) or True)
        self.assertEqual(code, 0)
        self.assertEqual(report["voiceOverFrontend"], "launched")
        self.assertEqual(checked, [expected])
        launch = ["open", "-g", "-a", str(expected)]
        self.assertIn(launch, fake.commands)
        self.assertLess(fake.commands.index(launch),
                        next(index for index, command in enumerate(fake.commands)
                             if command[:3] == ["xcrun", "simctl", "create"]))

    def test_voiceover_frontend_unavailable_keeps_test_behavior(self):
        fake = FakeExecutor()
        code, report, _ = self.run_case(fake)
        self.assertEqual(code, 0)
        self.assertEqual(report["voiceOverFrontend"], "unavailable")
        self.assertNotIn("open", [command[0] for command in fake.commands])

    def test_voiceover_frontend_not_needed_for_older_runtime_or_sharing(self):
        for label, runtime, suite in (("older", RUNTIME_18, "full"),
                                      ("sharing", RUNTIME_27, "sharing")):
            with self.subTest(label=label):
                args = argparse.Namespace(**vars(self.args))
                args.runtime = runtime
                args.suite = suite
                fake = FakeExecutor()
                base = self.base / label
                self.assertEqual(self.execute_case(args, fake, base, app_probe=lambda _path: True), 0)
                report = json.loads((next(base.iterdir()) / "report.json").read_text())
                self.assertEqual(report["voiceOverFrontend"], "notRequired")
                self.assertNotIn(["xcode-select", "-p"], fake.commands)
                self.assertFalse(any(command[0] == "open" for command in fake.commands))

    def test_voiceover_frontend_launch_failure_fails_before_create(self):
        fake = FakeExecutor(launch_failure=True)
        code, report, _ = self.run_case(fake, app_probe=lambda _path: True)
        self.assertEqual(code, 1)
        self.assertEqual(report["voiceOverFrontend"], "failed")
        self.assertIn("DeviceHub launch failed", report["error"])
        self.assertFalse(any(command[:3] == ["xcrun", "simctl", "create"] for command in fake.commands))

    def test_private_voiceover_profile_requires_frontend(self):
        with mock.patch.dict(runner.SUITE_FILTERS, {"private": ("YarmsUITests/YarmsUITests/testVoiceOverCompletionRestoresFocusToFinish",)}):
            self.assertTrue(runner.needs_voiceover_frontend(RUNTIME_27, "private"))
            self.assertFalse(runner.needs_voiceover_frontend(RUNTIME_18, "private"))

    def test_profiles_filter_only_requested_tests(self):
        full = runner.test_command(SIM_ID, "full", self.base / "dd", self.base / "r")
        sharing = runner.test_command(SIM_ID, "sharing", self.base / "dd", self.base / "r")
        feedback = runner.test_command(SIM_ID, "feedback", self.base / "dd", self.base / "r")
        self.assertFalse(any(item.startswith("-only-testing:") for item in full))
        self.assertEqual(sum(item.startswith("-only-testing:") for item in sharing), 2)
        self.assertEqual(sum(item.startswith("-only-testing:") for item in feedback), 6)
        self.assertIn("-parallel-testing-enabled", full)
        self.assertEqual(full[full.index("-collect-test-diagnostics") + 1], "never")
        self.assertIn("CODE_SIGN_IDENTITY=-", full)

    def test_success_has_artifacts_and_deletes_only_owned_simulator(self):
        fake = FakeExecutor()
        code, report, root = self.run_case(fake)
        self.assertEqual(code, 0)
        self.assertEqual(report["status"], "passed")
        self.assertIn("Result: passed; tests 4 passed, 0 failed, 1 skipped", self.console.getvalue())
        self.assertEqual(report["testCounts"]["passed"], 4)
        self.assertTrue((root / "summary.json").exists())
        self.assertTrue((root / "xcodebuild.log").exists())
        self.assertFalse((root / "DerivedData").exists())
        mutations = [command for command in fake.commands if command[:2] == ["xcrun", "simctl"]
                     and command[2] in ("boot", "bootstatus", "ui", "shutdown", "delete")]
        self.assertEqual([command[2] for command in mutations],
                         ["boot", "bootstatus", "ui", "shutdown", "delete"])
        self.assertTrue(all(command[3] == SIM_ID for command in mutations))
        summary_command = next(command for command in fake.commands
                               if command[:3] == ["xcrun", "xcresulttool", "get"])
        self.assertEqual(summary_command[:5],
                         ["xcrun", "xcresulttool", "get", "test-results", "summary"])
        self.assertEqual(summary_command[5:7], ["--path", str(root / "Tests.xcresult")])
        self.assertEqual(len(summary_command), 7)

    def test_failing_xcodebuild_still_cleans_up(self):
        fake = FakeExecutor(test_code=65, failed=1)
        code, report, _ = self.run_case(fake)
        self.assertEqual(code, 1)
        self.assertEqual(report["testExitCode"], 65)
        self.assertEqual(report["status"], "failed")
        self.assertIn(["xcrun", "simctl", "delete", SIM_ID], fake.commands)

    def test_single_failed_test_preserves_zero_pass_failure_counts(self):
        code, report, _ = self.run_case(FakeExecutor(test_code=65, passed=0, failed=1))
        self.assertEqual(code, 1)
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["testExitCode"], 65)
        self.assertEqual(report["testCounts"], {"passed": 0, "failed": 1, "skipped": 1})

    def test_timeout_and_interrupt_still_clean_up(self):
        for mode in ("timeout", "interrupt"):
            with self.subTest(mode=mode):
                base = self.base / mode
                fake = FakeExecutor(**{mode: True})
                self.assertEqual(self.execute_case(self.args, fake, base), 1)
                self.assertIn(["xcrun", "simctl", "delete", SIM_ID], fake.commands)

    def test_timed_out_create_recovers_only_exact_owned_name(self):
        fake = FakeExecutor(create_timeout=True)
        code, report, _ = self.run_case(fake)
        self.assertEqual(code, 1)
        self.assertEqual(report["simulatorID"], SIM_ID)
        self.assertIn(["xcrun", "simctl", "delete", SIM_ID], fake.commands)
        self.assertFalse(any("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb" in command for command in fake.commands))

    def test_malformed_create_id_never_targets_foreign_simulator(self):
        fake = FakeExecutor(create_output="not-a-uuid", recover_created=False)
        code, report, _ = self.run_case(fake)
        self.assertEqual(code, 1)
        self.assertIsNone(report["simulatorID"])
        self.assertFalse(any(command[:3] in (["xcrun", "simctl", "shutdown"],
                                                ["xcrun", "simctl", "delete"])
                             for command in fake.commands))

    def test_valid_foreign_create_id_is_never_mutated(self):
        foreign_id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        fake = FakeExecutor(create_output=foreign_id)
        code, report, _ = self.run_case(fake)
        self.assertEqual(code, 1)
        self.assertEqual(report["simulatorID"], SIM_ID)
        self.assertIn("does not match", report["error"])
        self.assertFalse(any(foreign_id in command for command in fake.commands
                             if command[:3] in (["xcrun", "simctl", "boot"],
                                                ["xcrun", "simctl", "shutdown"],
                                                ["xcrun", "simctl", "delete"])))
        self.assertIn(["xcrun", "simctl", "delete", SIM_ID], fake.commands)

    def test_ambiguous_owned_name_prevents_all_device_mutation(self):
        fake = FakeExecutor(ambiguous_owned=True)
        code, report, _ = self.run_case(fake)
        self.assertEqual(code, 1)
        self.assertIsNone(report["simulatorID"])
        self.assertTrue(any("Multiple simulators" in error for error in report["cleanupErrors"]))
        self.assertFalse(any(command[:3] in (["xcrun", "simctl", "boot"],
                                                ["xcrun", "simctl", "shutdown"],
                                                ["xcrun", "simctl", "delete"])
                             for command in fake.commands))

    def test_recovered_owned_name_requires_valid_uuid(self):
        fake = FakeExecutor(create_timeout=True, owned_id="not-a-uuid")
        code, report, _ = self.run_case(fake)
        self.assertEqual(code, 1)
        self.assertIsNone(report["simulatorID"])
        self.assertTrue(any("UUID" in error for error in report["cleanupErrors"]))
        self.assertFalse(any(command[:3] in (["xcrun", "simctl", "shutdown"],
                                                ["xcrun", "simctl", "delete"])
                             for command in fake.commands))

    def test_second_signal_during_cleanup_marks_failure_and_finishes_cleanup(self):
        state = runner.InterruptState()
        state.interrupted = True

        class SignalingExecutor(FakeExecutor):
            def run(self, command, timeout, log=None):
                if command[:3] == ["xcrun", "simctl", "shutdown"]:
                    state.handle(signal.SIGTERM, None)
                    self.assert_cleaning = state.cleaning
                    if hasattr(signal, "pthread_sigmask"):
                        active = signal.pthread_sigmask(signal.SIG_BLOCK, set())
                        self.assert_masked = {signal.SIGINT, signal.SIGTERM}.issubset(active)
                return super().run(command, timeout, log)

        fake = SignalingExecutor()
        self.assertEqual(self.execute_case(self.args, fake, self.base,
                                           interrupt_state=state), 1)
        report = json.loads((next(self.base.iterdir()) / "report.json").read_text())
        self.assertTrue(fake.assert_cleaning)
        if hasattr(signal, "pthread_sigmask"):
            self.assertTrue(fake.assert_masked)
        self.assertEqual(report["status"], "failed")
        self.assertIn(["xcrun", "simctl", "delete", SIM_ID], fake.commands)

    @unittest.skipUnless(hasattr(os, "killpg"), "process groups require POSIX")
    def test_executor_timeout_reaps_its_child(self):
        with self.assertRaises(runner.CommandTimeout):
            runner.Executor().run([sys.executable, "-c", "import time; time.sleep(30)"], 0.05)

    def test_exited_parent_still_terminates_owned_group(self):
        process = mock.Mock(pid=12345)
        process.poll.return_value = 0
        process.wait.return_value = 0
        with mock.patch.object(runner.os, "killpg") as kill_group:
            runner.Executor._stop(process)
        self.assertEqual(kill_group.call_args_list,
                         [mock.call(12345, signal.SIGTERM), mock.call(12345, signal.SIGKILL)])
        self.assertEqual(process.wait.call_count, 2)

    def test_main_restores_signal_handlers_after_failure(self):
        original = {signum: signal.getsignal(signum) for signum in (signal.SIGINT, signal.SIGTERM)}
        with mock.patch.object(runner, "execute", return_value=1):
            self.assertEqual(runner.main([]), 1)
        self.assertEqual({signum: signal.getsignal(signum)
                          for signum in (signal.SIGINT, signal.SIGTERM)}, original)

    def test_cleanup_failure_and_missing_or_empty_summary_fail(self):
        for name, fake in (("cleanup", FakeExecutor(cleanup_failure=True)),
                           ("missing", FakeExecutor(summary=False)),
                           ("empty", FakeExecutor(passed=0))):
            with self.subTest(name=name):
                base = self.base / name
                self.assertEqual(self.execute_case(self.args, fake, base), 1)
                report = json.loads((next(base.iterdir()) / "report.json").read_text())
                self.assertEqual(report["status"], "failed")

    def test_already_shutdown_owned_simulator_is_clean_cleanup(self):
        fake = FakeExecutor(shutdown_failure=True, device_state="Shutdown")
        code, report, _ = self.run_case(fake)
        self.assertEqual(code, 0)
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["cleanupErrors"], [])
        self.assertIn(["xcrun", "simctl", "delete", SIM_ID], fake.commands)

    def test_shutdown_error_requires_exact_owned_shutdown_state(self):
        cases = (
            FakeExecutor(shutdown_failure=True, device_state="Booted"),
            FakeExecutor(shutdown_failure=True, device_state="Shutdown", listed_name="Foreign iPhone"),
            FakeExecutor(shutdown_failure=True, device_state="Shutdown", list_devices_failure=True),
        )
        for index, fake in enumerate(cases):
            with self.subTest(index=index):
                base = self.base / str(index)
                self.assertEqual(self.execute_case(self.args, fake, base), 1)
                report = json.loads((next(base.iterdir()) / "report.json").read_text())
                self.assertEqual(report["status"], "failed")
                self.assertTrue(any(error.startswith("shutdown:") for error in report["cleanupErrors"]))
                self.assertIn(["xcrun", "simctl", "delete", SIM_ID], fake.commands)

    def test_legacy_summary_count_keys_are_supported(self):
        class LegacyExecutor(FakeExecutor):
            def run(self, command, timeout, log=None):
                if command[:3] == ["xcrun", "xcresulttool", "get"]:
                    self.commands.append(command)
                    return 0, json.dumps({"testsPassed": 2, "testsFailed": 0, "testsSkipped": 0})
                return super().run(command, timeout, log)

        code, report, _ = self.run_case(LegacyExecutor())
        self.assertEqual(code, 0)
        self.assertEqual(report["testCounts"], {"passed": 2, "failed": 0, "skipped": 0})


if __name__ == "__main__":
    unittest.main()
