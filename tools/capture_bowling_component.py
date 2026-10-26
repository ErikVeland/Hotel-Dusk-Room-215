#!/usr/bin/env python3
"""Capture process 44 from a valid walking checkpoint in the ROM reference runner.

This is a modified-checkpoint component trace. It does not establish a normal
Chapter 8 route or bowling completion.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / ".build/rom-reference/hotel-reference"
ROM = ROOT / "Source/ROM/Hotel Dusk - Room 215.nds"
WALKING = ROOT / "extracted/reference/component-walking-base/ready.mln"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(name, commands):
    directory = ROOT / "extracted/reference" / name
    directory.mkdir(exist_ok=True)
    text = "\n".join(commands + ["quit"]) + "\n"
    (directory / "commands.txt").write_text(text)
    with (directory / "runner.log").open("w") as log:
        subprocess.run([str(RUNNER), str(ROM), str(directory)], input=text, text=True,
                       stdout=log, stderr=subprocess.STDOUT, check=True, cwd=ROOT)
    return directory


def find_process(data, update):
    for offset in range(0x200000, len(data) - 0x748, 4):
        vtable, = struct.unpack_from("<I", data, offset)
        if 0x021FCB40 < vtable < 0x02210000:
            callback, = struct.unpack_from("<I", data, vtable - 0x02000000 + 16)
            if callback == update:
                return offset
    raise ValueError(f"No process with update {update:08x}")


def snapshot(data, base):
    return {
        "update": "0x021FD530",
        "stage": struct.unpack_from("<h", data, base + 0x2AC)[0],
        "substage": struct.unpack_from("<h", data, base + 0x2AE)[0],
        "roundIndex": struct.unpack_from("<h", data, base + 0x9AE)[0],
        "cameraMatrix": list(struct.unpack_from("<16i", data, base + 0x2B4)),
    }


def capture_centre_roll(ready_checkpoint):
    commands = [f"load {ready_checkpoint}", "touch 15 90", "frames 8"]
    for x in range(23, 120, 8):
        commands += [f"touch {x} 90", "frames 8"]
    commands += ["touch 125 90", "frames 8", "release", "frames 180", "capture roll"]
    trace = run("component-bowling-centre-roll", commands)
    data = (trace / "roll-ram.bin").read_bytes()
    base = find_process(data, 0x021FD530)
    rotations = [struct.unpack_from("<i", data, base + 0x594 + index * 0x60)[0]
                 for index in range(10)]
    return {
        "romSHA256": digest(ROM),
        "checkpointSHA256": digest(ready_checkpoint),
        "commandsSHA256": digest(trace / "commands.txt"),
        "update": "0x021FD530",
        "processBase": hex(base),
        "stage": struct.unpack_from("<h", data, base + 0x2AC)[0],
        "substage": struct.unpack_from("<h", data, base + 0x2AE)[0],
        "roundIndex": struct.unpack_from("<h", data, base + 0x9AE)[0],
        "dragDelta20_12": list(struct.unpack_from("<6i", data, base + 0x504)),
        "pinRotations": rotations,
        "score": sum(rotation != 0 for rotation in rotations),
        "touchPath": "Start at (15, 90), move right in eight-pixel steps through (119, 90), then move to (125, 90). Hold each point for eight frames.",
        "captureAfterFrames": 180,
    }


def capture_roll_path(ready_checkpoint, raw_y):
    commands = [f"load {ready_checkpoint}", f"touch 15 {raw_y}", "frames 8"]
    for x in range(23, 120, 8):
        commands += [f"touch {x} {raw_y}", "frames 8"]
    commands += [f"touch 125 {raw_y}", "frames 8", "release", "frames 180", "capture roll"]
    command_text = "\n".join(commands + ["quit"]) + "\n"
    with tempfile.TemporaryDirectory(prefix="hotel-dusk-bowling-") as temporary:
        directory = Path(temporary)
        command_file = directory / "commands.txt"
        command_file.write_text(command_text)
        subprocess.run([str(RUNNER), str(ROM), str(directory)], input=command_text, text=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT, check=True, cwd=ROOT)
        data = (directory / "roll-ram.bin").read_bytes()
    base = find_process(data, 0x021FD530)
    rotations = [struct.unpack_from("<i", data, base + 0x594 + index * 0x60)[0]
                 for index in range(10)]
    return {
        "rawTouchY": raw_y,
        "commandsSHA256": hashlib.sha256(command_text.encode()).hexdigest(),
        "stage": struct.unpack_from("<h", data, base + 0x2AC)[0],
        "substage": struct.unpack_from("<h", data, base + 0x2AE)[0],
        "roundIndex": struct.unpack_from("<h", data, base + 0x9AE)[0],
        "dragDelta20_12": list(struct.unpack_from("<6i", data, base + 0x504)),
        "pinRotations": rotations,
        "toppledPins": [index for index, rotation in enumerate(rotations) if rotation != 0],
        "score": sum(rotation != 0 for rotation in rotations),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reuse-walking-base", action="store_true")
    args = parser.parse_args()
    if not args.reuse_walking_base:
        commands = ["load extracted/reference/entrance/entrance.mln", "frames 600"]
        for _ in range(20):
            commands += ["keys ffe", "frames 2", "keys fff", "frames 120"]
        run("component-walking-base", commands + ["capture ready", "save ready"])
    if not WALKING.exists():
        raise FileNotFoundError(f"Walking checkpoint not found: {WALKING}")

    trace = run("component-bowling", [f"load {WALKING}", "write32 0227d2f0 2c",
                "write32 0227d2f4 2c", "frames 120", "capture opening",
                "frames 300", "capture ready", "capture-geometry ready", "save ready"])
    opening_data = (trace / "opening-ram.bin").read_bytes()
    data = (trace / "ready-ram.bin").read_bytes()
    opening_base = find_process(opening_data, 0x021FD530)
    base = find_process(data, 0x021FD530)
    result = {
        "schemaVersion": 1,
        "kind": "modified-checkpoint-component-test",
        "note": "Uses the original process factory from a valid walking checkpoint. Does not establish a normal Chapter 8 route or bowling completion.",
        "romSHA256": digest(ROM),
        "walkingCheckpointSHA256": digest(WALKING),
        "commandsSHA256": digest(trace / "commands.txt"),
        "opening": snapshot(opening_data, opening_base),
        "ready": snapshot(data, base),
    }
    fixture = ROOT / "Tests/Fixtures/Bowling"
    fixture.mkdir(parents=True, exist_ok=True)
    (fixture / "source-trace.json").write_text(json.dumps(result, indent=2) + "\n")
    roll = capture_centre_roll(trace / "ready.mln")
    (fixture / "centre-roll.json").write_text(json.dumps(roll, indent=2) + "\n")
    sweep = {
        "romSHA256": digest(ROM),
        "checkpointSHA256": digest(trace / "ready.mln"),
        "kind": "modified-checkpoint touch-selection and pin-result sweep",
        "path": "Touch at (15, y), hold each eight-pixel horizontal step through (119, y) for eight frames, move to (125, y), hold eight frames, then release and capture after 180 frames.",
        "samples": [capture_roll_path(trace / "ready.mln", y) for y in [40, 60, 75, 90, 105, 120, 140]],
    }
    (fixture / "touch-sweep.json").write_text(json.dumps(sweep, indent=2) + "\n")
    print(f"Captured process 44 component trace in {fixture}")


if __name__ == "__main__":
    main()
