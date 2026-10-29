#!/usr/bin/env python3
"""Capture an isolated source trace of the second Chapter 6 label interaction."""
import hashlib
import json
from pathlib import Path
import struct

from capture_bowling_component import ROOT, ROM, run

PEELED = ROOT / "extracted/reference/component-label-peel-followup/peeled.mln"
REFERENCE = ROOT / "extracted/reference/component-label-peel-followup/followup-ram.bin"
FIXTURE = ROOT / "Tests/Fixtures/LabelPeel/source-transition.json"
UPDATE = 0x021FD0EC


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


def snapshot(path, base, game_state):
    data = path.read_bytes()
    return {
        "state": list(struct.unpack_from("<3h", data, base + 0x2A8)),
        "peelMode": data[base + 0x478],
        "selected": data[base + 0x301] != 0,
        "dragProgress": struct.unpack_from("<i", data, base + 0x47C)[0],
        "dragTimer": struct.unpack_from("<i", data, base + 0x2B8)[0],
        "gameStateWord0xDC": hex(struct.unpack_from("<H", data, game_state)[0]),
    }


def capture():
    if not PEELED.is_file() or not REFERENCE.is_file():
        raise FileNotFoundError("Run tools/capture_label_peel_component.py first")

    reference_data = REFERENCE.read_bytes()
    base = process_base(reference_data)
    context_pointer, = struct.unpack_from("<I", reference_data, 0x021FD274 - 0x02000000)
    game_state = context_pointer + 0xDC - 0x02000000
    process_address = base + 0x02000000

    commands = [
        f"load {PEELED}",
        f"write8 {process_address + 0x478:08x} 1",
        f"write16 {context_pointer + 0xDC:08x} 15c3",
        "frames 2",
    ]
    for index in range(1, 3):
        commands += ["touch 195 160", "frames 1"]
        for step in range(1, 7):
            commands += [f"touch {195 - step} {160 - step}", "frames 1"]
        commands += ["release", "frames 16", f"capture regrab-{index}"]

    for name, start in (("peel-963", (185, 140)), ("peel-792", (180, 135))):
        x, y = start
        commands += [f"touch {x} {y}", "frames 1"]
        for step in range(1, 16):
            commands += [f"touch {x - step} {y - step}", "frames 1"]
        commands += ["release", "frames 20", f"capture {name}"]

    x, y = 170, 120
    commands += [f"touch {x} {y}", "frames 1"]
    for step in range(1, 71):
        commands += [f"touch {x - step} {y - step}", "frames 1"]
        if step in (2, 10, 20, 40, 60, 70):
            commands.append(f"capture long-pull-{step}")
    commands += ["release", "frames 60", "capture wait-60"]
    elapsed = 60
    for delay in (60, 60, 60, 120):
        elapsed += delay
        commands += [f"frames {delay}", f"capture wait-{elapsed}"]
    commands.append("quit")

    trace = run("component-label-peel-source-transition", commands)
    names = (
        "regrab-1", "regrab-2", "peel-963", "peel-792",
        "long-pull-2", "long-pull-10", "long-pull-20", "long-pull-40",
        "long-pull-60", "long-pull-70", "wait-60", "wait-120", "wait-180",
        "wait-240", "wait-360",
    )
    FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    FIXTURE.write_text(json.dumps({
        "schemaVersion": 1,
        "kind": "isolated process 46 source transition trace",
        "note": "This trace forces the process peel flag and game-state word 0xDC. It establishes source input and animation states only, not a normal Chapter 6 story route or a returned branch.",
        "romSHA256": digest(ROM),
        "peeledCheckpointSHA256": digest(PEELED),
        "commandsSHA256": digest(trace / "commands.txt"),
        "processAddress": hex(process_address),
        "gameStateAddress": hex(context_pointer + 0xDC),
        "touchTransform": "pageX = rawY; pageY = 255 - rawX",
        "gestures": [
            "Two short diagonal re-grabs from raw (195,160) to (189,154).",
            "Two diagonal pulls from raw (185,140) and (180,135), each 15 pixels up-left.",
            "One 70-frame diagonal pull from raw (170,120) to (100,50).",
        ],
        "states": {
            name: snapshot(trace / f"{name}-ram.bin", base, game_state)
            for name in names
        },
    }, indent=2) + "\n")


if __name__ == "__main__":
    capture()
