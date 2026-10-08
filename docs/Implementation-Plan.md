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
[ ] Finish the full dark rerun and automate native VoiceOver frontend startup. Fresh unattended devices failed speech retrieval and navigation before the modal; the focused test passed after displaying its device in Device Hub, and the next fresh full run's native test passed with Device Hub running but No Selection. Start the active Xcode's Device Hub in the background for iOS 27 full/feedback suites when available, record this setup, test the launch/failure paths, and verify a fresh native regression through the maintained runner. Keep ownership and speech assertions intact; do not terminate the shared frontend during cleanup. The initial full run had 95 passes, one setup failure and two skips, with successful cleanup.
[ ] Commit and push the implementation, open a draft PR, attach it to this chat and request Codex review.
[ ] Run Brooks review on the PR, record a concise review ledger, address actionable feedback and CI failures, and verify final checks and mergeability. Leave the PR unmerged.

## Open questions
- None. Use the latest available iOS runtime and a supported available iPhone type by default; permit explicit runtime/type identifiers for reproducibility. Existing device-specific diagnostics remain local because they depend on private capture provenance and signing profiles.
