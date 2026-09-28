# Plan

Address the remaining Codex findings on PR #12. Correct the documented precedence of restored notes, then make paragraph merging stream through the existing and incoming strings so a valid near-10 MB backup cannot allocate millions of temporary components. The reverse-order note behavior and its validation remain recorded at commit `b7aba40`.

## Scope
- In: `docs/Architecture.md`, the private shared note helper in `YarmsApp/WorkoutStore.swift`, focused edge-case validation, and the PR review/CI follow-up.
- Out: backup schema or size-limit changes, UI changes, workout identity/folder/alias rules, and the deferred library-presentation refactor.

## Action items
- [x] Inspect the two new Codex comments, backup size validation, current note helper, and restore-order test.
- [x] Commit this resolved plan as a local checkpoint on `codex/checkup-followups` (`0c3bf57`).
- [x] Correct `docs/Architecture.md` to distinguish current-note precedence during restore from earliest-save precedence during enrichment; verify, commit, push, and acknowledge the P3 comment.
- [ ] Replace eager paragraph arrays with streaming ranges and occurrence counts in `WorkoutStore.swift`, retaining the tested note order and intentional repeats.
- [ ] Exercise a large delimiter-heavy but valid backup alongside focused note tests, then run the restore benchmark, full simulator suite, simulator build, and repository verification.
- [ ] Commit and push the P2 fix, acknowledge its Codex comment, and follow fresh review, CI, and mergeability to terminal state.

## Open questions
- None. The two review findings are bounded and have explicit expected behavior.
