#!/usr/bin/env python3
"""Capture an isolated original SSAR cue through the ROM's own command runner.

This modifies a verification checkpoint. It is not evidence of story timing.
The runner remains a development oracle and is never used by the Swift game.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=int, required=True)
    parser.add_argument("--entry", type=int, required=True)
    parser.add_argument("--frames", type=int, default=180)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    checkpoint = ROOT / "extracted/reference/opening-queue/frame300.mln"
    ram = (checkpoint.parent / "frame300-ram.bin").read_bytes()
    read = lambda address: struct.unpack_from("<I", ram, address - 0x02000000)[0]
    queue = 0x022543F4
    active = read(queue + 0x298)
    nodes = [read(queue + 0x2A4)]
    nodes.append(read(nodes[-1] + 4))
    nodes.append(read(nodes[-1] + 4))
    objects = [read(active)] + [read(node) for node in nodes]
    assert read(objects[0]) == 0x020FBCB0
    assert read(objects[1]) == 0x020FB52C
    assert read(objects[2]) == read(objects[3]) == 0x020FB58C
    args.output.mkdir(parents=True, exist_ok=False)
    commands = [f"load {checkpoint}"]

    def write32(address, value):
        commands.append(f"write32 {address:08x} {value & 0xFFFFFFFF:08x}")

    def write16(address, value):
        commands.append(f"write16 {address:08x} {value & 0xFFFF:04x}")

    # Keep the existing allocation/list nodes. Replace only source command data.
    write32(objects[0], 0x020FB52C)  # BGM dispatcher 020A5140: stop immediately.
    write16(objects[0] + 4, 1)
    write16(objects[0] + 6, 0)
    write32(objects[1], 0x020FB2D4)  # SE dispatcher 020A51F8: stop all effects.
    for offset, value in [(4, 1), (6, -1), (8, 0), (10, 8)]:
        write16(objects[1] + offset, value)
    write32(objects[2], 0x020FB2D4)
    for offset, value in [(4, 0), (6, args.entry), (8, args.archive)]:
        write16(objects[2] + offset, value)
    write32(objects[3], 0x020FB454)  # Original frame wait, handler 020A3B34.
    write16(objects[3] + 4, 0xFFFF)
    write16(objects[3] + 6, 0)
    write32(nodes[-1] + 4, 0)
    write32(queue + 0x2A8, nodes[-1])
    commands += ["capture fixture-before", f"frames {args.frames}", "capture fixture-after", "quit"]
    text = "\n".join(commands) + "\n"
    (args.output / "commands.txt").write_text(text)
    (args.output / "fixture.json").write_text(json.dumps({
        "kind": "modified-checkpoint-component-test", "archiveID": args.archive, "entryID": args.entry,
        "checkpoint": str(checkpoint.relative_to(ROOT)),
        "checkpointSHA256": hashlib.sha256(checkpoint.read_bytes()).hexdigest(),
        "sourceHandlers": ["020a5140", "020a51f8", "020a3b34"],
        "audio": {"format": "s16le", "sampleRate": 48000, "channels": 2},
        "note": "Commands stop music/effects, play the requested original cue, then wait. This is not a normal story-path trace."
    }, indent=2) + "\n")
    subprocess.run([str(ROOT / ".build/rom-reference/hotel-reference"),
                    str(ROOT / "Source/ROM/Hotel Dusk - Room 215.nds"), str(args.output)],
                   input=text, text=True, check=True)


if __name__ == "__main__":
    main()
