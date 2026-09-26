# Plan

Create a feature branch and a first design-language proposal for yarms so future UI changes follow shared product principles, tokens, and component rules. Ground the proposal in the existing SwiftUI app and icon palette, and illustrate it with an interactive concept for discussion before adopting it in production screens.

## Scope
- In: `codex/ui-design-system`, a proposed `docs/Design-Language.md`, documentation links, and a conversation-only visual concept using invented workout data.
- Out: executable Swift changes, new dependencies, storage changes, a production component library, device installation, and opening or merging a pull request.

## Action items
- [x] Inspect README, Architecture, existing implementation history, color assets, library/player UI, and the current UI tests; create the branch from the current main commit `8068a1a`.
- [ ] Record the proposed design language: product principles, color roles, native typography, spacing, shape, icons, motion, content, components, and screen states.
- [ ] Define a SwiftUI adoption framework and a short decision checklist that preserve saving, folder organization, playback fallback, notes, and confirmed deletion.
- [ ] Link the proposal from README and Architecture while clearly distinguishing proposed standards from implemented behavior.
- [ ] Create an interactive conversation concept to explore appearance and component treatment using invented examples.
- [ ] Verify local links and repository hygiene with `./scripts/verify-repository.sh`; check palette contrast, document/source consistency, and concept interactions. No app tests need changes or execution because executable app behavior is unchanged.
- [ ] Review risks including large text, missing metadata, long folder names, dark mode, unavailable playback, and confirmation/error states; identify device checks for subsequent UI implementation.
- [ ] Commit the documented foundation and push the feature branch using save-branch.

## Open questions
- None blocking this proposal. Calm, focused, native iPhone styling with the existing icon palette is an editable starting assumption; visual preferences remain open for refinement, not production acceptance.
