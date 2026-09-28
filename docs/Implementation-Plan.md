# Plan

Address the P2 note-ordering gap found on PR #12. Add a store-level restore-then-enrichment regression with the short link saved first, then make the shared note policy retain only distinct paragraph occurrences while preserving each saved note's intentional repeats. The original checkup implementation and validation remain recorded at commit `9c1f05c`.

## Scope
- In: `WorkoutStore` note combination, focused store regressions, architecture note semantics, opt-in restore benchmark, simulator validation, and the Codex feedback acknowledgment.
- Out: workout identity, folder and alias trust rules, UI changes, backup schema changes, and the deferred library-presentation refactor.

## Action items
- [x] Inspect the Codex P2 example, the current shared note helper, backup and coalescing tests, and `docs/Architecture.md`.
- [ ] Commit this resolved plan as a local safety checkpoint on `codex/checkup-followups`.
- [ ] Add a failing restore-then-enrich test with an older short link, and paragraph-order cases that preserve intentional repeats and distinct partial text.
- [ ] Update the shared note policy so prior paragraph occurrences are not appended again when they appear inside a later combined note.
- [ ] Update `docs/Architecture.md` to match the actual note semantics and verification limits.
- [ ] Run targeted store tests, the opt-in restore scaling benchmark, the full simulator suite, unsigned simulator build, and repository verification.
- [ ] Commit and push the fix, acknowledge the addressed Codex comment, then follow the refreshed PR checks and mergeability to terminal state.

## Open questions
- None. The user requested the full PR review cycle; the P2 behavior and expected earliest-save ordering are clear.
