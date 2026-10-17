#!/usr/bin/env python3
"""Recover byte-exact Nitro audio files and their original linkage from SDAT.

Uses only Python's standard library. The output preserves sequence commands,
instrument definitions, compressed samples and archive entry points unchanged.
It does not substitute MIDI timing, assign soundtrack titles or infer game cues.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

KINDS = ("sequences", "sequenceArchives", "banks", "waveArchives",
         "players", "groups", "streamPlayers", "streams")
MAGIC = {0: b"SSEQ", 1: b"SSAR", 2: b"SBNK", 3: b"SWAR", 7: b"STRM"}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


class Reader:
    def __init__(self, data: bytes):
        self.data = data

    def unpack(self, fmt: str, offset: int):
        size = struct.calcsize("<" + fmt)
        if offset < 0 or offset + size > len(self.data):
            raise ValueError(f"Read outside archive at {offset:#x}")
        return struct.unpack_from("<" + fmt, self.data, offset)

    def u32(self, offset: int) -> int:
        return self.unpack("I", offset)[0]

    def string(self, offset: int, limit: int) -> str:
        if not 0 <= offset < limit <= len(self.data):
            raise ValueError("Invalid symbol offset")
        end = self.data.index(0, offset, limit)
        return self.data[offset:end].decode("ascii")


def extract(path: Path, output: Path) -> dict:
    source = path.read_bytes()
    r = Reader(source)
    magic, bom, version, size, header_size, blocks = r.unpack("4sHHIHH", 0)
    if (magic, bom, version, size, header_size, blocks) != (b"SDAT", 0xFEFF, 0x100, len(source), 0x40, 4):
        raise ValueError("Expected a complete little-endian Nitro SDAT 1.0 archive with symbols")
    offsets = r.unpack("8I", 0x10)
    sym, sym_size, info, info_size, fat, fat_size, files, files_size = offsets
    for offset, length, marker in ((sym, sym_size, b"SYMB"), (info, info_size, b"INFO"),
                                   (fat, fat_size, b"FAT "), (files, files_size, b"FILE")):
        if offset + length > len(source) or source[offset:offset + 4] != marker:
            raise ValueError(f"Invalid {marker!r} block")
    sym_tables = r.unpack("8I", sym + 8)
    info_tables = r.unpack("8I", info + 8)
    output.mkdir(parents=True, exist_ok=True)

    def names(relative: int, nested: bool = False):
        if relative == 0:
            return []
        at = sym + relative
        count = r.u32(at)
        result = []
        for index in range(count):
            ptr = at + 4 + index * (8 if nested else 4)
            relative_name = r.u32(ptr)
            name = r.string(sym + relative_name, sym + sym_size) if relative_name else None
            result.append((name, names(r.u32(ptr + 4))) if nested else name)
        return result

    payloads = []
    file_records = []
    for index in range(r.u32(fat + 8)):
        offset, length = r.unpack("II", fat + 12 + index * 16)
        if not files + 8 <= offset <= offset + length <= files + files_size:
            raise ValueError(f"File {index} lies outside FILE block")
        data = source[offset:offset + length]
        marker = data[:4]
        if marker not in MAGIC.values():
            raise ValueError(f"Unknown sound file {index}: {marker!r}")
        filename = f"files/{index:03d}.{marker.decode('ascii').lower()}"
        destination = output / filename
        destination.parent.mkdir(exist_ok=True)
        destination.write_bytes(data)
        payloads.append(data)
        file_records.append({"id": index, "offset": offset, "length": length,
                             "magic": marker.decode("ascii"), "path": filename, "sha256": digest(data)})

    inventory = {"schemaVersion": 1, "source": str(path), "sha256": digest(source),
                 "length": len(source), "files": file_records}
    for kind, table in enumerate(info_tables):
        labels = names(sym_tables[kind], kind == 1)
        entries = []
        count = r.u32(info + table) if table else 0
        if len(labels) != count:
            raise ValueError(f"Symbol/info counts differ for {KINDS[kind]}")
        for index in range(count):
            relative = r.u32(info + table + 4 + index * 4)
            label = labels[index][0] if kind == 1 else labels[index]
            entry = {"id": index, "symbol": label, "present": bool(relative)}
            if relative == 0:
                entries.append(entry)
                continue
            at = info + relative
            if kind in MAGIC:
                file_id, flags = r.unpack("HH", at)
                if file_id >= len(payloads) or payloads[file_id][:4] != MAGIC[kind]:
                    raise ValueError(f"Invalid {KINDS[kind]} file reference")
                entry.update(fileID=file_id, fileFlags=flags)
            if kind == 0:
                bank, volume, channel_priority, player_priority, player = r.unpack("H4B", at + 4)
                entry.update(bankID=bank, volume=volume, channelPriority=channel_priority,
                             playerPriority=player_priority, playerID=player)
            elif kind == 1:
                data = payloads[entry["fileID"]]
                ar = Reader(data)
                data_offset, sequence_count = ar.unpack("II", 0x18)
                subsymbols = labels[index][1]
                if len(subsymbols) != sequence_count:
                    raise ValueError("SSAR symbol/sequence counts differ")
                seqs = []
                for sub in range(sequence_count):
                    start, bank, volume, channel_priority, player_priority, player = ar.unpack("iH4B", 0x20 + sub * 12)
                    if start != -1 and not data_offset <= data_offset + start < len(data):
                        raise ValueError("Invalid SSAR entry point")
                    seqs.append({"id": sub, "symbol": subsymbols[sub], "eventOffset": start,
                                 "bankID": bank, "volume": volume, "channelPriority": channel_priority,
                                 "playerPriority": player_priority, "playerID": player})
                entry.update(eventDataOffset=data_offset, sequences=seqs)
            elif kind == 2:
                entry["waveArchiveIDs"] = [None if v == -1 else v for v in r.unpack("4h", at + 4)]
            elif kind == 3:
                data = payloads[entry["fileID"]]
                wr = Reader(data)
                waves = []
                for wave in range(wr.u32(0x38)):
                    offset = wr.u32(0x3C + wave * 4)
                    encoding, loop, rate, timer, loop_words, length_words = wr.unpack("BBHHHI", offset)
                    sample_length = (loop_words + length_words) * 4
                    if offset + 12 + sample_length > len(data):
                        raise ValueError("Wave data exceeds archive")
                    waves.append({"id": wave, "offset": offset, "encoding": encoding,
                                  "loop": bool(loop), "sampleRate": rate, "timer": timer,
                                  "loopStartWords": loop_words, "loopLengthWords": length_words,
                                  "sha256": digest(data[offset:offset + 12 + sample_length])})
                entry["waves"] = waves
            elif kind == 4:
                limit, channel_mask, heap_size = r.unpack("HHI", at)
                entry.update(maxSequences=limit, channelMask=channel_mask, heapSize=heap_size)
            elif kind == 5:
                members = []
                for member in range(r.u32(at)):
                    typ, flags, identifier = r.unpack("BB2xI", at + 4 + member * 8)
                    members.append({"type": typ, "loadFlags": flags, "id": identifier})
                entry["members"] = members
            elif kind == 6:
                length = r.unpack("B", at)[0]
                entry["channels"] = list(r.unpack(f"{length}B", at + 1))
            elif kind == 7:
                entry.update(zip(("volume", "priority", "playerID", "flags"), r.unpack("4B", at + 4)))
            entries.append(entry)
        inventory[KINDS[kind]] = entries

    for sequence in inventory["sequences"] + [s for a in inventory["sequenceArchives"] for s in a.get("sequences", [])]:
        if sequence.get("present", True) and sequence.get("eventOffset") != -1:
            assert 0 <= sequence["bankID"] < len(inventory["banks"])
            assert 0 <= sequence["playerID"] < len(inventory["players"])
    for bank in inventory["banks"]:
        for wave in bank.get("waveArchiveIDs", []):
            assert wave is None or 0 <= wave < len(inventory["waveArchives"])
    inventory["counts"] = {kind: sum(e["present"] for e in inventory[kind]) for kind in KINDS}
    inventory["counts"]["archiveSequences"] = sum(len(a.get("sequences", [])) for a in inventory["sequenceArchives"])
    inventory["counts"]["waveSamples"] = sum(len(a.get("waves", [])) for a in inventory["waveArchives"])
    (output / "inventory.json").write_text(json.dumps(inventory, indent=2) + "\n")
    return inventory


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path, default=Path("extracted/root/data/sound_data.sdat"))
    parser.add_argument("--output", type=Path, default=Path("extracted/audio"))
    args = parser.parse_args()
    inventory = extract(args.source, args.output)
    print(json.dumps({"sha256": inventory["sha256"], "files": len(inventory["files"]),
                      "counts": inventory["counts"]}, indent=2))


if __name__ == "__main__":
    main()
