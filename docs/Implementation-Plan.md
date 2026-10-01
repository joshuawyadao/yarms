# Plan

Give yarms a gentle, consistent motion language across saving, browsing, organization, and notes. Use brief interaction feedback and an inline saved checkmark with a small pink bloom, keep playback and scrolling steady, and honor Reduce Motion.

## Scope
- In: shared motion and press treatments, folder selection and count feedback, thumbnail fades, truthful save confirmations, focused UI regression coverage, documentation, validation, and a saved feature branch.
- Out: looping decoration, sounds, haptics, delayed actions, custom system navigation or Share Sheet presentations, storage changes, third-party dependencies, and a pull request.

## Action items
- [x] Inspect the design language, user guide, design/assets guide, testing/development docs, shared components, library/player state changes, and current UI tests.
- [x] Checkpoint this resolved plan on a feature branch using the save-branch guardrails.
- [x] Add reusable short motion tokens, accessible press feedback, and a one-shot saved confirmation; keep confirmation text available after the flourish ends.
- [x] Apply scoped motion to folder controls, thumbnail arrival, library save feedback, note saving, and playback button presses; avoid animating metadata refreshes, search typing, playback time, or whole screens.
- [x] Extend UI tests for success feedback, duplicate saves, editing after saving, persistence, and Reduce Motion; reuse existing folder, deletion, and large-text coverage.
- [ ] Verify rapid actions, failed saves, stable control targets, cancellation of pending effects, dark/light appearance, large text, and Reduce Motion. Run repository checks, simulator build, focused tests, and the full scheme.
- [x] Update Design-Language.md, Design-and-Assets.md, User-Guide.md, Testing.md, and Repository-Map.md with implemented behavior and validation limits.
- [ ] Review the scoped diff, record validation, commit coherent checkpoints, and push the completed branch.

## Open questions
- None. The user approved creating and saving `codex/gentle-app-motion`; use native presentation and no added completion delays.

## Implementation decisions

- Keep library result replacement and search immediate; animate only local controls, counts, image arrival, folder badges, and successful-save feedback. This prevents list-wide movement and preserves scroll position.
- Compare pending imports with persisted records so opening an existing library cannot trigger false save feedback. A duplicate paste selects All and reports that the workout is already saved.
- Use a shared internal motion environment that combines the real system preference with preview/debug-test overrides; Apple’s native Reduce Motion environment is read-only.
- Reuse existing Swift files and project membership. No storage schema, dependencies, signing, or extension lifecycle changes.

## Validation in progress

- The simulator app and extension build passes after replacing the read-only native accessibility environment override with the shared policy. Repository and whitespace checks pass.
- Focused normal/reduced-motion paste tests passed. The notes test exposed a cursor-position assumption: saved notes trim surrounding whitespace, so the assertion now checks the complete edited value after normal trimming. Full-suite validation includes this stronger assertion.
- A read-only review found no actionable regression in save/import/lifecycle or note feedback. Success stays behind persistence, and pending-import detection uses persisted records.
