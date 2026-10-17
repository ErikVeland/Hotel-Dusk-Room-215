#!/usr/bin/env python3
"""Recover audio tables and constants from the original relocated ARM7 image."""
import hashlib
import json
from pathlib import Path
import struct
from resolve_original_globals import arm7_segments, read_bytes

ROOT = Path(__file__).resolve().parents[1]


def recover():
    data = (ROOT / "extracted/recovered_logic/binaries/arm7.bin").read_bytes()
    segments, _ = arm7_segments(data)

    def integer(address):
        return struct.unpack("<I", read_bytes(segments, address, 4))[0]

    def table(pointer, count, format):
        address = integer(pointer)
        raw = read_bytes(segments, address, struct.calcsize(format) * count)
        return {"address": f"{address:08x}", "sha256": hashlib.sha256(raw).hexdigest(),
                "values": list(struct.unpack("<" + format * count, raw))}

    result = {
        "schemaVersion": 1,
        "sourceARM7_SHA256": hashlib.sha256(data).hexdigest(),
        "attack": table(0x03800158, 19, "B"),
        "attenuation": table(0x0380020C, 128, "h"),
        "modulationSine": table(0x037FF504, 33, "b"),
        "channelOrder": table(0x038000D4, 16, "B"),
        "initialEnvelope": struct.unpack("<i", read_bytes(segments, 0x037FFAF4, 4))[0],
        "randomSeed": integer(integer(0x037FF490)),
        "randomMultiplier": integer(0x037FF494),
        "randomIncrement": integer(0x037FF498),
        "driverAlarmInterval": integer(0x037FF810),
        "sources": {
            "random": "037ff468", "attack": "03800138", "decayRelease": "037ffba4",
            "envelope": "0380015c", "voiceMix": "038002ec", "trackMix": "038015f4",
            "sequenceTick": "0380189c", "sequenceCommands": "038009d8",
            "driverAlarm": "037ff7c0"
        }
    }
    destination = ROOT / "Sources/HotelDuskDuoKit/Resources/Original/Audio/OriginalSoundDriver.json"
    destination.write_text(json.dumps(result, indent=2) + "\n")
    return result


if __name__ == "__main__":
    result = recover()
    print(f"Recovered ARM7 envelope, attenuation, modulation and random tables: {result['sourceARM7_SHA256']}")
