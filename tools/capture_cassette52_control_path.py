#!/usr/bin/env python3
"""Capture process 52 control input after its normal scene transition."""
import hashlib
import json
import struct

from capture_bowling_component import WALKING, find_process, run

UPDATE = 0x021FD888
PROCESS = 52
PROCESS_BASE = 0x022D1C20


def capture_state(directory, name):
    data = (directory / f"{name}-ram.bin").read_bytes()
    base = find_process(data, UPDATE)
    return {
        "mainPhase": struct.unpack_from("<h", data, base + 0x2AE)[0],
        "inputPhase": struct.unpack_from("<h", data, base + 0x43E)[0],
        "cursor": list(struct.unpack_from("<2h", data, base + 0x440)),
        "selector": struct.unpack_from("<h", data, base + 0x5B4)[0],
        "touchActive": data[0x020FD86B - 0x02000000] != 0,
        "ramSHA256": hashlib.sha256((directory / f"{name}-ram.bin").read_bytes()).hexdigest(),
    }


def main():
    commands = [
        f"load {WALKING}", "release", "frames 1",
        f"write32 0227d2f0 {PROCESS:x}", f"write32 0227d2f4 {PROCESS:x}",
        "frames 300", "touch 76 156", "frames 1",
    ]
    for y in range(155, 107, -1):
        commands.extend((f"touch 76 {y}", "frames 1"))
    commands.extend(("frames 180", "release", "frames 8", "capture controls-ready",
                     "touch 47 47", "frames 1", "capture control-tap",
                     "release", "frames 1", "capture released", "frames 20",
                     "capture idle-20"))
    directory = run("component-cassette52-normal-control-tap", commands)
    payload = {
        "schemaVersion": 1,
        "kind": "normal input after isolated process 52 scene transition",
        "processID": PROCESS,
        "overlay": 28,
        "update": f"0x{UPDATE:08X}",
        "romSHA256": hashlib.sha256((directory.parents[2] / "Source/ROM/Hotel Dusk - Room 215.nds").read_bytes()).hexdigest(),
        "walkingCheckpointSHA256": hashlib.sha256(WALKING.read_bytes()).hexdigest(),
        "commandsSHA256": hashlib.sha256((directory / "commands.txt").read_bytes()).hexdigest(),
        "controlTapRawTouch": [47, 47],
        "states": {name: capture_state(directory, name)
                   for name in ("controls-ready", "control-tap", "released", "idle-20")},
        "note": "The process starts from a walking checkpoint. The scene opens through touch input. The control tap follows that transition without writing the input phase. This does not test the story event that launches process 52.",
    }
    target = directory.parents[2] / "Tests/Fixtures/Cassette/process-52-normal-control-tap.json"
    target.write_text(json.dumps(payload, indent=2) + "\n")
    print(target)


if __name__ == "__main__":
    main()
