# Design and assets

[Documentation index](README.md) · [Design language](Design-Language.md) · [Repository map](Repository-Map.md) · [UI verification](Testing.md)

The UI uses the approved Yarms app icon, semantic colors, system fonts, and SF Symbols. The installed display name and library title are **yarms**; the Share extension title is **Save to yarms**. Swift types, the Xcode scheme, and prose use **Yarms**.

## Icon and color source

The [asset catalog](../Assets/Assets.xcassets/) contains the [1024 × 1024 app icon](../Assets/Assets.xcassets/AppIcon.appiconset/AppIcon.png) and six named color sets. Each color has light, dark, and increased-contrast appearances. Keep the existing catalog names stable because SwiftUI views look them up by string. The [design language](Design-Language.md#color-choose-by-purpose) records the current palette and component rules.

| Color | Role in the app |
| --- | --- |
| [AccentColor](../Assets/Assets.xcassets/AccentColor.colorset/Contents.json) | Text, icons, and controls; lighter in dark mode |
| [YarmsAction](../Assets/Assets.xcassets/YarmsAction.colorset/Contents.json) | Native Paste tint, filled Open in TikTok action, selected folder chips, and swipe Move |
| [YarmsCanvas](../Assets/Assets.xcassets/YarmsCanvas.colorset/Contents.json) | Screen and notes-editor backgrounds |
| [YarmsSurface](../Assets/Assets.xcassets/YarmsSurface.colorset/Contents.json) | Cards, notes container, bottom action area |
| [YarmsSoft](../Assets/Assets.xcassets/YarmsSoft.colorset/Contents.json) | Unselected chips, playback buttons, placeholders, subtle borders |
| [YarmsBloom](../Assets/Assets.xcassets/YarmsBloom.colorset/Contents.json) | Brief decorative bloom behind a successful-save checkmark, never essential text or a selection cue |

The catalog JSON is the authority for color values; the [design language](Design-Language.md#color-choose-by-purpose) has the single human-readable reference table. Avoid copying hex values into Swift or other guides. `YarmsAction` is deliberately separate from the text accent so white labels remain readable in dark mode. Changing one requires checking the actual foreground/background pairing in light, dark, and increased-contrast appearances. [YarmsTheme.swift](../YarmsApp/YarmsTheme.swift) exposes the shared roles and action styles, while [YarmsUIComponents.swift](../YarmsApp/YarmsUIComponents.swift) contains reusable folder, workout-card, and empty-state content.

## Layout and accessibility

| Surface | Rules to preserve |
| --- | --- |
| Library | Save card, folder section, and workout rows share a vertical list; avoid a fixed header that squeezes rows out at large text sizes |
| Folder selection | Horizontal chips with counts, checkmarks, and selected VoiceOver state for smaller collections. At accessibility text sizes, with more than six named folders, or when a name exceeds 24 characters, a labeled picker opens a native sheet with wrapping names, counts, and explicit selection |
| Workout cards | Thumbnail or SF Symbol placeholder, title, available creator, and folder; a source-link subtitle distinguishes untitled links |
| Workout screen | Heading above a portrait player, optional notes below, and controls plus full-width Open in TikTok in a bottom safe-area inset |
| Player sizing | 16:9 height-to-width portrait region; content capped at 600 points with 16-point horizontal padding |
| Playback controls | Four 44 × 44 point buttons; readiness/error state controls availability; VoiceOver labels name each action |
| Notes | Explicit Save action, keyboard Done button, and persisted text after reopening/relaunching |
| Workout completion | Finish workout below the player opens a native, dismissible “Good Job BUNS!” sheet with a smiling pink heart; scrollable at large text, no completion history |
| Destructive actions | Confirm workout/folder deletion; explain what data remains |

Use semantic system fonts so Dynamic Type can scale. Keep visible text/VoiceOver meaning alongside symbols and colors. Verify light/dark/increased-contrast appearances, long titles/folder names, missing metadata, large text, keyboard focus, and scrolling using the [test/device checklist](Testing.md). Do not describe simulator layout assertions as a full accessibility audit.

Save confirmations and the completion modal's supporting text use adaptive primary foreground for readable contrast on the pink canvas. Save-result announcements use low priority and originate in successful action handlers; they do not move VoiceOver focus or replay when a view redraws.

## Motion

Shared controls use a small, brief press compression; folder selection, counts, folder badges, and arriving thumbnails have local transitions. Inline save confirmations retain their text after a one-shot pink bloom. Reduce Motion disables these custom animations while preserving static feedback. The [motion contract](Design-Language.md#icons-and-motion) defines timing, triggers, and exclusions; `YarmsMotion` and `YarmsSaveConfirmation` keep those choices consistent. The explicit Finish workout action opens a native sheet with one short smiling-heart/sparkle animation; Reduce Motion shows the same art statically. It requests a pause from a ready embedded player without automatically resuming after dismissal. Other navigation, playback controls, and the Share extension retain their native behavior and timing.

## Graphics in repository documentation

The root README reuses the checked-in icon rather than maintaining a duplicate. The [architecture guide](Architecture.md) uses Mermaid for the capture/enrichment flow and player message sequence; [Data and privacy](Data-and-Privacy.md) diagrams restore validation and commit boundaries. GitHub renders those fenced blocks, and adjacent prose explains the same behavior for readers without diagram support.

When updating a flow, update its diagram and explanatory text together. Keep node labels brief, avoid color-only meaning, and check rendered labels/arrows at a normal reading width. Prefer these source-controlled diagrams for technical flows rather than screenshots of text.

If adding product screenshots later, capture a real build using an isolated synthetic library. Include useful alt text, identify the screen/state and light/dark appearance, and remove private links, notes, account details, and device identifiers. Do not present a generated mockup as an implemented screen. See [Contributing](../CONTRIBUTING.md) for public-data rules.
