# Plan

Address the P2 note-ordering gap found on PR #12. Add a store-level restore-then-enrichment regression with the short link saved first, then make the shared note policy retain only distinct paragraph occurrences while preserving each saved note's intentional repeats. The original checkup implementation and validation remain recorded at commit `9c1f05c`.

## Scope
- In: `WorkoutStore` note combination, focused store regressions, architecture note semantics, opt-in restore benchmark, simulator validation, and the Codex feedback acknowledgment.
- Out: workout identity, folder and alias trust rules, UI changes, backup schema changes, and the deferred library-presentation refactor.

## Action items
- [x] Inspect the Codex P2 example, the current shared note helper, backup and coalescing tests, and `docs/Architecture.md`.
- [x] Commit this resolved plan as a local safety checkpoint on `codex/checkup-followups` (`1915550`).
- [x] Add a failing restore-then-enrich test with an older short link, and paragraph-order cases that preserve intentional repeats and distinct partial text.
- [x] Update the shared note policy so prior paragraph occurrences are not appended again when they appear inside a later combined note.
- [x] Update `docs/Architecture.md` to match the actual note semantics and verification limits.
- [x] Run targeted store tests, the opt-in restore scaling benchmark, the full simulator suite, unsigned simulator build, and repository verification.
- [x] Commit the validated fix; use the PR review cycle to push it, acknowledge the Codex comment, and follow refreshed checks and mergeability.

## Open questions
- None. The user requested the full PR review cycle; the P2 behavior and expected earliest-save ordering are clear.

## Validation evidence
- Before the fix, the new store-level regression and paragraph-order table failed with the exact `Imported\n\nCurrent\n\nImported` duplication reported by Codex (result: `/tmp/yarms-pr12-red.xcresult`).
- After the fix, all 50 targeted backup, library, and opt-in scaling tests passed on iPhone 18 Pro / iOS 27 (`/tmp/yarms-pr12-targeted.xcresult`).
- Full simulator suite with the opt-in benchmark: 89 passed, one signed-device Keychain test skipped, zero failures; all seven UI journeys passed (`/tmp/yarms-pr12-full.xcresult`). Benchmark medians were 0.035767667 and 0.144025042 seconds for 1,000 and 4,000 aliases respectively (4.027×, below the 10× limit).
- The unsigned generic iOS Simulator build, `./scripts/verify-repository.sh`, and `git diff --check` passed. Xcode delayed finalization while collecting optional simulator diagnostics; ending its `simctl diagnose` child after all tests passed allowed Xcode to write a successful result bundle.
