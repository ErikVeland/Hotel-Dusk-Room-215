#!/usr/bin/env python3
"""Capture isolated process 44 ball-to-pin collision updates."""
import hashlib
import json
import struct

from capture_bowling_component import ROOT, run, find_process, pin_state

PROCESS = 0x02310020
UPDATE = 0x021FD530
ROLL = ROOT / "extracted/reference/component-bowling-camera-input/roll-23.mln"

CASES = {
    "head-on": ((0, 0, 2_000), (0, 0, -200)),
    "diagonal": ((500, 0, 2_000), (-50, 0, -200)),
    "near-edge": ((2_000, 0, 2_000), (0, 0, -200)),
    "stationary-overlap": ((0, 0, 2_000), (0, 0, 0)),
    "outer-edge": ((3_000, 0, 2_000), (0, 0, -200)),
    "moving-away-overlap": ((0, 0, 2_000), (0, 0, 200)),
    "moving-away-slow": ((0, 0, 2_000), (0, 0, 100)),
    "moving-away-fast": ((0, 0, 2_000), (0, 0, 400)),
    "moving-away-diagonal": ((500, 0, 2_000), (50, 0, 200)),
    "axial-graze": ((0, 0, 3_700), (0, 0, -200)),
    "axial-miss": ((0, 0, 3_800), (0, 0, -200)),
    "axial-edge": ((0, 0, 4_100), (0, 0, -200)),
    "axial-clear": ((0, 0, 4_200), (0, 0, -200)),
}


def capture(name, ball_position, ball_velocity):
    commands = [f"load {ROLL}"]
    for index in range(10):
        pin = PROCESS + 0x558 + index * 0x60
        position = (0, 0, 0) if index == 0 else (1_000_000 + index * 100_000, 0, 1_000_000)
        for offset, value in zip((0, 4, 8), position):
            commands.append(f"write32 {pin + offset:x} {value & 0xffffffff:x}")
        for offset in (0x24, 0x28, 0x2C, 0x3C, 0x48):
            commands.append(f"write32 {pin + offset:x} 0")
        commands.append(f"write32 {pin + 0x5C:x} {int(index == 0) << 8:x}")
    for offset, value in zip((0x4F8, 0x4FC, 0x500), ball_position):
        commands.append(f"write32 {PROCESS + offset:x} {value & 0xffffffff:x}")
    for offset, value in zip((0x51C, 0x520, 0x524), ball_velocity):
        commands.append(f"write32 {PROCESS + offset:x} {value & 0xffffffff:x}")
    commands.extend(("capture before", "frames 1", "capture after"))
    directory = run(f"component-bowling-ball-pin-{name}", commands)
    states = {}
    source_radius_components = None
    for state_name in ("before", "after"):
        data = (directory / f"{state_name}-ram.bin").read_bytes()
        base = find_process(data, UPDATE)
        if state_name == "before":
            source_radius_components = [
                struct.unpack_from("<f", data, 0x02204D4C - 0x02000000)[0],
                struct.unpack_from("<f", data, 0x02204D78 - 0x02000000)[0],
            ]
        states[state_name] = {
            "ballPositionFixed20_12": list(struct.unpack_from("<3i", data, base + 0x4F8)),
            "ballVelocityFixed20_12": list(struct.unpack_from("<3i", data, base + 0x51C)),
            "pinStates": [pin_state(data, base, index) for index in range(10)],
        }
    return {
        "commandsSHA256": hashlib.sha256((directory / "commands.txt").read_bytes()).hexdigest(),
        "sourceBallPinRadiusComponents": source_radius_components,
        "states": states,
    }


def main():
    payload = {
        "schemaVersion": 1,
        "kind": "modified-checkpoint isolated ball-to-pin collision captures",
        "romSHA256": hashlib.sha256((ROOT / "Source/ROM/Hotel Dusk - Room 215.nds").read_bytes()).hexdigest(),
        "checkpointSHA256": hashlib.sha256(ROLL.read_bytes()).hexdigest(),
        "processID": 44,
        "update": f"0x{UPDATE:08X}",
        "note": "Each case starts from the captured roll-23 checkpoint, enables pin 0 only, parks the other pins and writes ball position and velocity before one source update. These are isolated component captures, not normal Chapter 8 route evidence.",
        "cases": {name: {"input": {"ballPositionFixed20_12": list(position),
                                   "ballVelocityFixed20_12": list(velocity)}, **capture(name, position, velocity)}
                  for name, (position, velocity) in CASES.items()},
    }
    target = ROOT / "Tests/Fixtures/Bowling/ball-pin-collisions.json"
    target.write_text(json.dumps(payload, indent=2) + "\n")
    print(target)


if __name__ == "__main__":
    main()
