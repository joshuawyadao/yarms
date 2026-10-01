# Plan

Prepare the cool-pink UI update on `codex/ui-design-system` for review against current `main`. Preserve main's storage fixes and documentation structure, reconcile the design guidance, and shepherd a pull request through review and CI without merging it.

## Scope
- In: merge current main, reconcile documentation, validate the integrated app, open a draft PR, run Brooks and Codex review, address actionable feedback and CI failures, and push the completed branch.
- Out: additional product features, redesign changes beyond review fixes, personal device data or artifacts, and the final PR merge.

## Action items
- [x] Inspect branch history, main's documentation and storage changes, the PR template, CI configuration, and existing UI coverage.
- [x] Merge main while preserving both the design-system work and newer storage/test behavior; resolve README, Architecture, and active-plan conflicts from their source intent.
- [x] Update the documentation index, repository map, Design and Assets, User Guide, Testing, README, and Architecture to reference the canonical Design Language and describe adaptive folder controls.
- [x] Run repository checks and the integrated simulator suite; retain meaningful UI assertions and isolated synthetic test data. No new tests are needed for documentation reconciliation; add focused regressions only for executable review fixes.
- [ ] Commit and push the integration, open and attach a draft PR, and request Codex review.
- [ ] Run a scoped Brooks review, record findings in the review ledger and history, and address actionable review or CI findings with targeted validation.
- [ ] Verify current checks, review state, and mergeability; record any concrete blocker and leave the PR unmerged.

## Open questions
- None. The user authorized the PR workflow. Preserve the calm, playful cool-pink direction and native light/dark support; further design feedback follows the intended user's hands-on review.

## Integration and review evidence

- Resolved conflicts in README, Architecture, and this active plan. Preserved main's documentation navigation, diagrams, and current storage/test improvements; added design-language links and UI-specific guidance.
- Scoped Brooks review: 100/100, no actionable findings across six production risks and the quick test check. The large but cohesive UI diff was sampled at its highest-risk presentation and interaction boundaries; generated project wiring was excluded.
- Documentation links and repository checks pass. No additional test source changes were needed for integration. Integrated simulator suite on iPhone 17e / iOS 26.5: 89 passed, two expected skips (signed-device Keychain and opt-in restore benchmark), zero failures, including all eight UI tests. GitHub review/check status will be recorded before handoff.
