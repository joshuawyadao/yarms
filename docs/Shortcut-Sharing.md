# Save TikTok workouts from the Share Sheet

[Documentation index](README.md) · [User guide](User-Guide.md) · [Installation](Development.md)

After Yarms is installed, no Shortcut setup is needed. This file keeps its original name so existing links continue to work; the current default is the direct Share extension.

## Save a link

1. In TikTok, open a workout video and tap **Share**.
2. Choose **Save to yarms** in the iOS share sheet. If it is not visible, open **More** and enable or select it. Safari can also share a TikTok video URL.
3. Let the extension finish. If it cannot recognize or save the link, it shows an error.
4. Open or return to Yarms to import the link into the library. New workouts go to **Unfiled**.

The extension accepts a supported TikTok video URL or text containing one. It writes a small pending-link record to the shared on-device Keychain and completes only after that write succeeds. Yarms does not need to open during sharing. Title, creator, and thumbnail are requested later by the app; no video file is downloaded.

If a link seems missing, choose **All** or **Unfiled** and clear search. A recognized duplicate keeps the existing workout. If the extension is absent or saving fails, confirm Yarms still opens, check installation/signing using [Development](Development.md), and use Paste as a fallback.

## Paste or use an existing Shortcut

Copy a TikTok video link, open Yarms, and tap its system **Paste** control. An existing personal Shortcut can instead pass shared text into the **Save TikTok Workout** action's **Shared TikTok Link** parameter. Both paths queue a file in the app's local inbox, which the app imports during refresh. The Shortcut is optional.

For accepted hosts and URL validation, see [Data and privacy](Data-and-Privacy.md#network-boundaries). For the two queue paths, see the [architecture diagram](Architecture.md#components-and-boundaries).

## Installation and upgrades

The Share extension and app need the same signing team and Keychain access group. Each iPhone needs an installation from Xcode. This repository does not provide App Store or TestFlight distribution.

Apple's [Personal Team guidance](https://developer.apple.com/help/account/basics/about-your-developer-account) specifies seven-day provisioning profiles, so free-team installations need periodic rebuilding and reinstalling. Do not delete the app or its data to renew signing. See [Development](Development.md) for setup and [Storage migration](Storage-Migration.md) before replacing an earlier App Group build.
