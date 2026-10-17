#!/usr/bin/env python3
"""Trace deterministic SSEQ tracks through their first complete repeat.

The trace retains source ticks and command offsets. Unsupported commands fail
instead of silently changing music. This is an audit, not a DS audio emulator.
"""
from __future__ import annotations
from collections import Counter
import json
from pathlib import Path
import struct


def trace_sequence(data: bytes, start: int = 0):
    tracks = [(0, start)]
    result = []
    commands = Counter()
    for track_id, initial in tracks:
        pc = initial
        tick = 0
        note_wait = True
        stack = []
        loops = []
        visited = {}
        notes = []
        events = []
        ended = False
        loop = None

        def byte():
            nonlocal pc
            value = data[pc]
            pc += 1
            return value

        def integer(size):
            nonlocal pc
            value = int.from_bytes(data[pc:pc + size], "little")
            pc += size
            return value

        def variable():
            value = 0
            for _ in range(4):
                v = byte()
                value = (value << 7) | (v & 127)
                if v < 128:
                    return value
            raise ValueError("Invalid variable length integer")

        for _ in range(200000):
            at = pc
            # Returning to a subroutine is expected. A jump below identifies
            # an infinite repeat only when its target has the same call stack.
            visited[(at, tuple(stack))] = tick
            opcode = byte()
            commands[opcode] += 1
            if opcode < 0x80:
                velocity, duration = byte(), variable()
                notes.append([tick, opcode, velocity, duration])
                if note_wait:
                    tick += duration
            elif opcode == 0x80:
                tick += variable()
            elif opcode == 0x81:
                events.append([tick, opcode, variable()])
            elif opcode == 0x93:
                target_id, address = byte(), integer(3)
                if target_id in [t[0] for t in tracks]:
                    raise ValueError("Repeated track creation needs runtime interpretation")
                if tick != 0:
                    raise ValueError("Delayed track creation needs runtime interpretation")
                tracks.append((target_id, address))
            elif opcode == 0x94:
                address = integer(3)
                key = (address, tuple(stack))
                if key in visited:
                    loop = {"startTick": visited[key], "endTick": tick, "targetOffset": address, "jumpOffset": at}
                    break
                pc = address
            elif opcode == 0x95:
                address = integer(3)
                stack.append(pc)
                pc = address
            elif 0xC0 <= opcode <= 0xD6:
                value = byte()
                events.append([tick, opcode, value])
                if opcode == 0xC7:
                    note_wait = bool(value)
                if opcode == 0xD4:
                    loops.append([pc, value, tick])
            elif opcode in (0xE0, 0xE1, 0xE2):
                events.append([tick, opcode, integer(2)])
            elif opcode == 0xFC:
                if not loops:
                    raise ValueError("Loop end without loop start")
                address, count, beginning = loops[-1]
                if count == 0:
                    loop = {"startTick": beginning, "endTick": tick, "targetOffset": address, "jumpOffset": at}
                    break
                if count > 1:
                    loops[-1][1] -= 1
                    pc = address
                else:
                    loops.pop()
            elif opcode == 0xFD:
                if not stack:
                    raise ValueError("Return without a call")
                pc = stack.pop()
            elif opcode == 0xFE:
                integer(2)
            elif opcode == 0xFF:
                ended = True
                break
            else:
                raise ValueError(f"Unsupported opcode {opcode:#x} at {at:#x}")
        else:
            raise ValueError("Unbounded sequence trace")
        result.append({"trackID": track_id, "startOffset": initial, "endTick": tick,
                       "ends": ended, "loop": loop, "notes": notes, "events": events})
    return result, {f"{k:02x}": v for k, v in sorted(commands.items())}


def main():
    root = Path("extracted/audio")
    inventory = json.loads((root / "inventory.json").read_text())
    result = []
    for seq in inventory["sequences"]:
        data = (root / inventory["files"][seq["fileID"]]["path"]).read_bytes()
        data = data[struct.unpack_from("<I", data, 0x18)[0]:]
        tracks, commands = trace_sequence(data)
        result.append({"symbol": seq["symbol"], "bankID": seq["bankID"], "volume": seq["volume"],
                       "tracks": tracks, "commands": commands})
        print(seq["symbol"], [(t["trackID"], t["endTick"], t["loop"] and t["loop"]["startTick"]) for t in tracks])
    (root / "sequence-traces.json").write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
