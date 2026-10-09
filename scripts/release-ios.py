#!/usr/bin/env python3
"""Check Release artifacts or retain a versioned local iOS archive."""

import argparse
import json
import os
import plistlib
import re
import shutil
import signal
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

from xcode_support import (CommandTimeout, Executor, InterruptedRun, InterruptState,
                           ROOT, RunError, blocked_termination_signals,
                           require_command)


APP_ID = "com.joshuawyadao.yarms"
SHARE_ID = APP_ID + ".share"
SHARED_GROUP_SUFFIX = APP_ID + ".shared"
DEBUG_SENTINELS = (b"-YarmsUITestStoreID", b"-YarmsUITestReduceMotion", b"YarmsUITests")
RELEASES = ROOT / ".build" / "releases"


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="mode", required=True)
    check = commands.add_parser("check", help="check an unsigned generic iOS Simulator Release build")
    archive = commands.add_parser("archive", help="create and check a retained iOS archive")
    for command in (check, archive):
        command.add_argument("--timeout-seconds", type=int, default=1200,
                             help="maximum seconds for the Xcode build/archive step")
    archive.add_argument("--version", required=True, help="three-component marketing version, e.g. 1.0.0")
    archive.add_argument("--build-number", required=True, help="positive integer bundle build number")
    signing = archive.add_mutually_exclusive_group()
    signing.add_argument("--unsigned", action="store_true", help="retain an unsigned, non-distributable archive")
    signing.add_argument("--team", help="Apple development team ID for signing both targets")
    archive.add_argument("--notes-file", type=Path, help="optional UTF-8 text for local release notes")
    args = parser.parse_args(argv)
    if args.timeout_seconds < 1:
        parser.error("--timeout-seconds must be positive")
    if args.mode == "archive":
        if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", args.version):
            parser.error("--version must have three numeric components")
        if not re.fullmatch(r"[1-9][0-9]*", args.build_number):
            parser.error("--build-number must be a positive integer")
        if args.team and not re.fullmatch(r"[A-Z0-9]{10}", args.team):
            parser.error("--team must be a ten-character Apple team ID")
    return args


def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def run_directory(args):
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    prefix = f"{args.version}-{args.build_number}-" if args.mode == "archive" else "check-"
    path = RELEASES / f"{prefix}{stamp}-{uuid.uuid4().hex[:8]}"
    path.mkdir(parents=True, exist_ok=False)
    return path


def source_state(executor):
    """Record provenance without reading or writing repository contents."""
    sha = require_command(executor, ["git", "rev-parse", "HEAD"], 15).strip()
    dirty = bool(require_command(executor, ["git", "status", "--porcelain"], 15).strip())
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise RunError("Git did not return a commit SHA")
    return {"commit": sha, "dirty": dirty}


def overrides(args):
    values = []
    if args.mode == "archive":
        values += [f"MARKETING_VERSION={args.version}",
                   f"CURRENT_PROJECT_VERSION={args.build_number}"]
        if args.team:
            values.append(f"DEVELOPMENT_TEAM={args.team}")
    if args.mode == "check" or args.unsigned:
        values.append("CODE_SIGNING_ALLOWED=NO")
    return values


def base_xcode_command(args, run_dir):
    destination = "generic/platform=iOS Simulator" if args.mode == "check" else "generic/platform=iOS"
    command = ["xcodebuild", "-project", "Yarms.xcodeproj", "-scheme", "Yarms",
               "-configuration", "Release", "-destination", destination,
               "-derivedDataPath", str(run_dir / "DerivedData")]
    if args.mode == "check":
        command += ["-sdk", "iphonesimulator"]
    return command


def build_settings_command(args, run_dir, target):
    command = base_xcode_command(args, run_dir)
    if target == "YarmsShare":
        command[command.index("-scheme") + 1] = target
        command[command.index("-scheme")] = "-target"
        derived_index = command.index("-derivedDataPath")
        del command[derived_index:derived_index + 2]
        destination_index = command.index("-destination")
        del command[destination_index:destination_index + 2]
        if args.mode == "archive":
            command += ["-sdk", "iphoneos"]
    return command + ["-showBuildSettings", "-json"] + overrides(args)


def build_command(args, run_dir):
    command = base_xcode_command(args, run_dir)
    if args.mode == "archive":
        command += ["-archivePath", str(archive_path(args, run_dir))]
    return command + overrides(args) + ["build" if args.mode == "check" else "archive"]


def archive_path(args, run_dir):
    return run_dir / f"Yarms-{args.version}-{args.build_number}.xcarchive"


def read_build_settings(output):
    try:
        payload = json.loads(output)
    except (TypeError, ValueError) as exc:
        raise RunError("Xcode returned invalid Release build settings JSON") from exc
    if not isinstance(payload, list):
        raise RunError("Xcode returned no target build settings")
    result = {}
    for item in payload:
        if isinstance(item, dict) and item.get("target") in ("Yarms", "YarmsShare"):
            target = item["target"]
            if target in result or not isinstance(item.get("buildSettings"), dict):
                raise RunError(f"Ambiguous Release build settings for {target}")
            result[target] = item["buildSettings"]
    if set(result) != {"Yarms", "YarmsShare"}:
        raise RunError("Xcode did not report both app and Share extension build settings")
    return result


def target_settings(executor, args, run_dir):
    entries = []
    for target in ("Yarms", "YarmsShare"):
        output = require_command(executor, build_settings_command(args, run_dir, target), 120)
        entries.extend(parse_target_json(output, target))
    return read_build_settings(json.dumps(entries))


def parse_target_json(output, target):
    """Find Xcode's JSON array even when DVT diagnostics surround it on stderr."""
    candidates = []
    decoder = json.JSONDecoder()
    for match in re.finditer(r"(?m)^[ \t]*\[", output):
        try:
            value, _ = decoder.raw_decode(output[match.start():].lstrip())
        except ValueError:
            continue
        if isinstance(value, list) and any(
                isinstance(item, dict) and item.get("target") == target
                and isinstance(item.get("buildSettings"), dict) for item in value):
            candidates.append(value)
    if len(candidates) != 1:
        raise RunError(f"Xcode returned {'ambiguous' if candidates else 'invalid'} {target} Release build settings JSON")
    return candidates[0]


def _required(settings, key, target):
    value = str(settings.get(key, "")).strip()
    if not value:
        raise RunError(f"{target} has no {key} setting")
    return value


def _keychain_group(value, team):
    prefix = "$(AppIdentifierPrefix)"
    if value.startswith(prefix):
        value = value[len(prefix):]
    elif team and value == team + "." + SHARED_GROUP_SUFFIX:
        value = SHARED_GROUP_SUFFIX
    return value


def validate_settings(settings, args):
    app, share = settings["Yarms"], settings["YarmsShare"]
    for name, target, bundle in (("Yarms", app, APP_ID), ("YarmsShare", share, SHARE_ID)):
        if _required(target, "CONFIGURATION", name) != "Release":
            raise RunError(f"{name} is not configured for Release")
        if _required(target, "PRODUCT_BUNDLE_IDENTIFIER", name) != bundle:
            raise RunError(f"{name} has the wrong bundle identifier")
        if target.get("ENABLE_TESTABILITY", "NO") == "YES":
            raise RunError(f"{name} enables testability in Release")
        if _required(target, "SWIFT_OPTIMIZATION_LEVEL", name) == "-Onone":
            raise RunError(f"{name} disables Swift optimization in Release")
        swift_conditions = str(target.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", ""))
        swift_flags = str(target.get("OTHER_SWIFT_FLAGS", ""))
        if re.search(r"(?:^|\s)(?:-enable-testing|-Onone)(?:\s|$)", swift_flags):
            raise RunError(f"{name} has testability or unoptimized Swift flags in Release")
        c_flags = " ".join(str(target.get(key, "")) for key in
                           ("GCC_PREPROCESSOR_DEFINITIONS", "OTHER_CFLAGS", "OTHER_CPLUSPLUSFLAGS"))
        if (re.search(r"(?:^|\s)DEBUG(?:\s|$)", swift_conditions)
                or re.search(r"(?:^|\s)-D\s*DEBUG(?:\s|$)", swift_flags)
                or re.search(r"(?:^|\s)(?:-D)?DEBUG(?:=1)?(?:\s|$)", c_flags)):
            raise RunError(f"{name} compiles DEBUG code in Release")
        if _keychain_group(_required(target, "YARMS_KEYCHAIN_GROUP", name),
                           str(target.get("DEVELOPMENT_TEAM", "")).strip()) != SHARED_GROUP_SUFFIX:
            raise RunError(f"{name} has the wrong shared Keychain group")
        if _required(target, "CODE_SIGN_STYLE", name) != "Automatic":
            raise RunError(f"{name} must use automatic code signing")
        deployment = _required(target, "IPHONEOS_DEPLOYMENT_TARGET", name)
        if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", deployment):
            raise RunError(f"{name} has an invalid iOS deployment target")
        if tuple(int(p) for p in deployment.split(".")) < (18,):
            raise RunError(f"{name} targets iOS older than 18")
    for key in ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION", "DEVELOPMENT_TEAM", "YARMS_KEYCHAIN_GROUP"):
        if str(app.get(key, "")) != str(share.get(key, "")):
            raise RunError(f"App and Share extension disagree on {key}")
    if share.get("APPLICATION_EXTENSION_API_ONLY") != "YES" or share.get("SKIP_INSTALL") != "YES":
        raise RunError("Share extension needs extension-only APIs and SKIP_INSTALL=YES")
    version = _required(app, "MARKETING_VERSION", "Yarms")
    build = _required(app, "CURRENT_PROJECT_VERSION", "Yarms")
    if args.mode == "archive" and (version, build) != (args.version, args.build_number):
        raise RunError("Archive version overrides did not reach both targets")
    team = str(app.get("DEVELOPMENT_TEAM", "")).strip()
    if args.mode == "archive" and not args.unsigned and not team:
        raise RunError("Signed archive requires a development team; pass --team TEAM")
    if args.mode == "archive" and args.team:
        if team != args.team:
            raise RunError("Requested signing team did not reach both targets")
    return {"version": version, "build_number": build, "configured_team": team or None,
            "bundle_ids": {"app": APP_ID, "share_extension": SHARE_ID},
            "shared_keychain_group": SHARED_GROUP_SUFFIX}


def _plist(path):
    try:
        with path.open("rb") as handle:
            value = plistlib.load(handle)
    except (OSError, ValueError, plistlib.InvalidFileException) as exc:
        raise RunError(f"Missing or invalid bundle metadata: {path}") from exc
    if not isinstance(value, dict):
        raise RunError(f"Invalid bundle metadata: {path}")
    return value


def bundle_paths(args, run_dir, settings):
    if args.mode == "archive":
        root = archive_path(args, run_dir)
        app = root / "Products" / "Applications" / "Yarms.app"
        return root, app
    app_settings = settings["Yarms"]
    build_dir = Path(_required(app_settings, "TARGET_BUILD_DIR", "Yarms"))
    product = _required(app_settings, "FULL_PRODUCT_NAME", "Yarms")
    if product != "Yarms.app" or not build_dir.is_absolute():
        raise RunError("Unexpected app build product path")
    app = build_dir / product
    derived = (run_dir / "DerivedData").resolve()
    if not app.resolve().is_relative_to(derived):
        raise RunError("App build product escaped this Release run")
    return None, app


def _validate_bundle(path, bundle_id, version, build, expected_type):
    if not path.is_dir():
        raise RunError(f"Missing {expected_type}: {path}")
    info = _plist(path / "Info.plist")
    expected = {"CFBundleIdentifier": bundle_id, "CFBundleShortVersionString": version,
                "CFBundleVersion": build}
    for key, value in expected.items():
        if str(info.get(key, "")) != value:
            raise RunError(f"{expected_type} has the wrong {key}")
    executable = info.get("CFBundleExecutable")
    if not isinstance(executable, str) or executable in ("", ".", "..") or Path(executable).name != executable:
        raise RunError(f"{expected_type} has an unsafe executable name")
    binary = path / executable
    if not binary.is_file() or binary.is_symlink():
        raise RunError(f"{expected_type} executable is missing")
    data = binary.read_bytes()
    for sentinel in DEBUG_SENTINELS:
        if sentinel in data:
            raise RunError(f"{expected_type} contains debug-only test control {sentinel.decode()}")
    minimum = info.get("MinimumOSVersion")
    if not isinstance(minimum, str) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", minimum):
        raise RunError(f"{expected_type} has no valid minimum iOS version")
    if tuple(int(p) for p in minimum.split(".")) < (18,):
        raise RunError(f"{expected_type} targets iOS older than 18")
    return info, minimum


def validate_artifact(args, run_dir, settings, metadata):
    archive, app = bundle_paths(args, run_dir, settings)
    if archive is not None:
        if not archive.is_dir():
            raise RunError("Xcode did not create the requested archive")
        archive_info = _plist(archive / "Info.plist")
        archive_app = archive_info.get("ApplicationProperties", {})
        if (not isinstance(archive_app, dict)
                or archive_app.get("ApplicationPath") != "Applications/Yarms.app"):
            raise RunError("Archive metadata points to a different application")
    app_info, app_min = _validate_bundle(app, APP_ID, metadata["version"], metadata["build_number"], "app")
    plugins = app / "PlugIns"
    extension = plugins / "YarmsShare.appex"
    if not plugins.is_dir() or sorted(path.name for path in plugins.iterdir()) != ["YarmsShare.appex"]:
        raise RunError("App does not contain exactly the expected Share extension")
    extension_info, share_min = _validate_bundle(extension, SHARE_ID, metadata["version"],
                                                  metadata["build_number"], "Share extension")
    extension_settings = extension_info.get("NSExtension")
    point = (extension_settings.get("NSExtensionPointIdentifier")
             if isinstance(extension_settings, dict) else None)
    if point != "com.apple.share-services":
        raise RunError("Share extension has the wrong extension point")
    if app_min != share_min:
        raise RunError("App and Share extension minimum iOS versions differ")
    for root, dirs, files in os.walk(app):
        for name in dirs + files:
            if name.endswith((".xctest", ".xctestrun", ".xctestproducts")):
                raise RunError("Release app contains a test bundle")
    return {"archive": str(archive) if archive else None, "app": str(app),
            "share_extension": str(extension), "minimum_ios": app_min,
            "app_executable": app_info["CFBundleExecutable"],
            "share_executable": extension_info["CFBundleExecutable"]}


def _extract_plist(output, source):
    start, end = output.find("<plist"), output.rfind("</plist>")
    if start < 0 or end < 0:
        raise RunError(f"{source} returned no entitlements plist")
    try:
        value = plistlib.loads(output[start:end + len("</plist>")].encode("utf-8"))
    except (ValueError, plistlib.InvalidFileException) as exc:
        raise RunError(f"{source} returned invalid entitlements") from exc
    if not isinstance(value, dict):
        raise RunError(f"{source} returned invalid entitlements")
    return value


def _signature_details(executor, path, timeout):
    require_command(executor, ["codesign", "--verify", "--strict", str(path)], timeout)
    display = require_command(executor, ["codesign", "-dv", str(path)], timeout)
    team_match = re.search(r"(?m)^TeamIdentifier=([A-Z0-9]+)\s*$", display)
    id_match = re.search(r"(?m)^Identifier=([^\s]+)\s*$", display)
    if not team_match or not id_match:
        raise RunError(f"Could not read signing identity for {path.name}")
    entitlements = _extract_plist(require_command(executor,
                                                  ["codesign", "-d", "--entitlements", ":-", str(path)],
                                                  timeout), path.name)
    return {"team": team_match.group(1), "identifier": id_match.group(1),
            "entitlements": entitlements}


def validate_signatures(executor, artifact, configured_team):
    result = {}
    for name, bundle in (("app", APP_ID), ("share_extension", SHARE_ID)):
        detail = _signature_details(executor, Path(artifact[name]), 30)
        if detail["team"] != configured_team or detail["identifier"] != bundle:
            raise RunError(f"{name} signature disagrees with configured team or bundle ID")
        ents = detail["entitlements"]
        app_identifier = ents.get("application-identifier") or ents.get("com.apple.application-identifier")
        if app_identifier != f"{configured_team}.{bundle}":
            raise RunError(f"{name} has the wrong signed application identifier")
        groups = ents.get("keychain-access-groups")
        if not isinstance(groups, list) or not groups or any(not isinstance(g, str) for g in groups):
            raise RunError(f"{name} has no signed Keychain access groups")
        expected_group = f"{configured_team}.{SHARED_GROUP_SUFFIX}"
        if groups[0] != expected_group or any("$(" in group for group in groups):
            raise RunError(f"{name} lacks the default resolved shared Keychain access group")
        result[name] = {"team": detail["team"], "identifier": detail["identifier"],
                        "shared_keychain_group": expected_group}
    return result


def _write_json_atomic(path, value):
    temporary = path.with_name(path.name + ".tmp")
    try:
        with temporary.open("w", encoding="utf-8") as handle:
            json.dump(value, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def release_notes(args, report, notes_text):
    metadata = report.get("metadata") or {}
    source = report.get("source") or {}
    status = "passed" if report["status"] == "passed" else "failed"
    title = (f"Yarms {metadata.get('version', args.version)} ({metadata.get('build_number', args.build_number)})"
             if args.mode == "archive" else "Yarms Release check")
    lines = [f"# {title}", "", f"Release validation: {status}.",
             f"Source commit: {source.get('commit', 'unavailable')}.",
             f"Source had local changes: {('yes' if source['dirty'] else 'no') if 'dirty' in source else 'unknown'}." ]
    if args.mode == "archive":
        signed = report.get("signing", {}).get("status") == "verified"
        lines += [f"Signing: {'verified for app and Share extension' if signed else 'unchecked; not distribution-ready'}."]
    if report.get("error"):
        lines += [f"Failure: {report['error']}"]
    if notes_text:
        lines += ["", "## Notes", "", notes_text.strip()]
    return "\n".join(lines) + "\n"


def execute(args, executor=None, release_root=None):
    global RELEASES
    if release_root is not None:
        RELEASES = Path(release_root)
    executor = executor or Executor()
    run_dir = run_directory(args)
    notes_text = None
    report = {"mode": args.mode, "status": "running", "started_at": utc_now(),
              "run_directory": str(run_dir), "source": None, "metadata": None,
              "artifact": None, "signing": {"status": "unchecked", "distribution_ready": False},
              "log": str(run_dir / "xcodebuild.log"), "error": None}
    _write_json_atomic(run_dir / "report.json", report)
    (run_dir / "xcodebuild.log").write_text("Xcode build has not started.\n", encoding="utf-8")
    try:
        if args.mode == "archive" and args.notes_file:
            try:
                if args.notes_file.stat().st_size > 65536:
                    raise RunError("Release notes file exceeds 64 KiB")
                notes_text = args.notes_file.read_text(encoding="utf-8")
            except (OSError, UnicodeError) as exc:
                raise RunError("Could not read UTF-8 release notes file") from exc
        report["source"] = source_state(executor)
        settings = target_settings(executor, args, run_dir)
        metadata = validate_settings(settings, args)
        report["metadata"] = metadata
        require_command(executor, build_command(args, run_dir), args.timeout_seconds,
                        run_dir / "xcodebuild.log")
        artifact = validate_artifact(args, run_dir, settings, metadata)
        report["artifact"] = artifact
        if args.mode == "archive" and not args.unsigned:
            report["signing"] = {"status": "verified", "distribution_ready": False,
                                 "targets": validate_signatures(executor, artifact,
                                                                metadata["configured_team"])}
        report["status"] = "passed"
    except (Exception, KeyboardInterrupt) as exc:
        report["status"] = "failed"
        report["error"] = "Interrupted" if isinstance(exc, KeyboardInterrupt) else str(exc)
    finally:
        derived = run_dir / "DerivedData"
        try:
            if derived.exists():
                if derived.is_symlink():
                    raise RunError("Owned DerivedData path unexpectedly became a symlink")
                with blocked_termination_signals():
                    shutil.rmtree(derived)
            report["derived_data_retained"] = False
            if report.get("artifact") and args.mode == "check":
                report["artifact"]["retained"] = False
        except (OSError, RunError) as exc:
            report["status"] = "failed"
            report["error"] = f"Could not clean owned DerivedData: {exc}"
            report["derived_data_retained"] = True
        report["finished_at"] = utc_now()
        _write_json_atomic(run_dir / "report.json", report)
        (run_dir / "release-notes.md").write_text(release_notes(args, report, notes_text),
                                                  encoding="utf-8")
    return report


def main(argv=None, executor=None, release_root=None):
    args = parse_args(argv)
    state = InterruptState()
    previous = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
    for sig in previous:
        signal.signal(sig, state.handle)
    try:
        report = execute(args, executor, release_root)
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    print(json.dumps({"status": report["status"], "report": str(Path(report["run_directory"]) / "report.json"),
                      "archive": (report.get("artifact") or {}).get("archive"), "error": report["error"]}))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
