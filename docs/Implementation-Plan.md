# Plan

Address the remaining Codex findings on PR #12. Correct the documented precedence of restored notes, then make paragraph merging stream through the existing and incoming strings so a valid near-10 MB backup cannot allocate millions of temporary components. The reverse-order note behavior and its validation remain recorded at commit `b7aba40`.

## Scope
- In: `docs/Architecture.md`, the private shared note helper in `YarmsApp/WorkoutStore.swift`, focused edge-case validation, and the PR review/CI follow-up.
- Out: backup schema or size-limit changes, UI changes, workout identity/folder/alias rules, and the deferred library-presentation refactor.

## Action items
- [x] Inspect the two new Codex comments, backup size validation, current note helper, and restore-order test.
- [x] Commit this resolved plan as a local checkpoint on `codex/checkup-followups` (`0c3bf57`).
- [x] Correct `docs/Architecture.md` to distinguish current-note precedence during restore from earliest-save precedence during enrichment; verify, commit, push, and acknowledge the P3 comment.
- [x] Replace eager paragraph arrays with streaming ranges and occurrence counts in `WorkoutStore.swift`, retaining the tested note order and intentional repeats.
- [x] Exercise a large delimiter-heavy but valid backup alongside focused note tests, then run the restore benchmark, full simulator suite, simulator build, and repository verification.
- [x] Commit the validated P2 fix; use the PR review cycle to push it, acknowledge the comment, and follow fresh review, CI, and mergeability.

## Open questions
- None. The two review findings are bounded and have explicit expected behavior.

## Validation evidence
- The P3 documentation correction was pushed in `5c3537e` and acknowledged on the Codex comment. No executable code changed in that slice.
- A one-off harness restored a valid 9.2 MB backup with 2.3 million paragraph separators. The eager implementation peaked at 153.6 MB RSS; streaming peaked at 64.6 MB, preserved the expected note, and restored it in 0.70 seconds.
- All 50 focused backup, library, and opt-in scaling tests passed on iPhone 18 Pro / iOS 27 (`/tmp/yarms-pr12-stream-targeted.xcresult`). The existing note regressions cover the unchanged semantics; the large-input probe checks allocation behavior without adding a slow routine test to the suite.
- Full simulator suite with opt-in restore benchmark: 89 passed, one signed-device Keychain test skipped, zero failures; all seven UI journeys passed (`/tmp/yarms-pr12-stream-full.xcresult`). Benchmark medians were 0.034935875 and 0.142759416 seconds for 1,000 and 4,000 aliases (4.086×, below the 10× limit).
- The unsigned generic iOS Simulator build, repository verification, and `git diff --check` passed. The known notes-focus frame warning remains non-failing.
