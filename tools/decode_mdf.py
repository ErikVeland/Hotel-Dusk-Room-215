#!/usr/bin/env python3
"""Recover MDF_DS nodes and GX geometry from the supplied original assets.

The original ARM9 loader at 0208b0f4 and renderers at 0208b6f0/0208baac
establish the tables. GX words remain byte-exact. Unknown variants fail.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
import math
from pathlib import Path
import struct

from cing_container import decompress
from decode_anm import DecodeError, payload, require, sha

ROOT = Path(__file__).resolve().parents[1]


def cstring(data):
    # Identifiers are opaque original bytes; Latin-1 is lossless, including
    # the two source model names containing non-ASCII exporter bytes.
    return data.split(b"\0", 1)[0].decode("latin1")


def fixed(value):
    # Original loader: Float32(value * 4096 +/- 0.5), then truncate.
    scaled = struct.unpack("<f", struct.pack("<f", value * 4096))[0]
    rounded = struct.unpack("<f", struct.pack("<f", scaled + (0.5 if value > 0 else -0.5)))[0]
    return int(rounded)


def concatenate(a, b):
    # ARM9 020bc948: signed 64-bit dot products, arithmetic shift by 12.
    return [sum(a[row * 4 + k] * b[k * 4 + col] for k in range(4)) >> 12
            for row in range(4) for col in range(4)]


class Geometry:
    def __init__(self, data, textured):
        self.data = data
        self.vertices = []
        self.indices = []
        self.commands = Counter()
        self.primitive = None
        position = 0
        colour = None
        uv = None
        begin = None
        cursor = 0
        while cursor < len(data):
            require(cursor + 4 <= len(data), "Truncated GX command word")
            word = struct.unpack_from("<I", data, cursor)[0]
            cursor += 4
            for shift in (0, 8, 16, 24):
                command = word >> shift & 255
                if command == 0:
                    continue
                self.commands[f"{command:02x}"] += 1
                count = {0x20: 1, 0x22: 1, 0x23: 2, 0x40: 1, 0x41: 0}.get(command)
                require(count is not None, f"Unsupported GX command {command:02x}")
                require(cursor + count * 4 <= len(data), "Truncated GX command parameters")
                params = struct.unpack_from("<" + "I" * count, data, cursor)
                cursor += count * 4
                if command == 0x20:
                    require(params[0] <= 0x7fff, "Unexpected GX colour bits")
                    colour = params[0]
                elif command == 0x22:
                    uv = struct.unpack("<hh", struct.pack("<I", params[0]))
                elif command == 0x40:
                    require(begin is None and params[0] in (0, 1), "Unsupported GX primitive")
                    self.primitive = params[0]
                    begin = len(self.vertices)
                elif command == 0x41:
                    require(begin is not None, "GX END without BEGIN")
                    size = 3 if self.primitive == 0 else 4
                    require((len(self.vertices) - begin) % size == 0, "Incomplete GX primitive")
                    for v in range(begin, len(self.vertices), size):
                        self.indices.extend((v, v + 1, v + 2))
                        if size == 4:
                            self.indices.extend((v, v + 2, v + 3))
                    begin = None
                elif command == 0x23:
                    require(begin is not None and params[1] <= 0xffff, "Invalid GX vertex")
                    require(not textured or (colour is not None and uv is not None), "Uninitialized GX attributes")
                    xyz = struct.unpack("<hhh", struct.pack("<IH", params[0], params[1]))
                    self.vertices.append((*xyz, *(uv or (0, 0)), colour or 0))
                    position += 1
        require(begin is None and self.vertices, "Unclosed or empty GX geometry")
        # Signed positions are 4.12, UVs are 12.4; colour is raw RGB555.
        self.vertex_bytes = b"".join(struct.pack("<5hH", *v) for v in self.vertices)
        self.index_bytes = struct.pack("<" + "I" * len(self.indices), *self.indices)


class Model:
    def __init__(self, original):
        self.data = decompress(original) if original[:3] == bytes.fromhex("123dda") else original
        data = self.data
        require(len(data) >= 48 and data[:16] == b"MDF_DS_100" + bytes(6), "Unsupported MDF variant")
        self.name = cstring(data[16:32])
        nodes, materials, node_offset, material_offset = struct.unpack_from("<4I", data, 32)
        require(material_offset == 48 and node_offset == 48 + materials * 48, "Unsupported MDF tables")
        require(node_offset + nodes * 96 <= len(data), "Truncated MDF nodes")
        self.materials = []
        for i in range(materials):
            at = material_offset + i * 48
            raw = data[at:at + 48]
            self.materials.append({"name": cstring(raw[:16]), "texture": cstring(raw[16:32]),
                                   "raw": raw.hex()})
        self.nodes = []
        self.groups = []
        self.geometry_bytes = bytearray()
        for i in range(nodes):
            at = node_offset + i * 96
            index, parent, groups_at, group_count, reserved = struct.unpack_from("<hh3I", data, at + 16)
            require(index == i and -1 <= parent < i and reserved == 0, "Invalid MDF hierarchy")
            matrix = struct.unpack_from("<16f", data, at + 32)
            require(all(math.isfinite(v) and abs(v) < 524288 for v in matrix), "Invalid MDF transform")
            local = list(map(fixed, matrix))
            world = local if parent == -1 else concatenate(self.nodes[parent]["worldFixed"], local)
            self.nodes.append({"name": cstring(data[at:at + 16]), "parent": parent,
                               "localFixed": local, "worldFixed": world, "groups": group_count})
            require(groups_at + group_count * 16 <= len(data), "Truncated MDF draw groups")
            for g in range(group_count):
                fields = struct.unpack_from("<II4H", data, groups_at + g * 16)
                draw_at, hit_at, draw_size, hit_size, material, flags = fields
                require(material < materials and flags in (0, 3, 4), "Unsupported MDF group record")
                record = {"node": i, "material": material, "flags": flags}
                for kind, offset, size in (("render", draw_at, draw_size), ("hit", hit_at, hit_size)):
                    require((offset == 0) == (size == 0), "Invalid MDF display list range")
                    if not size:
                        continue
                    require(offset + size <= len(data), "Truncated MDF display list")
                    geometry = Geometry(data[offset:offset + size], kind == "render")
                    self.geometry_bytes.extend(geometry.vertex_bytes)
                    self.geometry_bytes.extend(geometry.index_bytes)
                    record[kind] = {"offset": offset, "bytes": size, "primitive": geometry.primitive,
                                    "vertices": len(geometry.vertices), "triangles": len(geometry.indices) // 3,
                                    "gxSHA256": sha(geometry.data), "verticesSHA256": sha(geometry.vertex_bytes),
                                    "indicesSHA256": sha(geometry.index_bytes), "commands": dict(geometry.commands)}
                self.groups.append(record)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "extracted/unpacked_wpf")
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--report", type=Path, default=ROOT / "docs/original-model-report.json")
    args = parser.parse_args()
    entries, stats = [], Counter()
    for path in sorted(args.source.rglob("*.mdf")):
        raw = payload(path)
        relative = path.relative_to(args.source).as_posix()
        record = {"source": relative, "sourceSHA256": sha(path.read_bytes()), "payloadSHA256": sha(raw),
                  "payloadBytes": len(raw)}
        try:
            model = Model(raw)
            record.update({"status": "decoded", "name": model.name, "decodedSHA256": sha(model.data),
                           "geometrySHA256": sha(model.geometry_bytes), "nodes": model.nodes,
                           "materials": model.materials, "groups": model.groups})
            stats["decoded"] += 1
            stats["nodes"] += len(model.nodes)
            stats["materials"] += len(model.materials)
            for group in model.groups:
                for kind in ("render", "hit"):
                    if kind in group:
                        stats[kind + "Groups"] += 1
                        stats[kind + "Vertices"] += group[kind]["vertices"]
                        stats[kind + "Triangles"] += group[kind]["triangles"]
        except (DecodeError, ValueError, struct.error) as error:
            record.update({"status": "unsupported", "error": str(error)})
            stats["unsupported"] += 1
        entries.append(record)
        if args.bundle:
            destination = args.bundle / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(raw)
    report = {"formatVersion": 1, "coverage": {"models": len(entries), **dict(stats)}, "models": entries}
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    if args.bundle:
        (args.bundle / "OriginalModelManifest.json").write_text(json.dumps(report, separators=(",", ":")) + "\n")
    print(json.dumps(report["coverage"]))
    for record in entries:
        if record["status"] == "unsupported" and not record["source"].startswith("talktest/"):
            print(record["source"], record["error"])


if __name__ == "__main__":
    main()
