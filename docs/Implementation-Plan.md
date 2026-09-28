# Plan

Address the three project-checkup findings with focused correctness and test changes. Preserve the current UI, workout identity and ordering, folder assignments, alias trust, and backup compatibility while making note combination consistent and verifying real redirect and player behavior.

## Scope
- In: shared distinct-note policy, restore-then-enrichment regressions, controlled redirect transport coverage with a negative control, deterministic player behavior tests, layout-warning investigation, architecture documentation, validation, commits, and branch push.
- Out: broad library-presentation refactor, schema changes, new third-party services, UI redesign, PR creation, and physical-device/live TikTok claims without a fresh device check.

## Action items
- [x] Inspect the current baseline, `docs/Architecture.md`, existing store/backup/player/metadata tests, and the previous checkup evidence; baseline was clean detached `8068a1a`.
- [ ] Confirm the target branch and commit this resolved plan as the first local checkpoint.
- [ ] Add a failing store-level restore-then-enrich regression, unify distinct-note combination, and cover repeated imports, multi-paragraph notes, ordering, identity, folders, and aliases.
- [ ] Add a controlled redirect transport test that exercises URLSession automatic redirect handling; prove it fails when delegate wiring is removed in an isolated negative-control build.
- [ ] Add deterministic behavior tests for readiness, play/pause/end states, time/duration ordering, errors, command gating, and seek bounds through a production-used seam or controlled local WebKit harness.
- [ ] Investigate the recorded invalid-frame warning in the player/notes UI journey; fix only an established in-scope cause, otherwise record the evidence and remaining uncertainty.
- [ ] Update `docs/Architecture.md` for note semantics, test seams, and verification limits; retain existing README behavior unless the implementation requires clarification.
- [ ] Run focused tests for each slice, the documented opt-in restore-scaling benchmark, the full simulator suite, simulator build, and repository verification; checkpoint coherent tested slices locally.
- [ ] Audit the completed work against the objective, commit remaining changes and this plan, and push the confirmed branch.

## Open questions
- None. The user approved `codex/checkup-followups` for implementation, commits, and push.
