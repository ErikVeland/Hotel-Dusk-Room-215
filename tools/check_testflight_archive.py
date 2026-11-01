#!/usr/bin/env python3
"""Check local archive metadata and size before App Store Connect validation."""
import argparse
from pathlib import Path
import plistlib


def check(archive):
    apps = list((archive / 'Products/Applications').glob('*.app'))
    if len(apps) != 1:
        raise ValueError('The archive must contain exactly one app.')
    app = apps[0]
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != 'com.veland.hoteldusk.duo':
        raise ValueError('The archive has the wrong bundle identifier.')
    if info.get('ITSAppUsesNonExemptEncryption') is not False:
        raise ValueError('The encryption declaration is missing.')
    if not info.get('NSMicrophoneUsageDescription') or not info.get('CFBundleIcons'):
        raise ValueError('The microphone purpose or app icon is missing.')
    privacy = plistlib.loads((app / 'PrivacyInfo.xcprivacy').read_bytes())
    reasons = {entry['NSPrivacyAccessedAPIType']: entry['NSPrivacyAccessedAPITypeReasons']
               for entry in privacy['NSPrivacyAccessedAPITypes']}
    if 'CA92.1' not in reasons.get('NSPrivacyAccessedAPICategoryUserDefaults', []):
        raise ValueError('The local-preferences privacy declaration is missing.')
    if 'C617.1' not in reasons.get('NSPrivacyAccessedAPICategoryFileTimestamp', []):
        raise ValueError('The save-file metadata privacy declaration is missing.')
    if not list((archive / 'dSYMs').glob('*.app.dSYM')):
        raise ValueError('The archive has no app crash symbols.')
    size = sum(path.stat().st_size for path in app.rglob('*') if path.is_file())
    if size >= 4_000_000_000:
        raise ValueError(f'The app is {size:,} bytes. Reduce it below 4 GB before uploading.')
    print(f"Archive checks passed: version {info['CFBundleShortVersionString']} "
          f"({info['CFBundleVersion']}), {size:,} bytes.")
    print('Apple validation and physical-device testing are separate checks.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    try:
        check(args.archive)
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f'Archive check failed: {error}\n')
