#!/usr/bin/env python3
"""Capture the bowling pin-pair positional correction from overlay 11."""
import json
from pathlib import Path

from capture_bowling_component import ROOT, digest, find_process, pin_state, run


def main():
    checkpoint = ROOT / "extracted/reference/component-bowling-camera-input/roll-23.mln"
    checkpoint_ram = checkpoint.with_name(f"{checkpoint.stem}-ram.bin")
    process = find_process(checkpoint_ram.read_bytes(), 0x021FD530) + 0x02000000
    cases = {}
    for axis in ("x", "z"):
        for separation in (100, 300, 600, 900, 1_000, 1_100, 1_200, 1_500):
            positions = ((0, 0, 0), (separation, 0, 0)) if axis == "x" else (
                (0, 0, 0), (0, 0, separation))
            motions = ((200, 0, 0), (0, 0, 0)) if axis == "x" else (
                (0, 0, 200), (0, 0, 0))
            name = f"{axis}-{separation}"
            commands = [f"load {checkpoint}"]
            for index in range(10):
                pin = process + 0x558 + index * 0x60
                position = positions[index] if index < 2 else (1_000_000 + index * 100_000, 0, 1_000_000)
                motion = motions[index] if index < 2 else (0, 0, 0)
                for offset, value in zip((0, 4, 8), position):
                    commands.append(f"write32 {pin + offset:x} {value & 0xffffffff:x}")
                for offset, value in zip((0x24, 0x28, 0x2C), motion):
                    commands.append(f"write32 {pin + offset:x} {value & 0xffffffff:x}")
                for offset in (0x3C, 0x48):
                    commands.append(f"write32 {pin + offset:x} 0")
                active = int(index < 2)
                commands.extend((f"write8 {pin + 0x5C:x} {active:x}",
                                 f"write8 {pin + 0x5D:x} {active:x}"))
            for offset, value in ((0x4F8, 1_000_000), (0x4FC, 0), (0x500, 1_000_000),
                                  (0x51C, 0), (0x520, 0), (0x524, 0)):
                commands.append(f"write32 {process + offset:x} {value:x}")
            commands.extend(("capture before", "frames 1", "capture after"))
            trace = run(f"component-bowling-pin-separation-{name}", commands)
            states = {}
            for state_name in ("before", "after"):
                data = (trace / f"{state_name}-ram.bin").read_bytes()
                base = find_process(data, 0x021FD530)
                states[state_name] = [pin_state(data, base, index) for index in range(2)]
            cases[name] = {
                "commandsSHA256": digest(trace / "commands.txt"),
                "input": {
                    "positionsFixed20_12": positions,
                    "motionsFixed20_12": motions,
                },
                "states": states,
            }

    fixture = {
        "schemaVersion": 1,
        "kind": "modified-checkpoint isolated bowling pin-pair separation sweep",
        "romSHA256": digest(ROOT / "Source/ROM/Hotel Dusk - Room 215.nds"),
        "checkpointSHA256": digest(checkpoint),
        "note": "The ball is parked far from the two active pins. Each case advances one original process update.",
        "cases": cases,
    }
    target = ROOT / "Tests/Fixtures/Bowling/pin-separation-sweep.json"
    target.write_text(json.dumps(fixture, indent=2) + "\n")
    print(f"Captured isolated bowling pin-pair separation in {target}")


if __name__ == "__main__":
    main()
