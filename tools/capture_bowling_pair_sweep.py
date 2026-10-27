#!/usr/bin/env python3
"""Capture isolated pin-pair responses across contact angles and motion axes."""
import json
from pathlib import Path

from capture_bowling_component import ROOT, digest, find_process, pin_state, run


def main():
    checkpoint = ROOT / "extracted/reference/component-bowling-camera-input/roll-23.mln"
    checkpoint_ram = checkpoint.with_name(f"{checkpoint.stem}-ram.bin")
    process = find_process(checkpoint_ram.read_bytes(), 0x021FD530) + 0x02000000
    cases = {
        "x-contact-x-motion": ((0, 0, 0), (1_500, 0, 0), (200, 0, 0), (0, 0, 0)),
        "x-contact-z-motion": ((0, 0, 0), (1_500, 0, 0), (0, 0, 200), (0, 0, 0)),
        "x-contact-diagonal-motion": ((0, 0, 0), (1_500, 0, 0), (120, 0, 160), (0, 0, 0)),
        "z-contact-x-motion": ((0, 0, 0), (0, 0, 1_500), (200, 0, 0), (0, 0, 0)),
        "z-contact-z-motion": ((0, 0, 0), (0, 0, 1_500), (0, 0, 200), (0, 0, 0)),
        "z-contact-diagonal-motion": ((0, 0, 0), (0, 0, 1_500), (120, 0, 160), (0, 0, 0)),
        "diagonal-contact-x-motion": ((0, 0, 0), (900, 0, 1_200), (200, 0, 0), (0, 0, 0)),
        "diagonal-contact-z-motion": ((0, 0, 0), (900, 0, 1_200), (0, 0, 200), (0, 0, 0)),
        "diagonal-contact-aligned-motion": ((0, 0, 0), (900, 0, 1_200), (120, 0, 160), (0, 0, 0)),
        "reverse-diagonal-contact-aligned-motion": ((900, 0, 1_200), (0, 0, 0), (-120, 0, -160), (0, 0, 0)),
        "negative-x-contact-x-motion": ((1_500, 0, 0), (0, 0, 0), (-200, 0, 0), (0, 0, 0)),
        "negative-z-contact-z-motion": ((0, 0, 1_500), (0, 0, 0), (0, 0, -200), (0, 0, 0)),
    }
    captures = {}
    for name, (first_position, second_position, first_motion, second_motion) in cases.items():
        commands = [f"load {checkpoint}"]
        for index in range(10):
            pin = process + 0x558 + index * 0x60
            position = first_position if index == 0 else second_position if index == 1 else (
                1_000_000 + index * 100_000, 0, 1_000_000)
            motion = first_motion if index == 0 else second_motion if index == 1 else (0, 0, 0)
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
        trace = run(f"component-bowling-pair-sweep-{name}", commands)
        states = {}
        for state_name in ("before", "after"):
            data = (trace / f"{state_name}-ram.bin").read_bytes()
            base = find_process(data, 0x021FD530)
            states[state_name] = [pin_state(data, base, index) for index in range(2)]
        captures[name] = {
            "commandsSHA256": digest(trace / "commands.txt"),
            "input": {
                "positionsFixed20_12": [first_position, second_position],
                "motionsFixed20_12": [first_motion, second_motion],
            },
            "states": states,
        }

    fixture = {
        "schemaVersion": 1,
        "kind": "modified-checkpoint isolated bowling pin-pair response sweep",
        "romSHA256": digest(ROOT / "Source/ROM/Hotel Dusk - Room 215.nds"),
        "checkpointSHA256": digest(checkpoint),
        "note": "The ball is parked far from the two active pins. Each case advances one original process update.",
        "cases": captures,
    }
    target = ROOT / "Tests/Fixtures/Bowling/pin-pair-sweep.json"
    target.write_text(json.dumps(fixture, indent=2) + "\n")
    print(f"Captured isolated bowling pin-pair response sweep in {target}")


if __name__ == "__main__":
    main()
