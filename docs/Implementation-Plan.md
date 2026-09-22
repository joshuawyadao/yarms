# Plan

Turn the foundation's shared-link inbox into a durable, searchable local workout library. Persist each link before any network request, resolve supported TikTok short links, and enrich saved workouts through oEmbed while retaining usable entries when network or metadata fails.

## Scope
- In: local workout records, inbox import and duplicate handling, metadata and short-link resolution, searchable library UI with thumbnails and paste fallback, tests and documentation.
- Out: workout notes, custom playback controls, export/import, account sync, and video downloads.

## Action items
[x] Inspect the merged foundation source, docs, and tests; create a fresh branch from latest `main`.
[ ] Add a versioned on-device workout store that imports each inbox file idempotently and removes it only after an atomic library save.
[ ] Add short-link resolution and TikTok oEmbed metadata fetching with safe URL validation and graceful network failure.
[ ] Replace the pending-link shell with a searchable library that displays available thumbnail, creator, and title; keep paste saving immediate and preserve Open in TikTok.
[ ] Add focused tests for inbox import, duplicate links, corrupt/missing metadata, URL resolution, search, and offline fallback.
[ ] Update README, architecture, progress, and implementation docs; run simulator build, tests, and repository verification.
[ ] Review privacy, redirect hosts, race/crash recovery, empty and failed-network states before PR review.

## Open questions
- None. Keep all personal workout data on device and preserve the original shared link even if enrichment fails.
