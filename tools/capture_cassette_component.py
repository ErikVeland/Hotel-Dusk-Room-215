#!/usr/bin/env python3
"""Capture overlay 25 touch phases from an isolated walking checkpoint."""
import hashlib
import json
from pathlib import Path
import struct

from capture_bowling_component import ROOT, ROM, WALKING, run

UPDATE = 0x021FD3BC


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def process_base(data):
    for offset in range(0x200000, len(data) - 0x1970, 4):
        vtable, = struct.unpack_from("<I", data, offset)
        if 0x021FCB40 < vtable < 0x02210000:
            update, = struct.unpack_from("<I", data, vtable - 0x02000000 + 16)
            if update == UPDATE:
                return offset
    raise ValueError("No overlay 25 process was found in the captured RAM")


def snapshot(path):
    data = path.read_bytes()
    base = process_base(data)

    def signed16(offset):
        return struct.unpack_from("<h", data, base + offset)[0]

    return {
        "processBase": hex(base + 0x02000000),
        "variant": signed16(0x2A8),
        "mainPhase": signed16(0x2AA),
        "inputPhase": signed16(0x43A),
        "inputTimer": signed16(0x43C),
        "inputFlags": [data[base + 0x43E], data[base + 0x444]],
        "cursor": [signed16(0x440), signed16(0x442)],
        "dragAccumulator": struct.unpack_from("<f", data, base + 0x4B0)[0],
        "gestureDelta": [signed16(0x4D0), signed16(0x4D2)],
        "gesturePosition": [signed16(0x4D4), signed16(0x4D6)],
        "gestureActive": signed16(0x4D8),
        "dragProgress": struct.unpack_from("<i", data, 0x1FFF38)[0],
        "interactionGate": data[0x10BDA4],
        "strokeCounter": signed16(0x4E4),
    }


def capture_variant(process_id, name):
    variants = {45: 0, 76: 1}
    if process_id not in variants:
        raise ValueError("Only cassette processes 45 and 76 are supported")
    commands = [
        f"load {WALKING}",
        f"write32 0227d2f0 {process_id:x}",
        f"write32 0227d2f4 {process_id:x}",
        "frames 300",
        "capture ready",
        "touch 141 130",
        "frames 1",
        "capture down",
        "touch 140 130",
        "frames 1",
        "touch 139 130",
        "frames 1",
        "touch 138 130",
        "frames 1",
        "touch 137 130",
        "frames 1",
        "touch 136 130",
        "frames 1",
        "touch 135 130",
        "frames 6",
        "capture threshold-crossed",
    ]
    motion_states = []
    capture_steps = {1, 2, 3, 4, 5, 10, 20, 30, 40, 50, 60}
    for y in range(131, 191):
        step = y - 130
        commands.extend([f"touch 135 {y}", "frames 1"])
        if step in capture_steps:
            state = f"slow-swipe-step-{step}"
            commands.extend(["capture " + state])
            motion_states.append(state)
    commands.extend([
        "frames 20",
        "capture held-after-swipe",
        "release",
        "frames 8",
        "capture released",
    ])
    directory = run(name, commands)
    state_names = ["ready", "down", "threshold-crossed", *motion_states,
                   "held-after-swipe", "released"]
    return {
        "processID": process_id,
        "variant": variants[process_id],
        "commandsSHA256": digest(directory / "commands.txt"),
        "states": {
            state: snapshot(directory / f"{state}-ram.bin")
            for state in state_names
        },
    }


def capture_repeated_swipes():
    commands = [
        f"load {WALKING}",
        "write32 0227d2f0 2d",
        "write32 0227d2f4 2d",
        "frames 300",
        "capture ready",
    ]
    state_names = ["ready"]
    for index in range(1, 7):
        commands.extend([
            "touch 141 130",
            "frames 1",
            "touch 135 130",
            "frames 1",
            "touch 135 190",
            "frames 1",
            "frames 30",
            f"capture swipe-{index}-held",
            "release",
            "frames 1",
            "frames 10",
            f"capture swipe-{index}-released",
        ])
        state_names.extend([f"swipe-{index}-held", f"swipe-{index}-released"])
    directory = run("component-cassette-repeated-swipes", commands)
    return {
        "processID": 45,
        "variant": 0,
        "commandsSHA256": digest(directory / "commands.txt"),
        "states": {
            state: snapshot(directory / f"{state}-ram.bin")
            for state in state_names
        },
    }


def capture_rewind_completion():
    commands = [
        f"load {WALKING}",
        "write32 0227d2f0 4c",
        "write32 0227d2f4 4c",
        "frames 300",
        "capture ready",
        "touch 141 130",
        "frames 1",
        "capture down",
    ]
    for x in (140, 139, 138, 137, 136, 135):
        commands.extend([f"touch {x} 130", "frames 1"])
    commands.append("capture x-ready")
    states = ["ready", "down", "x-ready"]
    capture_y = {129, 128, 127, 120, 110, 100}
    for y in range(129, 99, -1):
        commands.extend([f"touch 135 {y}", "frames 1"])
        if y in capture_y:
            state = f"up-{y}"
            commands.extend(["capture " + state])
            states.append(state)
    commands.extend([
        "capture at-y100",
        "frames 65",
        "capture after-65",
        "frames 60",
        "capture after-125",
        "frames 60",
        "capture after-185",
        "frames 60",
        "capture after-245",
        "release",
        "frames 8",
        "capture released-at-phase12",
        "keys ffe",
        "frames 1",
        "capture a-press",
        "keys fff",
        "frames 1",
        "capture a-release",
    ])
    states.extend(["at-y100", "after-65", "after-125", "after-185",
                   "after-245", "released-at-phase12", "a-press", "a-release"])
    directory = run("component-cassette-76-rewind-finish-probe", commands)
    return {
        "processID": 76,
        "variant": 1,
        "commandsSHA256": digest(directory / "commands.txt"),
        "rawTouchPath": "Tap (141, 130), move to raw X 135, then move raw Y from 130 to 100 one pixel per frame. Hold the touch for 245 more frames, then press A.",
        "states": {
            state: snapshot(directory / f"{state}-ram.bin")
            for state in states
        },
    }


def main():
    if not WALKING.exists():
        raise FileNotFoundError(f"Walking checkpoint not found: {WALKING}")
    traces = [
        capture_variant(45, "component-cassette-45-held-trace"),
        capture_variant(76, "component-cassette-76-held-trace"),
    ]
    result = {
        "schemaVersion": 1,
        "kind": "modified-checkpoint-component-test",
        "note": "Records touch-state transitions for isolated overlay 25 processes. It does not establish a normal Chapter 8 route or story return.",
        "romSHA256": digest(ROM),
        "walkingCheckpointSHA256": digest(WALKING),
        "update": hex(UPDATE),
        "rawTouchPath": "Tap (141, 130), move left to (135, 130), then slide down one pixel per frame to (135, 190).",
        "traces": traces,
        "repeatedSwipes": capture_repeated_swipes(),
        "rewindCompletionProbe": capture_rewind_completion(),
    }
    fixture = ROOT / "Tests/Fixtures/Cassette"
    fixture.mkdir(parents=True, exist_ok=True)
    (fixture / "held-touch-trace.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"Captured isolated cassette process states in {fixture}")


if __name__ == "__main__":
    main()
