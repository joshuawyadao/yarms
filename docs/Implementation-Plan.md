# Plan

Address the three project-checkup findings with focused correctness and test changes. Preserve the current UI, workout identity and ordering, folder assignments, alias trust, and backup compatibility while making note combination consistent and verifying real redirect and player behavior.

## Scope
- In: shared distinct-note policy, restore-then-enrichment regressions, controlled redirect transport coverage with a negative control, deterministic player behavior tests, layout-warning investigation, architecture documentation, validation, commits, and branch push.
- Out: broad library-presentation refactor, schema changes, new third-party services, UI redesign, PR creation, and physical-device/live TikTok claims without a fresh device check.

## Action items
- [x] Inspect the current baseline, `docs/Architecture.md`, existing store/backup/player/metadata tests, and the previous checkup evidence; baseline was clean detached `8068a1a`.
- [x] Confirm the target branch and commit this resolved plan as the first local checkpoint (`e45b2ac` on `codex/checkup-followups`).
- [x] Add a failing store-level restore-then-enrich regression, unify distinct-note combination, and cover repeated imports, multi-paragraph notes, ordering, identity, folders, and aliases.
- [x] Add a controlled redirect transport test that exercises URLSession automatic redirect handling; prove it fails when delegate wiring is removed in an isolated negative-control build.
- [x] Add deterministic behavior tests for readiness, play/pause/end states, time/duration ordering, errors, command gating, and seek bounds through a controlled local WebKit harness.
- [x] Investigate the recorded invalid-frame warning in the player/notes UI journey; the focused replay reproduced it during editor focus without source/backtrace evidence. Document the uncertainty; no app-owned cause was established.
- [x] Update `docs/Architecture.md` for note semantics, test seams, and verification limits; README behavior remains accurate and needs no change.
- [x] Run focused tests for each slice, the documented opt-in restore-scaling benchmark, the full simulator suite, simulator build, and repository verification; checkpoint coherent tested slices locally.
- [x] Audit the completed work against the objective, commit remaining changes and this plan, and push the confirmed branch `codex/checkup-followups`.

## Open questions
- None. The user approved `codex/checkup-followups` for implementation, commits, and push.

## Validation evidence
- Before the note fix, both new store tests failed with the expected duplicate-note assertions (five assertions total). The same simulator run passed the redirect test and all 11 player tests. An earlier test host exited before reporting a result; that interrupted run is not counted.
- Read-only review of all four changed test files found no actionable issues.
- After sharing the note policy, all 66 focused store, metadata, player, and notes UI tests passed on iPhone 18 Pro / iOS 27. The UI journey still reported the non-failing frame warning during note-editor focus.
- The isolated simulator negative control removed only `NoAutomaticRedirects` from the request. The new redirect test failed because requested hosts included `example.com`; the unchanged production wiring passed. No external network was used by the fixture.
- Local checkpoints: plan `e45b2ac`; note fix and store regressions `ecc3f2a`; transport/player tests and architecture documentation `72bc826`.
- The final suite's app-hosted target passed 81 tests and skipped only the signed-device Keychain check. The local player harness compiled without warnings after explicitly isolating its polling callback to the main actor.
- Opt-in restore benchmark passed: median 0.035867125 seconds for 1,000 aliases and 0.146095334 seconds for 4,000 (4.073×, below the 10× limit).
- Final full simulator run with `TEST_RUNNER_YARMS_RUN_BACKUP_BENCHMARK=1`: 88 passed, one signed-device Keychain test skipped, zero failures. All seven UI journeys passed; the known frame warning remained. Result bundle: `/tmp/yarms-followups-full.xcresult`.
- Unsigned generic iOS Simulator build, `./scripts/verify-repository.sh`, and `git diff --check` passed. No app UI, schema, identity, folder, or alias-trust policy changes were needed.
- Physical-device Keychain/Share Sheet, live TikTok playback and metadata, and Files interactions remain release checks. The broader library-presentation refactor remains deferred.
