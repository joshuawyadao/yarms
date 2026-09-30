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
- [x] Run repository verification, local link/anchor/image checks, diagram syntax/render checks, and a source-to-doc consistency review. No test files need changing because executable behavior is unchanged; use existing PR CI for build/unit/UI validation.
- [x] Push the feature branch and open draft PR #13; request Codex review and run Brooks review. Follow live CI and mergeability in the PR; do not merge.

## Open questions
- None. Keep the existing source structure and use focused documentation plus diagrams to improve readability.

## Validation evidence

- Audited application/shared/extension sources, all test files, asset catalogs, Xcode configuration, scripts, CI, community files, and existing documentation. Source folders remain in place; the repository map records ownership and navigation.
- `./scripts/verify-repository.sh` and `git diff --check` pass. A temporary Markdown parser checked 18 documents and 225 local page, heading-anchor, and image references with no failures.
- Three Mermaid diagrams parsed and rendered in a temporary browser preview; the README icon, navigation, diagrams, and representative guides were visually checked. Rendering tools and previews stay outside the repository.
- Current Apple Personal Team guidance and TikTok embed references were checked against their primary documentation. PR #11 and #12 merge/check history was verified on GitHub.
- No production code or test files changed. Existing CI will run the simulator build and unit/UI suite on the PR; no new signed-device or live TikTok result is claimed.

## PR review handoff

- [PR #13](https://github.com/joshuawyadao/yarms/pull/13) contains the progressive plan, guide, and validation commits. Local Brooks review found no actionable concerns (100/100); its documentation scope does not change production dependencies or behavior. The broad diff reflects the requested whole-repository documentation pass.
- An independent source-to-doc review found no factual discrepancies in capture, storage, backups, note precedence, playback, or assets.
- The GitHub Codex review request was accepted, but the bot [reported an exhausted code-review usage limit](https://github.com/joshuawyadao/yarms/pull/13#issuecomment-5905654516) instead of reviewing. No inline feedback was produced. The PR stays a draft and is not declared merge-ready; request `@codex review` again once review capacity is available.
- Final CI state is reported on the PR rather than hard-coded here while runs are active. Signed-device/live-service checks were not repeated for this documentation-only change.
