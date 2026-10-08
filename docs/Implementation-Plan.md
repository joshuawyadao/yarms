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
[ ] Finish the full dark rerun after diagnosing native VoiceOver startup. Fresh headless devices failed both speech retrieval and native navigation before the modal; the same native-navigation regression passed with its exact disposable device displayed in Device Hub, preserving modal-order and focus-restoration assertions. The full rerun checks whether Device Hub must merely be running or must display each device. Nineteen host tests, the unsigned generic build and all 26 sharing tests passed; the initial full run had 95 passes, one setup failure and two skips, with successful cleanup.
[ ] Commit and push the implementation, open a draft PR, attach it to this chat and request Codex review.
[ ] Run Brooks review on the PR, record a concise review ledger, address actionable feedback and CI failures, and verify final checks and mergeability. Leave the PR unmerged.

## Open questions
- None. Use the latest available iOS runtime and a supported available iPhone type by default; permit explicit runtime/type identifiers for reproducibility. Existing device-specific diagnostics remain local because they depend on private capture provenance and signing profiles.
