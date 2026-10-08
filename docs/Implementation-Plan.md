# Plan

Make Yarms' motion, accessibility and sharing regressions repeatable from a documented command, then review the complete branch through a GitHub pull request. Reuse the successful local validation approach with disposable simulators and synthetic replay data; keep captured phone payloads and signing artifacts private.

## Scope
- In: a portable macOS simulator test runner, full/feedback/sharing suites, retained results, bounded execution and cleanup, replay preservation regressions, CI integration, documentation, Codex and Brooks review, and narrow review/CI fixes.
- Out: TestFlight, new product features, automatic merging, physical-device installation or personal-library access, and pretending simulator replay proves TikTok's native Share/More taps or human motion/audio comfort.

## Action items
[x] Inspect Testing, Development, Repository Map, the existing XCTest suite, CI and the ignored phone replay harness; identify reusable lifecycle and duplicate-preservation checks.
[x] Add `scripts/test-ios.py` with available iPhone/runtime discovery, a new simulator per run, explicit suite/appearance choices, serial ad-hoc-signed tests, time limits, logs/xcresult/summary, and cleanup that cannot silently pass after failure.
[x] Add host-side tests covering discovery, selection, unsuccessful tests, timeout/interruption, ownership of cleanup and cleanup failure. Extend sharing tests to check original identity/source/notes/folder preservation across replay and relaunch without duplicating existing count-only tests.
[x] Run the maintained host tests in Repository Verify and use the same runner for CI Verify; preserve the unsigned generic build check.
[x] Update Testing, Development and Repository Map with runnable commands, artifact locations and the distinction between deterministic replay and native provider evidence.
[x] Address Codex PR #15's catalog portability finding: use the documented unfiltered `simctl list --json` form, make the fake executor reject unsupported extra operands, run host checks and a real catalog selection, then save/push and acknowledge the review comment. Twenty host tests and real catalog selection passed; fix 2988c22 is pushed and acknowledged.
[x] Finish the full dark rerun and automate native VoiceOver frontend startup. The maintained command passed 96 tests with two expected skips on a fresh iOS 27 simulator without intervention; all native speech/order/focus assertions remained active. Device Hub background startup is recorded, and the shared frontend stays available after owned-device cleanup. Twenty-five host tests passed.
[x] Disable optional verbose test diagnostics with the documented `-collect-test-diagnostics never` flag. The automatic full rerun finalized normally with real exit 0, retained XCTest attachments/logs, zero failed tests and successful owned-simulator/DerivedData cleanup.
[ ] Fix CI 37850982715's observed startup timeout: its report records an owned iOS 26.2 simulator, no test exit code and a 30-second `xcrun` timeout, locating the failure at appearance setup after boot. Increase that operation's bounded budget to 120 seconds and identify the `simctl` subcommand in timeout messages. Existing subprocess timeout/cleanup tests cover semantics; validate this configuration change with host checks and a fresh real CI run, without adding a test that merely mirrors the timeout constant.
[x] Commit and push the implementation, open draft PR #15, attach it to this chat and request Codex review. The catalog P1 finding is fixed and acknowledged; follow-up review of 4211059 found no new issues.
[ ] Run Brooks review on the PR, record a concise review ledger, address actionable feedback and CI failures, and verify final checks and mergeability. Leave the PR unmerged.

## Open questions
- None. Use the latest available iOS runtime and a supported available iPhone type by default; permit explicit runtime/type identifiers for reproducibility. Existing device-specific diagnostics remain local because they depend on private capture provenance and signing profiles.
