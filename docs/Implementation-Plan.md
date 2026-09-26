# Plan

Create a feature branch and a first design-language proposal for yarms so future UI changes follow shared product principles, tokens, and component rules. Ground the proposal in the existing SwiftUI app and icon palette, and illustrate it with an interactive concept for discussion before adopting it in production screens.

## Scope
- In: `codex/ui-design-system`, a proposed `docs/Design-Language.md`, documentation links, and a conversation-only visual concept using invented workout data.
- Out: executable Swift changes, new dependencies, storage changes, a production component library, device installation, and opening or merging a pull request.

## Action items
- [x] Inspect README, Architecture, existing implementation history, color assets, library/player UI, and the current UI tests; create the branch from the current main commit `8068a1a`.
- [x] Record the proposed design language: product principles, color roles, native typography, spacing, shape, icons, motion, content, components, and screen states.
- [x] Define a SwiftUI adoption framework and a short decision checklist that preserve saving, folder organization, playback fallback, notes, and confirmed deletion.
- [x] Link the proposal from README and Architecture while clearly distinguishing proposed standards from implemented behavior.
- [x] Create an interactive conversation concept to explore appearance and component treatment using invented examples.
- [x] Verify local links and repository hygiene with `./scripts/verify-repository.sh`; check palette contrast, document/source consistency, and concept interactions. No app tests need changes or execution because executable app behavior is unchanged.
- [x] Review risks including large text, missing metadata, long folder names, dark mode, unavailable playback, and confirmation/error states; identify device checks for subsequent UI implementation.
- [x] Commit the documented foundation and push the feature branch using save-branch.

## Open questions
- None blocking this proposal. The owner selected calm native iPhone styling with purple accents, then emphasized a fun, playful personality and ease of repeat use. The proposal combines a simple structure with rounded surfaces and encouraging copy. Reference apps and feedback from the intended user can follow later; component treatments and layouts remain open for refinement, not production acceptance.

## Validation results

- Repository structure, local Markdown links, and whitespace checks passed.
- Color references match the existing asset catalog; full-opacity white-on-Action contrast is 8.62:1 in light appearance and 5.19:1 in dark appearance.
- The conversation concept passed JavaScript syntax checking. Browser inspection confirmed folder selection, zero-match search, recovery to all results, and a readable 320-pixel layout in dark appearance, with no console errors observed.
- The concept is illustrative. Its appearance and larger-text design controls do not constitute native Dynamic Type or accessibility verification; simulator/device checks remain requirements for later UI implementation.
- No executable app files or test files changed, so simulator builds and tests were not run.
- The design language incorporates the owner’s preference for calm structure, playful details, and easy repeat use. The README and Architecture link to the proposal without claiming it is implemented.
