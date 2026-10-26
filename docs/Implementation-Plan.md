# Plan

Implement the efficiency audit’s immediate recommendations while preserving local-only storage, durable capture, backup validation and native accessibility behavior, then prepare an unmerged PR into main.

## Scope
- In: F01 batched library snapshots and background storage, F02 persisted bounded metadata retries, F03/F04 targeted CI without duplicate builds, F05 deterministic Debug-only UI fixtures, F06 evidence retention and opt-in local pruning, F08 note-heavy restore scaling, F09 direct import normalization, F10 fewer redirect requests; tests and canonical docs.
- Out: new hosting or subscriptions, database migration, physical-device installation, PR merging, and speculative image/player changes. F07’s new large-backup format remains a documented growth follow-up; preserve the current 10 MiB import limit and complete export warning.

## Action items
- [x] Inspect the audit, current source/tests and Architecture, Data-and-Privacy, Development, Release and Testing documentation; branch from current origin/main.
- [x] Stabilize ordinary UI journeys with local metadata/player fixtures scoped to valid Debug test storage; preserve native VoiceOver assertions and Release exclusions.
- [x] Add one-read library refresh and one-commit pending imports, consistent snapshots, unchanged-write avoidance and serialized off-main execution for refresh/enrichment; retain commit-before-acknowledgement and fresh reads for App Intent changes.
- [x] Persist metadata outcomes and retry dates locally; cap attempts, honor Retry-After, pause scheduling while inactive, provide manual retry and skip redundant canonical HEAD requests.
- [x] Remove backup decode round trips without weakening sanitization/size limits; benchmark and improve repeated note merging while preserving paragraph occurrence and precedence.
- [x] Gate macOS CI by relevant changes and successful fast checks, remove the redundant generic Debug build, retain stable required statuses and compact evidence, and add preview-first local pruning/phase metrics.
- [x] Extend focused storage/retry/network/fixture and host tests for failures, replays, stale writes, size limits, no external UI networking and protected evidence; run targeted checks, full simulator tests and unsigned Release verification.
- [x] Update Architecture, Data-and-Privacy, Testing, Development, Release and repository map as appropriate with actual behavior, measurements and deferred limits.
- [x] Checkpoint coherent changes, push this branch, open/attach draft PR #16, run Brooks and Codex review and save the review fixes. Keep the remaining CI/review readiness loop on the PR; final status is reported after fresh terminal checks without merging.
- [x] Address Codex P2 comment 4355584117: retain short-link resolver failure classification and Retry-After when combining it with oEmbed results, while preserving useful metadata and redirect validation.
- [x] Add controlled-network regressions for timeout plus successful metadata, transient HEAD plus permanent oEmbed response, and the later retry delay; run app tests and repository verification, update Architecture/Testing/Efficiency. App suite: 103 passed, zero failures and three expected skips; owned cleanup succeeded. Repository checks: 54 passed.
- [ ] Recheck final CI, Codex feedback and mergeability without merging PR #16.

## Open questions
- None. Keep the existing backup format and cost-free architecture; measure or document conditional follow-ups rather than adding infrastructure.

## Checkpoint validation
- Host verifier: 54 passing tests; Swift syntax parsing and worker storage typechecking passed. Unsigned Release verification passed. Full local iOS 26.5: 113 passed, zero failures and four expected skips; cleanup succeeded. All five hosted checks passed on 465d030. Codex found the remaining transient-resolution classification issue; no successful iOS 27 accessibility result is claimed.
