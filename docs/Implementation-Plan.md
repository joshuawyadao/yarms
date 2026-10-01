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
- [x] Build the simulator app, run targeted then full unit/UI tests, and inspect light/dark and large-text screenshots on available small/large iPhones; check keyboard, missing metadata, empty states, and long folder names.
- [x] Update Design-Language, Architecture, README, and this plan to describe adopted components, current behavior, validation, and any remaining physical-device checks.
- [x] Run repository verification, review the integrated diff, checkpoint coherent work, and push the completed branch.

## Open questions
- None. The user approved applying this direction throughout the app. Keep the icon-derived palette and native iOS controls, with friendly details and no pressure to exercise. Feedback from the intended user will inform a later iteration.

## Validation results

- The simulator app and test bundle build successfully with the two new shared files included in the generated Xcode project. `./scripts/verify-repository.sh` and `git diff --check` pass.
- The focused maximum-text-size UI check passes on iPhone 17e / iOS 26.5. It verifies the folder picker, selected state and counts, filtering, and reaching Paste after a zero-result search.
- Three focused UI checks pass on iPhone 17 Pro Max / iOS 26.5 in dark appearance: folder movement, maximum-text-size library use, and player/notes persistence. The simulator's original light appearance was restored afterward.
- Final full suite passes on iPhone 17e / iOS 26.5: 80 passed, 2 expected skips, 0 failures (72 unit tests plus all 8 UI tests). Skipped cases are the signed-device Keychain entitlement check and the opt-in backup scaling benchmark. `YarmsUITests.swift` retains existing regressions and adds the maximum-text-size folder/Paste scenario.
- Inspected native library and player screenshots in light/dark appearance and the maximum-text-size library on both sizes. This caught a cramped folder heading; its action now stacks below it. Searching hides the welcome text to make room for results. Static review also caught missing visible counts in the folder sheet; those now accompany the accessible counts.
- Earlier large-text checks failed because the test assumed off-screen lazy list rows were already present or scrolled away from Paste. The test now scrolls to the relevant content and dismisses the search keyboard, retaining its selection, filtering, and hittability assertions.
- The first iOS 27 test invocation stalled and was canceled; it is not counted as a pass. Completed runs use iOS 26.5 with bounded execution timeouts.
- Xcode reports an unattributed “Invalid frame dimension (negative or non-finite)” runtime warning when opening the notes keyboard. Typing, Done, saving, and relaunch persistence pass. The warning's source is not established; keyboard layout still needs a physical-device check.

## Remaining device review

- Install the updated branch on an iPhone before the intended user's weekend review. No personal device library was replaced during this change.
- Verify live TikTok playback, Share Sheet capture/Keychain entitlements, and Files import/export on a signed device; simulator UI examples use invented links.
- Complete hands-on VoiceOver, landscape/keyboard, Bold Text, Increase Contrast, and Reduce Motion checks. The automated large-text checks do not establish a full accessibility audit.
- For feedback, ask the intended user to save a workout, find it again, and follow it. Record where she hesitates and which details feel welcoming or distracting, then refine the shared guide and components.
