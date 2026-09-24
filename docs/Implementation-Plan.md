# Plan

Use lowercase `yarms` for the iPhone Home Screen label, the library title, and the Share Sheet action. Keep the existing Xcode target, module, and bundle identifiers so signing and stored data continue to use the same app identity.

## Scope
- In: app and Share extension display names, library title, matching sharing instructions, and direct verification of the built app's Info.plist.
- Out: target and bundle identifier renames, backup format changes, and general copy editing beyond the visible titles.

## Action items
- [x] Set the main app and Share extension display names in the checked-in Xcode project, project generator, and Share extension Info.plist.
- [x] Change the library navigation title to `yarms`. Skip new tests that would only mirror a literal display label; inspect the built metadata and run the existing UI flow instead.
- [x] Update README and sharing instructions so the Share Sheet action name matches the app.
- [x] Verify project generation preserves the names, inspect built Info.plist values, run the focused UI test and repository checks, and confirm signing remains valid. The signed app builds; its display name is `yarms`, the Share extension is `Save to yarms`, and the focused UI test passes.
- [x] Prepare the verified branch for commit and push with only title-related files staged.

## Open questions
- None.
