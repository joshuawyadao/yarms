# MVP roadmap

Yarms keeps workout links and personal notes on the iPhone. It requires no app account. This roadmap is delivered through small reviewed PRs, each merged into `main` after review and green checks.

1. **Foundation, share, and player validation:** SwiftUI app, approved icon, share extension, immediate local link inbox, paste fallback, official TikTok embedded player for canonical video links, and CI build/tests.
2. **Saving and library:** Resolve short links, fetch oEmbed title/creator/thumbnail when available, keep a durable local collection, and search it. A metadata failure must not lose a saved link.
3. **Workout player and notes:** Put the video first, add simple playback controls and optional local notes, and retain the Open in TikTok fallback.
4. **Backup and polish:** Export and restore a user-owned backup, complete empty/error/accessibility states, and verify the final main build and tests.

Yarms does not download TikTok posts or bypass creator download settings. Playback depends on TikTok's official player and the post remaining available.

The original share extension in milestone 1 required App Groups, which the owner's free Personal Team could not sign. A follow-up replaces it with a one-time [Shortcuts share-sheet setup](Shortcut-Sharing.md) and an app-local Save TikTok Workout action. The workout library, player, notes, paste fallback, and backup behavior remain in the app.
