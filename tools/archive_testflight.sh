#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 || ! $1 =~ ^[1-9][0-9]{0,3}$ ]]; then
    echo "Usage: bash tools/archive_testflight.sh BUILD_NUMBER [--unsigned]" >&2
    echo "Use a build number from 1 to 9999 that has not been uploaded." >&2
    exit 2
fi
if [[ $# -eq 2 && $2 != --unsigned ]]; then
    echo "The second argument must be --unsigned." >&2
    exit 2
fi

cd "$(dirname "$0")/.."
build_number="$1"
archive_name="HotelDusk-${build_number}"
signing_args=(CODE_SIGNING_ALLOWED=YES)
if [[ ${2:-} == --unsigned ]]; then
    archive_name="${archive_name}-unsigned"
    signing_args=(CODE_SIGNING_ALLOWED=NO)
fi
archive_path="$PWD/.build/testflight/${archive_name}.xcarchive"
if [[ -e "$archive_path" ]]; then
    echo "Archive already exists: $archive_path" >&2
    echo "Move the existing archive or use a new build number." >&2
    exit 1
fi

mkdir -p .build/testflight
artwork_python="$PWD/.build/testflight-tools/bin/python"
source_pack="$PWD/Sources/HotelDuskDuoKit/Resources/EnhancedArtwork"
beta_pack="$PWD/.build/testflight/EnhancedArtwork"
if [[ ! -x "$artwork_python" ]]; then
    echo "Create the artwork environment first:" >&2
    echo "python3 -m venv .build/testflight-tools" >&2
    echo ".build/testflight-tools/bin/python -m pip install Pillow==12.0.0" >&2
    exit 1
fi
if [[ -f "$beta_pack/ArtworkManifest.json" ]]; then
    "$artwork_python" - "$source_pack" "$beta_pack" <<'PY'
import hashlib, json, sys
from pathlib import Path
source, beta = map(Path, sys.argv[1:])
manifest = json.loads((beta / 'ArtworkManifest.json').read_text())
expected = hashlib.sha256((source / 'ArtworkManifest.json').read_bytes()).hexdigest()
exclusions = json.loads(Path('HotelDuskDuo/BetaArtworkExclusions.json').read_text())
packaging = manifest.get('betaPackaging', {})
if packaging.get('sourceManifestSHA256') != expected or packaging.get('originalArtworkFallbacks') != exclusions:
    sys.exit('The beta artwork is stale. Move .build/testflight/EnhancedArtwork, then run this command again.')
PY
else
    "$artwork_python" tools/package_beta_artwork.py "$source_pack" "$beta_pack" \
        --exclusions HotelDuskDuo/BetaArtworkExclusions.json
fi
"$artwork_python" tools/verify_artwork_candidate.py "$beta_pack"
{
    xcodebuild -version
    git rev-parse HEAD
    git status --short
} > ".build/testflight/${archive_name}-source.txt"

xcodebuild -project HotelDuskDuo.xcodeproj \
    -scheme HotelDuskDuoiOS -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath .build/testflight/DerivedData \
    -archivePath "$archive_path" \
    "CURRENT_PROJECT_VERSION=$build_number" \
    "${signing_args[@]}" archive 2>&1 | tee ".build/testflight/${archive_name}.log"

bash tools/install_beta_artwork.sh "$archive_path" "${2:-}"
python3 tools/check_testflight_archive.py "$archive_path"
echo "Archive: $archive_path"
if [[ ${2:-} == --unsigned ]]; then
    echo "This unsigned archive verifies compilation and packaging. It cannot be uploaded."
else
    echo "Open this archive in Xcode Organizer to validate and distribute it."
fi
