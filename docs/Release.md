# Release builds and archives

Use the checked-in [Release command](../scripts/release-ios.py) from the repository root on a Mac with Xcode. It builds the app and embedded Share extension in Release, checks their effective configuration and produced bundles, and retains evidence under ignored `.build/releases/`. It does not install on a device, export an IPA, or upload a release.

## Check a Release build

```sh
python3 scripts/release-ios.py check
```

This unsigned generic iOS Simulator build needs no signing account and does not boot a simulator. It checks matching bundle versions, expected identifiers, shared Keychain configuration, extension embedding, and Release compiler settings. It rejects Debug compilation, testability, test bundles, and compiled UI-test control markers in either executable. The temporary UI-test store and reduced-motion override are available only in Debug builds.

The independent **Release Verify** CI job runs this command and keeps its report, log, and notes for seven days. Host tests cover malformed settings, bundle mismatches, signing mismatches, command failures, and command boundaries. A separate compiler regression checks actual inbox behavior in both Debug and Release when `swiftc` is available.

## Create a versioned archive

For a local build without signing:

```sh
python3 scripts/release-ios.py archive --version 1.0.0 --build-number 2 --unsigned
```

For a signed archive, use the same local team for both targets:

```sh
python3 scripts/release-ios.py archive --version 1.0.0 --build-number 2 --team YOUR_TEAM_ID
```

The project does not commit a team. A signed invocation must have a team supplied with `--team` or already configured locally, plus a usable signing identity and profiles. The command uses existing local provisioning; it does not enable automatic profile updates. Follow [Development](Development.md#install-on-an-iphone) for signing setup.

The archive uses generic iOS, Release configuration, and a fresh output directory. Version and build inputs apply to both targets for this invocation without rewriting project settings. The extension retains `SKIP_INSTALL=YES` so it is embedded in the app rather than archived separately. The command requires three numeric components for `--version` and a positive integer for `--build-number`; increment the build for each release candidate. Apple describes these fields in [CFBundleShortVersionString](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleshortversionstring) and [CFBundleVersion](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion).

Pass `--notes-file /path/to/release-notes.md` to include your short user-facing change notes. Without that option, the command writes build metadata and validation notes. `--timeout-seconds` bounds Xcode execution; `--help` lists supported options.

## Read the result

Each invocation prints its retained report path. Its fresh directory contains `report.json`, `xcodebuild.log`, and `release-notes.md`; successful archive invocations also retain `Yarms-<version>-<build>.xcarchive`. The report records source commit and working-tree state, requested mode, versions, paths, validation outcome, signing status, and failure details. Run from a clean saved commit when preparing a candidate that others need to reproduce. Reports and archives stay local and ignored by Git. The `check` command removes its temporary app build products after inspection and marks them as not retained in the report; archive bundles are retained.

A failed Xcode command or failed artifact check returns a nonzero exit status and preserves evidence. An interrupt or timeout stops the command's owned process group. Cleanup removes only that invocation's temporary DerivedData, while retaining reports, logs, and archives.

An unsigned success verifies Release compilation and packaging; signing is explicitly unchecked. A signed success additionally verifies both code signatures, actual team identifiers, application identifiers, and the resolved shared Keychain entitlement. It does not certify profile expiry, distribution eligibility, App Store acceptance, or cross-process Keychain behavior on a phone. Keep the [signed-device checks](Testing.md#signed-iphone-checks) and final distribution review before releasing through TestFlight or the App Store.
