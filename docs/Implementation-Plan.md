# Plan

Require the existing full simulator and Release gates and clarify the fast-feedback workflow.

## Scope
- In: Scoped CI enforcement, automated validation, meaningful orchestration regressions, and canonical verification documentation for yarms.
- Out: Product feature changes, deployment, paid services or account changes, personal data, physical-device operation, and release signing/publishing.

## Action items
- [x] Read Testing, TestFlight, workflow classifier and existing runner regression tests.
- [x] Parent configured main-branch enforcement for both CI Verify and Release Verify using observed check names.
- [x] Document host/unit/sharing preflight, full required tests, unsigned Release and manual signed-device boundaries.
- [x] Preserve all current simulator assertions; no redundant tests or changed expected skips.
- [x] Run the existing host/repository tests (56 passed); parent verifies configured rules.
- [ ] Parent saves and pushes the scoped documentation branch.

## Discovery notes
- Baseline: `60704a5da23465f4fc6af8f86fd2a2b765f3c82d` (`origin/main`), isolated from the original checkout.
- Existing in-progress changes in original project folders remain untouched.
- Missing hosting/account capabilities are reported as concrete limitations; they are not permission to weaken required checks.
