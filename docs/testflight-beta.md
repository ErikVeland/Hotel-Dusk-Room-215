# TestFlight beta

The beta uses bundle ID `com.veland.hoteldusk.duo`, version `0.1`, and signing team `54WU29TRTY`.
The archive command sets the build number. Use a new number for each upload.
The complete original game is not yet verified as playable. See [current game status](../README.md).

## Preparation result — 1 November 2026

Version `0.1 (4)` has a signed device archive at `.build/testflight/HotelDusk-4.xcarchive`.
It uses merged revision `3ea2c37c`, including the corrected room labels.
Its archived app size is 2,844,819,695 bytes, down from 6,393,473,687 bytes.
Local metadata, privacy-manifest, crash-symbol, size, and code-signature checks pass.
All 7,564 images in the beta pack pass file-hash, dimension, and recorded-pixel-hash checks.
All 10 focused artwork, notebook, and startup tests pass with the beta pack.

App Store export succeeded. The signed IPA is `.build/testflight/export-4/Hotel Dusk.ipa` (2,795,488,371 bytes).
Its profile has `beta-reports-active` enabled and `get-task-allow` disabled, with no registered-device restriction.
The build has not been uploaded to App Store Connect or assigned to testers.
The source revision, sizes, SHA-256, and verification summary are recorded in `.build/testflight/build-4.json`.

The archive log, export log, and artwork test log are under `.build/testflight`.
Run the focused runtime checks against the beta pack with:

```sh
HOTEL_DUSK_ARTWORK_CANDIDATE="$PWD/.build/testflight/EnhancedArtwork" \
HOTEL_DUSK_NOTEBOOK_CANDIDATE="$PWD/.build/testflight/EnhancedArtwork" \
HOTEL_DUSK_ARTWORK_ANIMATION_SCALE=4 \
swift test --disable-sandbox \
  --filter '\.(ChapterOneArtworkCandidateTests|NotebookArtworkCandidateTests|HotelDuskDuoTests)/'
```

The gameplay verification is **not green**. The refreshed fast run recorded 303 passed Swift tests and one missing-reference skip.
Strict mode reports incomplete coverage because the PNG/WebP comparison reference is absent.
The earlier corrected native run recorded 201 passed tests and 12 failed tests before it was stopped during a lengthy restore test.
The remaining native tests did not complete. These results do not establish full-game beta readiness.

The native failures include lobby camera expectations, the Chapter 2 hanger/suitcase route, bag rendering and transitions,
Chapter 10 shed selection, pamphlet rendering, label peeling, map indicators, and pencil-sharpener behaviour and image dimensions.
Some failures compare original pixel dimensions with enhanced artwork dimensions. Others need route and behaviour investigation.
Do not treat all failures as artwork-only issues.

The detailed reports are in `.build/verification/testflight-merged-fast` and `.build/verification/testflight-native-corrected`.
Resolve or explicitly scope these issues before inviting testers. The device checks below also remain open.

## Create an archive

Use Xcode 27.1 or later to compile the hinge APIs. Use a release of Xcode accepted by App Store Connect.
The commands below select the installed stable Xcode without changing the system selection.

1. Install the artwork tool in a local environment:

   ```sh
   python3 -m venv .build/testflight-tools
   .build/testflight-tools/bin/python -m pip install Pillow==12.0.0
   ```

2. Regenerate the Xcode project after changing `project.yml`:

   ```sh
   xcodegen generate
   ```

3. Run the checks described in [the verification guide](verification.md).
4. Create the archive with an unused build number:

   ```sh
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
     bash tools/archive_testflight.sh 5
   ```

The command prepares a separate beta artwork pack, builds a signed Release archive, and checks its contents and size.
It stores the archive, build log, source revision, and working-tree status under `.build/testflight`.
It refuses to replace an existing archive. It does not upload the build.
An interrupted artwork job leaves no completed manifest. Move its incomplete output directory before retrying.

For compilation checks without signing, append `--unsigned`. An unsigned archive cannot be uploaded.
If signing fails, select the existing team in Xcode and refresh its signing assets.

## Artwork packaging

The source artwork occupies about 6.01 GB. The original app archive occupies about 6.39 GB.
Apple limits iOS apps to [4 GB uncompressed](https://developer.apple.com/help/app-store-connect/reference/app-uploads/maximum-build-file-sizes/).

The beta pack reduces 2,803 enhanced animation images from 8× to 4×.
Scene images retain their existing 4× resolution. All original game resources remain bundled.
The tool preserves the source artwork and checks each resized image after lossless WebP encoding.
It updates the image dimensions and checksums in the separate beta manifest.
The archive command installs this pack, signs the app again with its original identity, and verifies the signature.
Use the archive command for beta builds. Xcode's Archive action alone retains the oversized source artwork pack.

Three enhanced notebook controls have file and pixel checksums that differ from the source manifest.
`HotelDuskDuo/BetaArtworkExclusions.json` records these exceptions. The game continues to use their existing original-artwork fallback.
Other checksum failures stop packaging. A successful package check does not establish visual quality on a device.

## Privacy and export metadata

The bundled privacy manifest declares no tracking or off-device data collection.
It declares `CA92.1` for local preferences and `C617.1` for local save-file metadata.
These reasons follow [Apple's required-reason API documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons).

Microphone samples drive puzzle input in memory. The app does not save or transmit them.
The current code uses Apple's SHA-256 implementation for integrity checks and has no custom encryption implementation.
The generated Info.plist sets `ITSAppUsesNonExemptEncryption` to `NO`.
Recheck these declarations if networking, analytics, or encryption changes.

## Validate and distribute

1. Open the completed `.xcarchive` in Xcode Organizer.
2. Select **Validate App**.
3. Resolve any issues reported by Apple.
4. Select **Distribute App → App Store Connect** when the build is ready to upload.
5. Select the app with bundle ID `com.veland.hoteldusk.duo` in App Store Connect.
6. Wait for build processing to finish.
7. Add the description and test notes from [beta test information](testflight-test-information.md).
8. Supply the feedback email and review contact details.
9. Assign the build to the intended tester group.

External testing also requires Apple's beta review. See [Apple's test-information guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

To export an IPA locally, use the prepared options:

```sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -exportArchive \
  -archivePath .build/testflight/HotelDusk-4.xcarchive \
  -exportPath .build/testflight/export-4 \
  -exportOptionsPlist HotelDuskDuo/ExportOptions-TestFlight.plist \
  -allowProvisioningUpdates
```

This export requires App Store distribution signing assets. The options export locally and retain the chosen build number.
The restricted command path prevents third-party `rsync` versions from interfering with Xcode's copy operation.
Provisioning updates let Xcode use the signed-in account to obtain distribution signing assets.

## Device checks before invitations

- Launch the Release build without Xcode attached.
- Start Chapter 1 and reach the lobby, front desk, bell, and registration.
- Quit during dialogue, then check that Continue restores the same place.
- Check saves during a puzzle and after backgrounding.
- Check notebook writing, erasing, page turns, and saved reading position.
- Check both music sources, mute, interruptions, and volume.
- Deny microphone permission and check the touch alternative.
- Allow microphone permission and check the relevant puzzle input.
- Check portrait and landscape layouts on the supported iPhone and iPad sizes.
- On Duo, fold and reopen during dialogue and during a puzzle.
- Compare the 4× animation pack on the physical display, including transparency and motion.
- Check a beta update over an existing installation without deleting its save.

The local checks cannot replace these device checks or Apple's upload validation.
