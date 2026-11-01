#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
archive_path="${1:?Supply the archive path.}"
source_pack="$PWD/.build/testflight/EnhancedArtwork"
app_path="$archive_path/Products/Applications/Hotel Dusk.app"
target_pack="$app_path/HotelDuskDuo_HotelDuskDuoKit.bundle/EnhancedArtwork"
if [[ ! -f "$source_pack/ArtworkManifest.json" ]]; then
    echo "error: Prepare the beta artwork with tools/archive_testflight.sh before archiving." >&2
    exit 1
fi
if [[ ! -d "$target_pack" ]]; then
    echo "error: The built game resource bundle is missing." >&2
    exit 1
fi
signing_identity=""
if [[ ${2:-} != --unsigned ]]; then
    signing_identity="$(/usr/bin/codesign -d --verbose=2 "$app_path" 2>&1 | sed -n 's/^Authority=//p' | sed -n '1p')"
    if [[ -z "$signing_identity" ]]; then
        echo "error: The archive has no signing identity to preserve." >&2
        exit 1
    fi
fi
# Replace the archived resource copy, then restore its original signing identity.
/usr/bin/rsync -a --delete "$source_pack/" "$target_pack/"
if [[ -n "$signing_identity" ]]; then
    /usr/bin/codesign --force --sign "$signing_identity" \
        --preserve-metadata=identifier,entitlements,requirements,flags,runtime "$app_path"
    /usr/bin/codesign --verify --deep --strict "$app_path"
fi
