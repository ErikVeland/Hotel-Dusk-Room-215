#!/usr/bin/env python3
"""Attenuate native sampler output to the supplied recordings' measured RMS.

Both sources retain their dynamics. A shared 3 dB margin leaves headroom for
the measured phrase peaks. Calibration is tied to both exact resource manifests.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", type=Path)
    args = parser.parse_args()
    profile = json.loads(args.profile.read_text())
    assert profile["note"].startswith("One complete native introduction and loop")
    assert [row["id"] for row in profile["tracks"]] == list(range(36))
    resource = ROOT / "Sources/HotelDuskDuoKit/Resources"
    native = resource / "Original/Audio/OriginalAudioManifest.json"
    recorded = resource / "RecordedMusic/manifest.json"
    common = math.pow(10, -3 / 20)
    rows = []
    for row in profile["tracks"]:
        # Runtime profiles include raw and calibrated measurements. Derive
        # gains from the raw pair to avoid applying the current balance twice.
        native_measurement = row.get("unbalancedNative", row.get("native"))
        recorded_measurement = row.get("unbalancedRecorded", row.get("recorded"))
        assert native_measurement is not None and recorded_measurement is not None, "Profile needs raw source measurements"
        delta = recorded_measurement["rmsDBFS"] - native_measurement["rmsDBFS"]
        assert math.isfinite(delta) and delta < 0, "Calibration must not amplify either source"
        gain = common * math.pow(10, delta / 20)
        assert native_measurement["peakDBFS"] + 20 * math.log10(gain) < 0
        assert recorded_measurement["peakDBFS"] - 3 < 0
        rows.append({"id": row["id"], "nativeGain": gain, "recordedGain": common})
    result = {"schemaVersion": 1, "method": "Whole native introduction and loop RMS; both sources attenuated, shared 3 dB headroom.",
              "profileSHA256": hashlib.sha256(args.profile.read_bytes()).hexdigest(),
              "nativeManifestSHA256": hashlib.sha256(native.read_bytes()).hexdigest(),
              "recordedManifestSHA256": hashlib.sha256(recorded.read_bytes()).hexdigest(), "tracks": rows}
    (resource / "RecordedMusic/balance.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"Calibrated {len(rows)} cues with 3 dB shared headroom.")


if __name__ == "__main__":
    main()
