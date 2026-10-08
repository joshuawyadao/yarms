#!/usr/bin/env python3
"""Run the Yarms XCTest scheme on one disposable iPhone simulator."""

import argparse
import json
import os
import platform
import re
import shutil
import signal
import subprocess
import sys
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
FEEDBACK_TESTS = (
    "testPasteSearchPlayerLayoutAndNotesPersistence",
    "testPasteConfirmationAndErrorState",
    "testPasteConfirmationAndErrorStateWithReduceMotion",
    "testWorkoutCompletionRequiresFinishAndPreservesDraftNotes",
    "testWorkoutCompletionAtMaximumTextWithReduceMotion",
    "testVoiceOverCompletionRestoresFocusToFinish",
)
SUITE_FILTERS = {
    "full": (),
    "sharing": ("YarmsTests/ShortcutCaptureTests", "YarmsTests/LibraryTests"),
    "feedback": tuple(f"YarmsUITests/YarmsUITests/{name}" for name in FEEDBACK_TESTS),
}


class RunError(Exception):
    pass


class InterruptedRun(RunError):
    pass


class CommandTimeout(RunError):
    pass


@contextmanager
def blocked_termination_signals():
    """Defer a second interrupt until owned process/device cleanup finishes."""
    if hasattr(signal, "pthread_sigmask"):
        previous = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM})
        try:
            yield
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, previous)
    else:
        yield


class InterruptState:
    def __init__(self):
        self.interrupted = False
        self.cleaning = False

    def handle(self, _signum, _frame):
        first = not self.interrupted
        self.interrupted = True
        if first and not self.cleaning:
            raise InterruptedRun("Interrupted by signal")


class Executor:
    """Bounded subprocess execution; a timeout or interrupt stops only its process group."""

    def run(self, command, timeout, log=None):
        output = open(log, "w", encoding="utf-8") if log else subprocess.PIPE
        process = None
        try:
            process = subprocess.Popen(
                command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                text=True, start_new_session=True,
            )
            try:
                stdout, _ = process.communicate(timeout=timeout)
            except (subprocess.TimeoutExpired, KeyboardInterrupt, InterruptedRun):
                self._stop(process)
                raise
            return process.returncode, stdout or ""
        except subprocess.TimeoutExpired as exc:
            raise CommandTimeout(f"Timed out after {timeout}s: {command[0]}") from exc
        finally:
            if log:
                output.close()
            elif process and process.stdout:
                process.stdout.close()

    @staticmethod
    def _stop(process):
        with blocked_termination_signals():
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                pass
            # The direct child may have exited while descendants still hold its
            # stdout pipe. Always finish the owned group after a failed command.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)


def require_command(executor, command, timeout, log=None):
    code, output = executor.run(command, timeout, log)
    if code:
        raise RunError(f"{command[0]} exited {code}: {output.strip()[:500]}")
    return output


def parse_json(value, source):
    try:
        return json.loads(value)
    except (TypeError, ValueError) as exc:
        raise RunError(f"Invalid JSON from {source}") from exc


def version_tuple(runtime):
    value = str(runtime.get("version", ""))
    if not re.fullmatch(r"\d+(?:\.\d+)*", value):
        return ()
    return tuple(int(part) for part in value.split("."))


def select_profile(catalog, runtime_id=None, device_type_id=None):
    types = {item["identifier"]: item for item in catalog.get("devicetypes", [])
             if isinstance(item, dict) and item.get("identifier")}
    runtimes = [item for item in catalog.get("runtimes", [])
                if isinstance(item, dict) and item.get("identifier", "").startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
                and item.get("isAvailable") is True and version_tuple(item) >= (18,)]
    if runtime_id:
        runtimes = [item for item in runtimes if item["identifier"] == runtime_id]
    if not runtimes:
        raise RunError("No available iOS 18+ runtime matches the requested identifier")
    runtime = max(runtimes, key=version_tuple)
    supported = runtime.get("supportedDeviceTypes", [])
    compatible = []
    for entry in supported:
        identifier = entry.get("identifier") if isinstance(entry, dict) else entry
        item = types.get(identifier)
        if item and item.get("productFamily") == "iPhone" and item.get("isAvailable", True) is not False:
            compatible.append(item)
    if device_type_id:
        compatible = [item for item in compatible if item["identifier"] == device_type_id]
    if not compatible:
        raise RunError("No available iPhone type is compatible with the selected runtime")
    return runtime["identifier"], compatible[0]["identifier"]


def test_command(simulator_id, suite, derived_data, result_bundle):
    command = [
        "xcodebuild", "-project", "Yarms.xcodeproj", "-scheme", "Yarms",
        "-sdk", "iphonesimulator", "-destination", f"platform=iOS Simulator,id={simulator_id}",
        "-parallel-testing-enabled", "NO", "-derivedDataPath", str(derived_data),
        "-resultBundlePath", str(result_bundle), "CODE_SIGNING_ALLOWED=YES",
        "CODE_SIGN_IDENTITY=-",
    ]
    command += [f"-only-testing:{item}" for item in SUITE_FILTERS[suite]]
    return command + ["test"]


def validated_simulator_id(value):
    try:
        parsed = uuid.UUID(value)
    except (TypeError, ValueError, AttributeError) as exc:
        raise RunError("simctl did not return a simulator UUID") from exc
    if str(parsed) != value.lower():
        raise RunError("simctl did not return a canonical simulator UUID")
    return value


def find_owned_simulator(executor, name):
    devices = parse_json(require_command(executor, ["xcrun", "simctl", "list", "--json", "devices"], 30), "simctl devices")
    matches = [device for group in devices.get("devices", {}).values() for device in group
               if isinstance(device, dict) and device.get("name") == name]
    if len(matches) > 1:
        raise RunError("Multiple simulators have the ownership name; refusing cleanup")
    return validated_simulator_id(matches[0].get("udid")) if matches else None


def owned_simulator_is_shutdown(executor, simulator_id, name):
    devices = parse_json(require_command(executor, ["xcrun", "simctl", "list", "--json", "devices"], 30), "simctl devices")
    matches = [device for group in devices.get("devices", {}).values() for device in group
               if isinstance(device, dict) and device.get("udid") == simulator_id
               and device.get("name") == name]
    return len(matches) == 1 and matches[0].get("state") == "Shutdown"


def summarize(executor, result_bundle, summary_file):
    output = require_command(executor, ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result_bundle)], 60)
    summary = parse_json(output, "xcresulttool summary")
    summary_file.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    try:
        if "passedTests" in summary and "failedTests" in summary:
            passed = int(summary["passedTests"])
            failed = int(summary["failedTests"])
            skipped = int(summary.get("skippedTests", 0))
        else:
            passed = int(summary["testsPassed"])
            failed = int(summary["testsFailed"])
            skipped = int(summary.get("testsSkipped", 0))
    except (KeyError, TypeError, ValueError) as exc:
        raise RunError("XCTest summary has no usable test counts") from exc
    if passed < 0 or failed < 0 or skipped < 0 or passed + failed == 0:
        raise RunError("XCTest summary has invalid test counts")
    return {"passed": passed, "failed": failed, "skipped": skipped}


def write_report(path, report):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def execute(args, executor=None, run_base=None, host=None, interrupt_state=None):
    executor = executor or Executor()
    run_base = Path(run_base) if run_base else ROOT / ".build" / "test-runs"
    run_id = uuid.uuid4().hex
    run_root = run_base / f"{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}-{run_id}"
    run_root.mkdir(parents=True, exist_ok=False)
    report_path = run_root / "report.json"
    simulator_name = f"yarms-tests-{run_id}"
    report = {
        "version": 1, "status": "running", "suite": args.suite,
        "appearance": args.appearance, "runtime": None, "deviceType": None,
        "simulatorID": None, "simulatorName": simulator_name,
        "testExitCode": None, "testCounts": None, "error": None, "cleanupErrors": [],
    }
    write_report(report_path, report)
    print(f"Report: {report_path}", flush=True)
    simulator_id = None
    derived_data = run_root / "DerivedData"
    try:
        if (host or platform.system()) != "Darwin":
            raise RunError("Xcode simulator tests require macOS")
        catalog = parse_json(require_command(executor, ["xcrun", "simctl", "list", "--json", "runtimes", "devicetypes"], 30), "simctl catalog")
        runtime, device_type = select_profile(catalog, args.runtime, args.device_type)
        report.update(runtime=runtime, deviceType=device_type)
        write_report(report_path, report)
        created = require_command(executor, ["xcrun", "simctl", "create", simulator_name, device_type, runtime], 60)
        created = validated_simulator_id(created.strip())
        owned_id = find_owned_simulator(executor, simulator_name)
        if owned_id is None or owned_id.lower() != created.lower():
            raise RunError("simctl create UUID does not match the fresh owned simulator")
        simulator_id = owned_id
        report["simulatorID"] = simulator_id
        write_report(report_path, report)
        require_command(executor, ["xcrun", "simctl", "boot", simulator_id], 60)
        require_command(executor, ["xcrun", "simctl", "bootstatus", simulator_id, "-b"], 180)
        require_command(executor, ["xcrun", "simctl", "ui", simulator_id, "appearance", args.appearance], 30)
        result_bundle = run_root / "Tests.xcresult"
        code, _ = executor.run(test_command(simulator_id, args.suite, derived_data, result_bundle), args.timeout_seconds, run_root / "xcodebuild.log")
        report["testExitCode"] = code
        write_report(report_path, report)
        if result_bundle.exists():
            report["testCounts"] = summarize(executor, result_bundle, run_root / "summary.json")
        else:
            raise RunError("XCTest result bundle is missing")
        if code != 0 or report["testCounts"]["failed"] != 0:
            raise RunError(f"XCTest failed (xcodebuild exit {code}; failed tests {report['testCounts']['failed']})")
    except (Exception, KeyboardInterrupt) as exc:
        report["error"] = str(exc) or type(exc).__name__
    finally:
        if interrupt_state:
            interrupt_state.cleaning = True
        with blocked_termination_signals():
            # A timed-out create may have succeeded. Recover only our exact unique name.
            if simulator_id is None and (host or platform.system()) == "Darwin":
                try:
                    simulator_id = find_owned_simulator(executor, simulator_name)
                    if simulator_id:
                        report["simulatorID"] = simulator_id
                except (Exception, KeyboardInterrupt) as exc:
                    report["cleanupErrors"].append(f"ownership lookup: {exc}")
            if simulator_id:
                for action in ("shutdown", "delete"):
                    try:
                        require_command(executor, ["xcrun", "simctl", action, simulator_id], 60)
                    except (Exception, KeyboardInterrupt) as exc:
                        already_shutdown = False
                        if action == "shutdown":
                            try:
                                already_shutdown = owned_simulator_is_shutdown(executor, simulator_id, simulator_name)
                            except (Exception, KeyboardInterrupt):
                                pass
                        if not already_shutdown:
                            report["cleanupErrors"].append(f"{action}: {exc}")
            try:
                if derived_data.exists():
                    shutil.rmtree(derived_data)
            except OSError as exc:
                report["cleanupErrors"].append(f"DerivedData: {exc}")
        if interrupt_state and interrupt_state.interrupted and not report["error"]:
            report["error"] = "Interrupted by signal"
        report["status"] = "passed" if not report["error"] and not report["cleanupErrors"] else "failed"
        write_report(report_path, report)
        counts = report["testCounts"]
        details = [f"Result: {report['status']}"]
        if counts:
            details.append(f"tests {counts['passed']} passed, {counts['failed']} failed, {counts['skipped']} skipped")
        if report["error"]:
            details.append(f"error: {report['error'][:500]}")
        if report["cleanupErrors"]:
            details.append(f"cleanup: {'; '.join(report['cleanupErrors'])[:500]}")
        print("; ".join(details), flush=True)
        print(f"Report: {report_path}", flush=True)
    return 0 if report["status"] == "passed" else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=SUITE_FILTERS, default="full")
    parser.add_argument("--appearance", choices=("light", "dark"), default="light")
    parser.add_argument("--runtime", help="Full iOS runtime identifier")
    parser.add_argument("--device-type", help="Full iPhone device type identifier")
    parser.add_argument("--timeout-seconds", type=int, default=1500)
    args = parser.parse_args(argv)
    if not 60 <= args.timeout_seconds <= 3600:
        parser.error("--timeout-seconds must be between 60 and 3600")

    interrupt_state = InterruptState()
    previous = {signum: signal.signal(signum, interrupt_state.handle)
                for signum in (signal.SIGINT, signal.SIGTERM)}
    try:
        return execute(args, interrupt_state=interrupt_state)
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)


if __name__ == "__main__":
    sys.exit(main())
