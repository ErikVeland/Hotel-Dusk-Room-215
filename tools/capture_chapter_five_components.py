#!/usr/bin/env python3
"""Capture isolated Chapter 5 puzzle inputs through the original process factory.

These modified checkpoints test components. They are not normal story-route evidence.
The verification-only ROM runner is never called by the native Swift application.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(name, commands):
    directory = ROOT / "extracted/reference" / name
    directory.mkdir(exist_ok=True)
    text = "\n".join(commands + ["quit"]) + "\n"
    (directory / "commands.txt").write_text(text)
    with (directory / "runner.log").open("w") as log:
        subprocess.run([str(ROOT / ".build/rom-reference/hotel-reference"),
                        str(ROOT / "Source/ROM/Hotel Dusk - Room 215.nds"), str(directory)],
                       input=text, text=True, stdout=log, stderr=subprocess.STDOUT, check=True)
    return directory


def find_process(data, update):
    for offset in range(0x200000, len(data) - 0x748, 4):
        vtable, = struct.unpack_from("<I", data, offset)
        if 0x021FCB40 < vtable < 0x02200000:
            callback, = struct.unpack_from("<I", data, vtable - 0x02000000 + 16)
            if callback == update:
                return offset
    raise ValueError(f"No process with update {update:08x}")


def linen_snapshot(path, base):
    data = path.read_bytes()
    return {"stage": struct.unpack_from("<h", data, base + 0x2A8)[0],
            "phase": struct.unpack_from("<h", data, base + 0x2AA)[0],
            "subphase": struct.unpack_from("<h", data, base + 0x2AC)[0],
            "held": data[base + 0x2ED] != 0,
            "returnValue": struct.unpack_from("<h", data, base + 0x298)[0],
            "gunAlpha": struct.unpack_from("<h", data, base + 0x55C)[0],
            "coverAlpha": struct.unpack_from("<h", data, base + 0x55E)[0],
            "pieces": [{"x": struct.unpack_from("<i", data, base + 0x41C + i * 32)[0],
                        "y": struct.unpack_from("<i", data, base + 0x420 + i * 32)[0],
                        "z": struct.unpack_from("<i", data, base + 0x424 + i * 32)[0],
                        "rotation": struct.unpack_from("<f", data, base + 0x434 + i * 32)[0],
                        "direction": struct.unpack_from("<h", data, base + 0x438 + i * 32)[0]}
                       for i in range(6)]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reuse-walking-base", action="store_true")
    parser.add_argument("--fixtures", type=Path, default=ROOT / "Tests/Fixtures/ChapterFiveComponents")
    args = parser.parse_args()
    if not args.reuse_walking_base:
        commands = ["load extracted/reference/entrance/entrance.mln", "frames 600"]
        for _ in range(20):
            commands += ["keys ffe", "frames 2", "keys fff", "frames 120"]
        run("component-walking-base", commands + ["capture ready", "save ready"])
    walking = ROOT / "extracted/reference/component-walking-base/ready.mln"
    # Original walking object 0227CFA0, pending process +350/+354. The original
    # update 0202A484 and next-process getter 0202F160 dispatch the factory.
    # No puzzle result, item, flag or puzzle instance memory is modified.
    linen = run("component-linenwagon", [f"load {walking}", "write32 0227d2f0 3c",
                "write32 0227d2f4 3c", "frames 100", "capture ready", "save ready"])
    data = (linen / "ready-ram.bin").read_bytes()
    base = find_process(data, 0x021FD194)
    rng, = struct.unpack_from("<I", data, base + 0x6F8)
    inverse = pow(0x5D588B65, -1, 1 << 32)
    for _ in range(12):
        rng = ((rng - 0x00269EC3) * inverse) & 0xFFFFFFFF
    commands = [f"load {linen / 'ready.mln'}"]
    points = [(80, 100), (128, 102), (82, 139), (124, 138), (84, 168), (121, 166)]
    for i, (x, y) in enumerate(points):
        commands += [f"touch {255-y} {x}", "frames 3", f"capture pick{i}",
                     f"touch {255-y} 0", "frames 3", f"capture held{i}",
                     "release", "frames 3", f"capture release{i}", "frames 60", f"capture removed{i}"]
    drag = run("component-linenwagon-drag", commands + ["save removed"])
    reveal = run("component-linenwagon-reveal", [f"load {drag / 'removed.mln'}",
                 "touch 85 96", "frames 3", "release", "frames 35", "capture cover",
                 "touch 145 96", "frames 3", "release", "frames 100", "capture revealed", "save revealed",
                 "touch 135 110", "frames 3", "release", "frames 3", "capture taken",
                 "frames 110", "capture wait", "frames 80", "capture returned", "save returned"])
    doll = run("component-doll", [f"load {walking}", "write32 0227d2f0 26", "write32 0227d2f4 26",
               "frames 100", "capture ready", "save ready"])
    commands = [f"load {doll / 'ready.mln'}"]
    for i in range(11):
        x, y = (150 if i % 2 == 0 else 180), 130 + i * 7
        commands += [f"touch {255-y} {x}", "frames 3", f"capture stitch{i}"]
    doll_solve = run("component-doll-solve", commands + ["release", "frames 3", "capture released",
                     "frames 15", "capture success", "frames 240", "capture returned"])
    doll_data = (doll / "ready-ram.bin").read_bytes()
    doll_base = find_process(doll_data, 0x021FD07C)
    success = (doll_solve / "success-ram.bin").read_bytes()
    result = {
        "schemaVersion": 1, "kind": "modified-checkpoint-component-test",
        "note": "Original process factory and touch input. Does not establish normal Chapter 5 route completion.",
        "romSHA256": digest(ROOT / "Source/ROM/Hotel Dusk - Room 215.nds"),
        "walkingCheckpointSHA256": digest(walking),
        "commandsSHA256": {p.name: digest(p / "commands.txt") for p in [linen, drag, reveal, doll, doll_solve]},
        "linen": {"processID": 60, "overlaySHA256": digest(ROOT / "extracted/recovered_logic/binaries/overlay_0033.bin"),
                  "seed": rng, "initial": linen_snapshot(linen / "ready-ram.bin", base),
                  "throws": [{"pageTouch": list(point),
                              "held": linen_snapshot(drag / f"held{i}-ram.bin", base),
                              "released": linen_snapshot(drag / f"release{i}-ram.bin", base),
                              "removed": linen_snapshot(drag / f"removed{i}-ram.bin", base)} for i, point in enumerate(points)],
                  "cover": linen_snapshot(reveal / "cover-ram.bin", base),
                  "revealed": linen_snapshot(reveal / "revealed-ram.bin", base),
                  "taken": linen_snapshot(reveal / "taken-ram.bin", base)},
        "doll": {"processID": 38, "overlaySHA256": digest(ROOT / "extracted/recovered_logic/binaries/overlay_0016.bin"),
                 "stitches": struct.unpack_from("<h", success, doll_base + 0x49A)[0],
                 "seamMask": struct.unpack_from("<H", success, doll_base + 0x524)[0],
                 "successStage": struct.unpack_from("<h", success, doll_base + 0x520)[0]}}
    args.fixtures.mkdir(parents=True, exist_ok=True)
    (args.fixtures / "source-trace.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"Captured process 60 and 38 component traces in {args.fixtures}")


if __name__ == "__main__":
    main()
