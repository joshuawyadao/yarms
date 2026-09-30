# Plan

Make the whole Yarms repository easier to navigate, use, and maintain. Audit the latest source, tests, configuration, and existing docs, then publish focused guides and source-based diagrams with progressive commits on `feat/repository-documentation`.

## Scope
- In: README and contributor onboarding, a documentation index and repository map, user and troubleshooting guidance, development/testing instructions, architecture and storage/privacy references, asset guidance, and current progress records.
- Out: application behavior changes, source-folder moves, new dependencies, invented screenshots, and claims that unperformed device checks passed.

## Action items
- [x] Inspect the existing docs, source layout, tests, project generator, assets, and CI; start from current `origin/main` (`05d866a`, including PR #12).
- [x] Commit this resolved plan before documentation edits; preserve earlier implementation plans in Git history.
- [x] Delegate the independent developer, test, and repository-map guides with explicit file ownership; audit app, capture, storage, backup, and playback behavior in the parent task.
- [x] Add `docs/README.md`, shorten the root README into an entry point, and update `CONTRIBUTING.md` with usable navigation and maintenance expectations.
- [x] Add `docs/User-Guide.md`, `docs/Data-and-Privacy.md`, and `docs/Design-and-Assets.md`; restructure `docs/Architecture.md` with accessible Mermaid diagrams and textual explanations.
- [x] Add `docs/Development.md`, `docs/Testing.md`, and `docs/Repository-Map.md`; verify commands, file ownership, target wiring, test limitations, and all tracked-file coverage.
- [x] Refresh sharing, migration, roadmap, and progress documentation, keeping historical validation separate from current limitations; checkpoint each coherent slice.
- [ ] Run repository verification, local link/anchor/image checks, diagram syntax/render checks, and a source-to-doc consistency review. No test files need changing because executable behavior is unchanged; use existing PR CI for build/unit/UI validation.
- [ ] Push the feature branch, open a draft PR, request Codex review, run Brooks review, and follow checks and mergeability to a terminal result without merging.

## Open questions
- None. Keep the existing source structure and use focused documentation plus diagrams to improve readability.
