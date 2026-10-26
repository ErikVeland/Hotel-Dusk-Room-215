#!/usr/bin/env python3
"""Record original coin input and answer checking in an isolated component run."""
import hashlib
import json
import struct
from capture_chapter_five_components import ROOT, run


def snapshot(path, base):
    data = path.read_bytes()
    return {"phase": struct.unpack_from("<h", data, base + 0x2A8)[0],
            "stage": struct.unpack_from("<h", data, base + 0x2AA)[0],
            "returnValue": struct.unpack_from("<h", data, base + 0x298)[0],
            "coins": [list(struct.unpack_from("<iii", data, base + 0x358 + i * 32)) for i in range(6)]}


def main():
    walking = ROOT / "extracted/reference/component-walking-base/ready.mln"
    entry = run("component-coins", [f"load {walking}", "write32 0227d2f0 33",
                "write32 0227d2f4 33", "frames 120", "capture ready", "save ready"])
    data = (entry / "ready-ram.bin").read_bytes()
    base = next(offset for offset in range(0x200000, len(data) - 0x820, 4)
                if 0x021FCB40 < (vtable := struct.unpack_from("<I", data, offset)[0]) < 0x02210000
                and struct.unpack_from("<I", data, vtable - 0x02000000 + 16)[0] == 0x021FCFB4)
    moved = run("component-coins-stack", [f"load {entry / 'ready.mln'}", "touch 204 96", "frames 3", "capture pick",
                "touch 127 96", "frames 3", "capture moved", "release", "frames 3", "capture released", "save stacked"])
    checked = run("component-coins-check", [f"load {moved / 'stacked.mln'}", "touch 16 22", "frames 3", "release",
                "frames 65", "capture checked", "frames 240", "capture returned"])
    save_trace(entry, moved, checked, base)


def save_trace(entry, moved, checked, base):
    trace = {"kind": "modified-checkpoint-component-test",
             "romSHA256": hashlib.sha256((ROOT / "Source/ROM/Hotel Dusk - Room 215.nds").read_bytes()).hexdigest(),
             "commandHashes": {folder.name: hashlib.sha256((folder / "commands.txt").read_bytes()).hexdigest()
                               for folder in [entry, moved, checked]},
             "initial": snapshot(entry / "ready-ram.bin", base),
             "steps": {name: snapshot(moved / f"{name}-ram.bin", base) for name in ["pick", "moved", "released"]},
             "checkedReturn": snapshot(checked / "checked-ram.bin", base)["returnValue"]}
    destination = ROOT / "Tests/Fixtures/Coins/source-trace.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(trace, indent=2) + "\n")


if __name__ == "__main__":
    main()
