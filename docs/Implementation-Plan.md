# Plan

Refine yarms around the intended user's preference for cool pink, with deliberate light and dark palettes and gentle invitations to enjoy a workout. Keep the established native layout and shared components on `codex/ui-design-system`.

## Scope
- In: adaptive semantic asset colors, increased-contrast variants, welcoming library/empty-state copy, design guidance, contrast calculations, simulator checks, commit and push.
- Out: new workout tracking or gamification, reminders, navigation/storage/player changes, app-icon artwork, device installation, and a pull request.

## Action items
- [x] Inspect the current palette, shared components, library copy, design guide, README/Architecture, and existing UI regression coverage.
- [ ] Set a cool pink palette for light/dark appearance and Increase Contrast; measure white action labels and accent text/icons on all brand surfaces, including pressed treatments.
- [ ] Make populated and empty library copy invite choosing and saving enjoyable workouts, while keeping instructions and error messages precise.
- [ ] Update Design-Language, README, and Architecture with cool pink roles, system appearance behavior, and a clear encouragement principle.
- [ ] Build and run existing folder and large-text UI checks in light/dark appearance; inspect screenshots, then run repository verification and diff checks. No new tests for this reversible color/copy-only change; measure actual asset pairs and retain existing behavior assertions.
- [ ] Record results and remaining device checks, commit the refinements, and push the feature branch.

## Open questions
- None. Use a blue-based rose pink rather than a warm peach tone, retaining the native structure. Treat encouragement as invitations to find, save, and try a workout at the person's own pace. The precise shade can evolve after the intended user's feedback.

## Prior validation and remaining checks

The preceding UI adoption passed 80 tests with 2 expected skips, plus 3 dark-mode UI checks. A simulator warning about an invalid frame dimension appeared while opening the notes keyboard; typing and persistence passed, and its source remains unestablished. This color/copy refinement does not change that layout. Signed-device sharing, live TikTok playback, Files, and hands-on accessibility/keyboard review remain device checks.
