#!/usr/bin/env python3
"""Compare cashbox wheel input with the original process in an isolated checkpoint.

This verifies the component, not the Chapter 10 story route.
"""
import hashlib
import json
import struct
from capture_chapter_five_components import ROOT, run


def snapshot(path, base):
    data = path.read_bytes()
    def value(fmt, offset):
        return struct.unpack_from(fmt, data, base + offset)[0]
    return {"phase": value("<h", 0x2AA), "stage": value("<h", 0x2AC),
            "nextPhase": value("<h", 0x2AE), "returnValue": value("<h", 0x298),
            "angles": [value("<f", 0x4FC + i * 44) for i in range(3)],
            "wheelX": [value("<i", 0x4E4 + i * 44) for i in range(3)],
            "wheelY": [value("<i", 0x56C + i * 44) for i in range(3)],
            "holding": value("<B", 0x2ED) != 0, "selected": value("<h", 0x2EE),
            "target": list(data[base + 0x68C:base + 0x68F])}


def main():
    walking = ROOT / "extracted/reference/component-walking-base/ready.mln"
    entry = run("component-cashbox", [f"load {walking}", "write32 0227d2f0 50",
                "write32 0227d2f4 50", "frames 100", "capture ready", "save ready"])
    data = (entry / "ready-ram.bin").read_bytes()
    base = next(offset for offset in range(0x200000, len(data) - 0x820, 4)
                if 0x021FCB40 < (vtable := struct.unpack_from("<I", data, offset)[0]) < 0x02210000
                and struct.unpack_from("<I", data, vtable - 0x02000000 + 16)[0] == 0x021FD544)
    commands = [f"load {entry / 'ready.mln'}"]
    names = []
    for wheel, count, y in [(0, 4, 40), (1, 2, 220), (2, 1, 40)]:
        for index in range(count):
            x = [35, 99, 161][wheel]
            commands += [f"touch 125 {x}", "frames 3", f"touch {255-y} {x}", "frames 3",
                         f"capture drag{wheel}_{index}", "release", "frames 90", f"capture wheel{wheel}_{index}"]
            names += [f"drag{wheel}_{index}", f"wheel{wheel}_{index}"]
    solved = run("component-cashbox-solve", commands + ["frames 300", "capture returned"])
    trace = {"kind": "modified-checkpoint-component-test",
             "romSHA256": hashlib.sha256((ROOT / "Source/ROM/Hotel Dusk - Room 215.nds").read_bytes()).hexdigest(),
             "commandsSHA256": hashlib.sha256((solved / "commands.txt").read_bytes()).hexdigest(),
             "initial": snapshot(entry / "ready-ram.bin", base),
             "steps": {name: snapshot(solved / f"{name}-ram.bin", base) for name in names}}
    destination = ROOT / "Tests/Fixtures/Cashbox/source-trace.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(trace, indent=2) + "\n")


if __name__ == "__main__":
    main()
