#!/usr/bin/env python3
"""Capture the isolated side-boundary response of bowling overlay 11."""
import json
import math
import struct
from pathlib import Path

from capture_bowling_component import ROOT, digest, find_process, run


def main():
    checkpoint = ROOT / "extracted/reference/component-bowling-camera-input/roll-23.mln"
    ram = checkpoint.with_name(f"{checkpoint.stem}-ram.bin")
    process = find_process(ram.read_bytes(), 0x021FD530) + 0x02000000
    samples = [
        ("inside-flat", 3.0, 0.0),
        ("edge-flat", 3.1, 0.0),
        ("outside-flat", 3.2, 0.0),
        ("outside-quarter-turn", 3.2, math.pi / 2),
        ("outside-half-turn", 3.2, math.pi),
        ("outside-three-quarter-turn", 3.2, 3 * math.pi / 2),
        ("outside-negative", -3.2, 0.0),
    ]
    cases = {}
    for name, x, rotation in samples:
        commands = [f"load {checkpoint}"]
        for index in range(10):
            pin = process + 0x558 + index * 0x60
            position = (round(x * 4096), 0, 0) if index == 0 else (1_000_000 + index * 100_000, 0, 1_000_000)
            for offset, value in zip((0, 4, 8), position):
                commands.append(f"write32 {pin + offset:x} {value & 0xffffffff:x}")
            for offset, value in zip((0x24, 0x28, 0x2C), (0, 0, 0)):
                commands.append(f"write32 {pin + offset:x} {value:x}")
            commands.append(f"write32 {pin + 0x3C:x} {struct.unpack('<I', struct.pack('<f', rotation))[0]:x}")
            commands.append(f"write32 {pin + 0x48:x} 0")
            commands.extend((f"write8 {pin + 0x5C:x} 0", f"write8 {pin + 0x5D:x} 1"))
        for offset, value in ((0x4F8, 1_000_000), (0x4FC, 0), (0x500, 1_000_000),
                              (0x51C, 0), (0x520, 0), (0x524, 0)):
            commands.append(f"write32 {process + offset:x} {value:x}")
        commands.extend(("capture before", "frames 1", "capture after"))
        trace = run(f"component-bowling-pin-boundary-{name}", commands)
        state = {}
        for state_name in ("before", "after"):
            data = (trace / f"{state_name}-ram.bin").read_bytes()
            base = find_process(data, 0x021FD530)
            pin = base + 0x558
            state[state_name] = {
                "positionFixed20_12": list(struct.unpack_from("<3i", data, pin)),
                "rotationFloat": struct.unpack_from("<f", data, pin + 0x3C)[0],
                "angularVelocityFloat": struct.unpack_from("<f", data, pin + 0x48)[0],
            }
        cases[name] = {"commandsSHA256": digest(trace / "commands.txt"),
                       "input": {"x": x, "rotation": rotation}, "states": state}

    fixture = {
        "schemaVersion": 1,
        "kind": "modified-checkpoint isolated pin-boundary captures",
        "romSHA256": digest(ROOT / "Source/ROM/Hotel Dusk - Room 215.nds"),
        "checkpointSHA256": digest(checkpoint),
        "note": "Only pin 0 is near the right or left lane boundary. The ball is parked far away. Each capture advances one original process update.",
        "cases": cases,
    }
    target = ROOT / "Tests/Fixtures/Bowling/pin-boundary-trace.json"
    target.write_text(json.dumps(fixture, indent=2) + "\n")
    print(f"Captured isolated bowling pin boundary response in {target}")


if __name__ == "__main__":
    main()
