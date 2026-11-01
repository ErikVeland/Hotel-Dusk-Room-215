# TestFlight beta

The beta uses bundle ID `com.veland.hoteldusk.duo`, version `0.1`, and signing team `54WU29TRTY`.
The archive command sets the build number. Use a new number for each upload.
The complete original game is not yet verified as playable. See [current game status](../README.md).

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
     bash tools/archive_testflight.sh 2
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
  -archivePath .build/testflight/HotelDusk-2.xcarchive \
  -exportPath .build/testflight/export-2 \
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
