#!/usr/bin/env python3
"""Capture the two input phases of Chapter 6 process 46."""
import hashlib
import json
from pathlib import Path
import struct

from capture_bowling_component import ROOT, ROM, WALKING, run

UPDATE = 0x021FD0EC
OUTPUT = ROOT / "extracted/reference/component-label-peel-followup"
FIXTURE = ROOT / "Tests/Fixtures/LabelPeel/process-46-followup.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def process_base(data):
    for offset in range(0x200000, len(data) - 0x6000, 4):
        vtable, = struct.unpack_from("<I", data, offset)
        if 0x021FCB40 < vtable < 0x02210000:
            callback, = struct.unpack_from("<I", data, vtable - 0x02000000 + 16)
            if callback == UPDATE:
                return offset
    raise ValueError("No overlay 22 process 46 was found")


def snapshot(path):
    data = path.read_bytes()
    base = process_base(data)
    mask = data[base + 0x4E8:base + 0x4E8 + 0x5000]
    return {
        "processAddress": hex(base + 0x02000000),
        "state": list(struct.unpack_from("<3h", data, base + 0x2A8)),
        "maskClearPixels": sum(value == 0 or value >= 128 for value in mask),
        "maskPixelCount": len(mask),
        "selected": data[base + 0x301] != 0,
        "selectedObject": struct.unpack_from("<I", data, base + 0x304)[0],
        "sourceFollowupFlag": data[base + 0x478],
        "dragTimer": struct.unpack_from("<i", data, base + 0x2B8)[0],
        "followupTimer": struct.unpack_from("<i", data, base + 0x2B4)[0],
        "dragWorldCoordinates": [
            struct.unpack_from("<i", data, base + offset)[0]
            for offset in (0x46C, 0x470, 0x47C, 0x480)
        ],
    }


def capture():
    # The view uses 192 x 256 page coordinates. Raw DS touch is 256 x 192,
    # with pageX = rawY and pageY = 255 - rawX.
    raw_x = list(range(47, 208, 2))
    raw_y = list(range(31, 160, 2))
    commands = [
        f"load {WALKING}", "write32 0227d2f0 2e", "write32 0227d2f4 2e",
        "frames 300",
    ]
    for row, y in enumerate(raw_y):
        xs = raw_x if row % 2 == 0 else reversed(raw_x)
        for x in xs:
            commands.extend((f"touch {x} {y}", "frames 1"))
    commands.extend((
        "release", "frames 1", "capture release-1", "frames 1", "capture release-2",
        "frames 3", "capture return-animation", "frames 55", "capture animation-60",
        "frames 5", "capture followup", "save peeled",
    ))

    for index in range(1, 6):
        commands.extend(("touch 180 150", "frames 1"))
        for step in range(1, 19):
            commands.extend((f"touch {180 - step} {150 - step}", "frames 1"))
        commands.extend(("release", "frames 12", f"capture drag-{index}"))

    trace = run("component-label-peel-followup", commands)
    names = (
        "release-1", "release-2", "return-animation", "animation-60", "followup",
        *(f"drag-{index}" for index in range(1, 6)),
    )
    states = {name: snapshot(trace / f"{name}-ram.bin") for name in names}
    if states["followup"]["maskClearPixels"] < 20_378:
        raise RuntimeError("The source label mask did not reach its 99.5% threshold")

    directions = {}
    for name, target in {
        "raw-x-increase": (198, 150),
        "raw-x-decrease": (162, 150),
        "raw-y-increase": (180, 168),
        "raw-y-decrease": (180, 132),
    }.items():
        commands = [f"load {trace / 'peeled.mln'}", "frames 2"]
        for _ in range(5):
            commands.extend(("touch 180 150", "frames 1"))
            distance = max(abs(target[0] - 180), abs(target[1] - 150))
            for step in range(1, distance + 1):
                x = 180 + (target[0] - 180) * step // distance
                y = 150 + (target[1] - 150) * step // distance
                commands.extend((f"touch {x} {y}", "frames 1"))
            commands.extend(("release", "frames 12"))
        commands.extend(("capture final",))
        direction_trace = run(f"component-label-peel-{name}", commands)
        directions[name] = snapshot(direction_trace / "final-ram.bin")

    corner_commands = [f"load {trace / 'peeled.mln'}", "frames 2", "touch 195 160", "frames 1", "capture grabbed"]
    for step in range(1, 16):
        corner_commands.extend((f"touch {195 - step} {160 - step}", "frames 1", f"capture step-{step}"))
    corner_commands.extend(("release", "frames 1", "capture released"))
    corner_trace = run("component-label-peel-corner-pixels", corner_commands)
    corner = {
        name: snapshot(corner_trace / f"{name}-ram.bin")
        for name in ("grabbed", "step-2", "step-6", "step-15", "released")
    }

    FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    FIXTURE.write_text(json.dumps({
        "schemaVersion": 1,
        "kind": "isolated process 46 input trace",
        "note": "The source mask and follow-up drag are captured from an injected walking checkpoint. This does not verify a normal Chapter 6 route or a successful process return.",
        "romSHA256": digest(ROM),
        "walkingCheckpointSHA256": digest(WALKING),
        "commandsSHA256": digest(trace / "commands.txt"),
        "touchTransform": "pageX = rawY; pageY = 255 - rawX",
        "sourceStateFields": "+0x478 follow-up flag, +0x2b8 drag timer, +0x2b4 phase timer",
        "followupGesture": "Five repeated drags from raw (180,150) to (162,132).",
        "states": states,
        "followupDirectionProbes": directions,
        "cornerSlowProbe": {
            "gesture": "Start raw (195,160), then move one raw pixel per frame diagonally towards (180,145).",
            "commandsSHA256": digest(corner_trace / "commands.txt"),
            "states": corner,
        },
    }, indent=2) + "\n")


if __name__ == "__main__":
    capture()
