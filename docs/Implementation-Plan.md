# Plan

Apply the approved calm, playful yarms design language across the native app on `codex/ui-design-system`. Introduce shared visual primitives, refresh the library and workout flows, and validate the real SwiftUI experience so it is ready for personal feedback.

## Scope
- In: semantic styling and shared UI components; library/save/folders/empty states; workout/player/notes; native supporting menus, move sheet, Share extension copy and progress; UI regression coverage; current docs; local commits and branch push.
- Out: data-schema or playback-protocol changes, new services, gamification, notifications, opening a PR, and automatically installing over a personal device library.

## Action items
- [x] Map the current SwiftUI and Share extension surfaces, existing UI contracts, Xcode generator, and Design-Language/Architecture/README guidance.
- [x] Add shared theme values, folder badges, action styles, and content components using the existing adaptive asset colors; wire new files into Xcode.
- [x] Apply welcoming copy, unified rounded surfaces, clearer actions, and adaptive folder/row layouts throughout the library while preserving Paste, search, move, delete, and backup behavior.
- [x] Apply shared styling and readable metadata to the workout/player, notes, and supporting flows, preserving the visible TikTok fallback, keyboard controls, confirmation, and persistence semantics.
- [x] Update UI tests for the new hierarchy and add focused large-text/selection coverage without weakening existing save, note, deletion, or compact-control checks.
- [ ] Build the simulator app, run targeted then full unit/UI tests, and inspect light/dark and large-text screenshots on available small/large iPhones; check keyboard, missing metadata, empty states, and long folder names.
- [x] Update Design-Language, Architecture, README, and this plan to describe adopted components, current behavior, validation, and any remaining physical-device checks.
- [ ] Run repository verification, review the integrated diff, checkpoint coherent work, and push the completed branch.

## Open questions
- None. The user approved applying this direction throughout the app. Keep the icon-derived palette and native iOS controls, with friendly details and no pressure to exercise. Feedback from the intended user will inform a later iteration.

## Validation in progress

- Simulator build passes with the new shared Swift files included in the generated project. Repository verification passes.
- Static review found a missing visible count in the full folder picker; each option now shows its count as well as exposing it to accessibility.
- The first iOS 27 focused test invocation stalled and was canceled. The iOS 26.5 rerun uses bounded test timeouts and disables diagnostic collection; runtime results are pending.
- Native PasteButton, native supporting sheets/alerts, existing storage, and player message handling retain their established behavior.
