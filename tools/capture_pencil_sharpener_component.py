#!/usr/bin/env python3
"""Capture process 59 from the isolated walking checkpoint."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / ".build/rom-reference/hotel-reference"
ROM = ROOT / "Source/ROM/Hotel Dusk - Room 215.nds"
CHECKPOINT = ROOT / "extracted/reference/component-walking-base/ready.mln"
OUTPUT = ROOT / "extracted/reference/component-process-59-interaction"
FIXTURE = ROOT / "Tests/Fixtures/PencilSharpener/source-trace.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def find_process(data):
    for offset in range(0x200000, len(data) - 0x748, 4):
        vtable, = struct.unpack_from("<I", data, offset)
        if 0x021FCB40 < vtable < 0x02210000:
            callback, = struct.unpack_from("<I", data, vtable - 0x02000000 + 16)
            if callback == 0x021FD074:
                return offset
    raise ValueError("No process 59 with update 0x021FD074")


def snapshot(data):
    base = find_process(data)
    return {
        "state": list(struct.unpack_from("<3h", data, base + 0x2A8)),
        "pencilHeld": data[base + 0x2ED] != 0,
        "exitFlags": [data[base + 0x2EC], data[base + 0x2ED]],
        "touchAndDragWords": list(struct.unpack_from("<8I", data, base + 0x3B8)),
    }


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    commands = [
        f"load {CHECKPOINT}", "write32 0227d2f0 3b", "write32 0227d2f4 3b",
        "frames 420", "capture ready", "save ready",
        "touch 100 100", "frames 20", "capture pencil-held",
        "touch 120 80", "frames 8", "touch 140 60", "frames 8",
        "capture pencil-dragged", "release", "frames 240",
        "capture after-pencil", "touch 15 172", "frames 4",
        "capture exit-requested", "release", "frames 1", "capture exit-plus-1",
        "frames 1", "capture exit-plus-2", "frames 8", "capture exit-plus-10",
        "frames 20", "capture exit-plus-30", "frames 30", "capture exit-plus-60",
        "frames 60", "capture exit-plus-120", "frames 120", "capture exit-plus-240",
    ]
    command_text = "\n".join(commands + ["quit"]) + "\n"
    (OUTPUT / "commands.txt").write_text(command_text)
    with (OUTPUT / "runner.log").open("w") as log:
        subprocess.run([str(RUNNER), str(ROM), str(OUTPUT)], input=command_text,
                       text=True, stdout=log, stderr=subprocess.STDOUT,
                       check=True, cwd=ROOT)

    states = {}
    names = ("ready", "pencil-held", "pencil-dragged", "after-pencil", "exit-requested",
             *(f"exit-plus-{frames}" for frames in (1, 2, 10, 30, 60, 120, 240)))
    for name in names:
        states[name] = snapshot((OUTPUT / f"{name}-ram.bin").read_bytes())
    if not states["pencil-held"]["pencilHeld"]:
        raise RuntimeError("The pencil touch did not enter the held state")
    if states["after-pencil"]["pencilHeld"]:
        raise RuntimeError("The pencil touch did not end after release")
    if states["exit-requested"]["state"][0] != 3:
        raise RuntimeError("The quit touch did not enter source exit state 3")
    fixture = {
        "schemaVersion": 1,
        "kind": "modified-checkpoint process 59 input trace",
        "note": "The trace verifies isolated process input states. It does not verify the Chapter 10 parent event, story return, or ending route.",
        "romSHA256": digest(ROM),
        "checkpointSHA256": digest(CHECKPOINT),
        "commandsSHA256": digest(OUTPUT / "commands.txt"),
        "exitInput": {"rawTouch": [15, 172], "heldFrames": 4},
        "states": states,
    }
    FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    FIXTURE.write_text(json.dumps(fixture, indent=2) + "\n")
    print(f"Captured process 59 input states in {FIXTURE}")


if __name__ == "__main__":
    main()
