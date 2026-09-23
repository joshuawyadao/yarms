# Plan

Address the two suggestions from the Yarms test quality review. Make backup test names describe the behavior they exercise, and add an opt-in measured restore scaling benchmark that can detect a return to expensive large-import behavior without slowing routine PR checks.

## Scope
- In: focused backup test corrections, an opt-in two-size restore benchmark, benchmark documentation, repository and simulator verification.
- Out: app behavior changes and the separate UI integration coverage warning.

## Action items
- [x] Rename the two misleading backup tests and remove the assertion that implies a restore happened when only decode ran.
- [x] Add an opt-in benchmark that measures restore of two archive sizes across repeated fresh stores and checks for a substantial scaling regression.
- [x] Document how to run the benchmark outside the routine CI suite and register any new test file in the Xcode project.
- [x] Run repository verification, the opt-in benchmark, and the normal simulator test suite.
- [x] Commit the test and documentation changes, including the existing review record, and push the current branch.

## Open questions
- None.
