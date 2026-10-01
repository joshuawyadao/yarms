# Plan

Prepare the cool-pink UI update on `codex/ui-design-system` for review against current `main`. Preserve main's storage fixes and documentation structure, reconcile the design guidance, and shepherd a pull request through review and CI without merging it.

## Scope
- In: merge current main, reconcile documentation, validate the integrated app, open a draft PR, run Brooks and Codex review, address actionable feedback and CI failures, and push the completed branch.
- Out: additional product features, redesign changes beyond review fixes, personal device data or artifacts, and the final PR merge.

## Action items
- [x] Inspect branch history, main's documentation and storage changes, the PR template, CI configuration, and existing UI coverage.
- [ ] Merge main while preserving both the design-system work and newer storage/test behavior; resolve README, Architecture, and active-plan conflicts from their source intent.
- [ ] Update the documentation index, repository map, Design and Assets, User Guide, Testing, README, and Architecture to reference the canonical Design Language and describe adaptive folder controls.
- [ ] Run repository checks and the integrated simulator suite; retain meaningful UI assertions and isolated synthetic test data. No new tests are needed for documentation reconciliation; add focused regressions only for executable review fixes.
- [ ] Commit and push the integration, open and attach a draft PR, and request Codex review.
- [ ] Run a scoped Brooks review, record findings in the review ledger and history, and address actionable review or CI findings with targeted validation.
- [ ] Verify current checks, review state, and mergeability; record any concrete blocker and leave the PR unmerged.

## Open questions
- None. The user authorized the PR workflow. Preserve the calm, playful cool-pink direction and native light/dark support; further design feedback follows the intended user's hands-on review.
