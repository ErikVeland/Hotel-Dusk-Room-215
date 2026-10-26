#!/usr/bin/env python3
"""Bundle the original text renderer's music and sound lookup tables."""
import json
import hashlib
import struct
from pathlib import Path
from recover_original_runtime_tables import recover

ROOT = Path(__file__).resolve().parents[1]


def main():
    source = recover()
    result = {
        "schemaVersion": 1,
        "arm9SHA256": source["arm9SHA256"],
        "textHandler": "0204370c",
        "music": [{"name": row["name"], "sequenceID": row["sequenceID"]}
                  for row in source["music"]],
        # 0200AD94 output 1 is the entry ID; output 2 is the archive ID.
        "sounds": [{"code": row["name"], "archiveID": row["output2"], "entryID": row["output1"]}
                   for row in source["sounds"]],
    }
    maps = (ROOT / "extracted/root/data/map/sdata/mapsound.bin").read_bytes()
    count, = struct.unpack_from("<I", maps)
    assert len(maps) == 4 + count * 24
    result["mapSoundSHA256"] = hashlib.sha256(maps).hexdigest()
    result["maps"] = []
    for index in range(count):
        offset = 4 + index * 24
        name = maps[offset:offset + 8].split(b"\0")[0].decode("ascii")
        # 020B5940 resolves BGM_ names, maps "none" to -1 and defaults to -2.
        sequence = next((r["sequenceID"] for r in source["music"] if r["name"] == name), -1)
        if name != "none" and not name.startswith("BGM_"):
            sequence = -2
        def sound_at(field):
            code = maps[offset + field:offset + field + 8].split(b"\0")[0].decode("ascii")
            cue = next((row for row in result["sounds"] if row["code"] == code), None)
            return None if cue is None else {"archiveID": cue["archiveID"], "entryID": cue["entryID"]}
        result["maps"].append({"mapID": index + 1, "sequenceID": sequence,
                               "footstep": sound_at(8), "ambient": sound_at(16)})
    path = ROOT / "Sources/HotelDuskDuoKit/Resources/Original/Audio/OriginalDialogueAudio.json"
    path.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Bundled {len(result['music'])} music and {len(result['sounds'])} sound mappings.")


if __name__ == "__main__":
    main()
