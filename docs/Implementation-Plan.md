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
- [x] Commit and push the integration, open and attach a draft PR, and request Codex review.
- [x] Run a scoped Brooks review, record findings in the review ledger and history, and address actionable review or CI findings with targeted validation.
- [ ] Verify current checks, review state, and mergeability; record any concrete blocker and leave the PR unmerged.

## Open questions
- None. The user authorized the PR workflow. Preserve the calm, playful cool-pink direction and native light/dark support; further design feedback follows the intended user's hands-on review.

## Integration and review evidence

- Resolved conflicts in README, Architecture, and this active plan. Preserved main's documentation navigation, diagrams, and current storage/test improvements; added design-language links and UI-specific guidance.
- Scoped Brooks review: 100/100, no actionable findings across six production risks and the quick test check. The large but cohesive UI diff was sampled at its highest-risk presentation and interaction boundaries; generated project wiring was excluded.
- Documentation links and repository checks pass. No additional test source changes were needed for integration. Integrated simulator suite on iPhone 17e / iOS 26.5: 89 passed, two expected skips (signed-device Keychain and opt-in restore benchmark), zero failures, including all eight UI tests. GitHub review/check status will be recorded before handoff.

- Opened [PR #14](https://github.com/joshuawyadao/yarms/pull/14) against main after pushing the integration. Codex review completed for `13aaab7` with no issues raised and no inline review threads; no feedback fixes or reactions were needed.

## CI follow-up plan

CI run `36817024976` passed 88 tests and skipped two, but the new large-text test failed at its initial folder-picker existence assertion on iPhone 16 Pro / iOS 18.5. The same test passes locally on iOS 26.5. Its current order waits for an offscreen lazy-list row before attempting to scroll; CI is the available iOS 18.5 reproduction environment.

- [x] Inspect the failed assertion, test activities, simulator versions, and lazy list composition. Codex review remains clear for the UI implementation.
- [ ] Make the large-text test locate offscreen controls through bounded scrolling before asserting existence and reachability. Preserve all folder, count, selection, search, and Paste assertions; do not change production layout unless runtime evidence requires it.
- [ ] Run the focused test on the available small iPhone simulator, check the diff, and review the test-only change.
- [ ] Save the fix and review evidence, push, then wait for CI's full iOS 18.5 suite and final review/mergeability state. Keep live readiness on PR #14.

No product decision is needed. Check scroll order first; if it does not resolve CI, investigate Dynamic Type launch settings and folder setup rather than weakening assertions.
