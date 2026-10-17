#!/usr/bin/env python3
"""Prepare original music with source loop ranges and clean PCM.

The supplied MIDI/DLS conversion is a native playback adapter. All sample PCM
is regenerated from ROM because the supplied DLS files have inconsistent tails.
No sequence-to-scene mapping is inferred.
"""
from collections import Counter
import hashlib
import json
from pathlib import Path
import shutil
import struct

STEP_TABLE = (7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31,
              34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130,
              143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408,
              449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166,
              1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749,
              3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484,
              7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
              15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767)
INDEX_TABLE = (-1, -1, -1, -1, 2, 4, 6, 8)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def decode_adpcm(data, negative_limit=-32767):
    predictor, index = struct.unpack_from("<hH", data)
    index &= 0x7F
    if index > 88:
        raise ValueError("Invalid ADPCM initial index")
    pcm = bytearray()
    for value in data[4:]:
        for nibble in (value & 15, value >> 4):
            step = STEP_TABLE[index]
            delta = step // 8
            if nibble & 1:
                delta += step // 4
            if nibble & 2:
                delta += step // 2
            if nibble & 4:
                delta += step
            predictor += -delta if nibble & 8 else delta
            predictor = max(negative_limit, min(32767, predictor))
            index = max(0, min(88, index + INDEX_TABLE[nibble & 7]))
            pcm.extend(struct.pack("<h", predictor))
    return bytes(pcm)


def chunks(data, start=0):
    at = start
    while at + 8 <= len(data):
        length = struct.unpack_from("<I", data, at + 4)[0]
        end = at + 8 + length
        if end > len(data):
            raise ValueError("Truncated RIFF chunk")
        yield at, data[at:at + 4], data[at + 8:end], end + length % 2
        at = end + length % 2


def chunk(marker, data):
    return marker + struct.pack("<I", len(data)) + data + bytes(len(data) % 2)


def repair_regions(value, waves):
    """Keep instrument parameters, correcting sample loops from original SWAR."""
    children = list(chunks(value, 4))
    wave_id = next((struct.unpack_from("<I", v, 8)[0] for _, m, v, _ in children if m == b"wlnk"), None)
    result = bytearray(value[:4])
    for _, marker, data, _ in children:
        if marker == b"LIST":
            data = repair_regions(data, waves)
        elif marker == b"wsmp" and wave_id is not None:
            wave = waves[wave_id]
            data = data[:16] + struct.pack("<I", int(wave["loop"]))
            if wave["loop"]:
                data += struct.pack("<4I", 16, 0, (wave["loopStartWords"] - 1) * 8, wave["loopLengthWords"] * 8)
        result += chunk(marker, data)
    return bytes(result)


def verify_instrument_links(original_bank, dls):
    expected = {}
    count = struct.unpack_from("<I", original_bank, 0x38)[0]
    for program in range(count):
        kind, offset, _ = struct.unpack_from("<BHB", original_bank, 0x3C + 4 * program)
        regions = []
        if kind == 0:
            continue
        if kind == 1:
            regions.append((0, 127, offset))
        elif kind == 16:
            low, high = original_bank[offset:offset + 2]
            regions = [(key, key, offset + 4 + (key - low) * 12) for key in range(low, high + 1)]
        elif kind == 17:
            low = 0
            for region, high in enumerate(original_bank[offset:offset + 8]):
                if region and high == 0:
                    break
                regions.append((low, high, offset + 10 + region * 12))
                low = high + 1
        else:
            raise ValueError(f"Unsupported original instrument type {kind}")
        entries = []
        for low, high, at in regions:
            wave, archive, root_pitch = struct.unpack_from("<HHB", original_bank, at)
            assert archive == 0
            entries.append((low, high, wave, root_pitch))
        expected[program] = entries
    actual = {}
    instruments = next(v for _, m, v, _ in chunks(dls, 12) if m == b"LIST" and v[:4] == b"lins")
    for _, _, instrument, _ in chunks(instruments, 4):
        parts = list(chunks(instrument, 4))
        header = next(v for _, m, v, _ in parts if m == b"insh")
        program = struct.unpack_from("<I", header, 8)[0]
        regions = next(v for _, m, v, _ in parts if m == b"LIST" and v[:4] == b"lrgn")
        entries = []
        for _, _, region, _ in chunks(regions, 4):
            parts = {m: v for _, m, v, _ in chunks(region, 4)}
            low, high = struct.unpack_from("<HH", parts[b"rgnh"])
            wave = struct.unpack_from("<I", parts[b"wlnk"], 8)[0]
            root_pitch = struct.unpack_from("<H", parts[b"wsmp"], 4)[0]
            entries.append((low, high, wave, root_pitch))
        actual[program] = entries
    assert expected == actual, "Supplied DLS instrument links differ from original SBNK"


def midi_note_events(data):
    if data[:4] != b"MThd" or data[12:14] != b"\0\x30":
        raise ValueError("Expected MIDI with 48 ticks per quarter note")
    result = []
    for _, marker, track, _ in chunks_midi(data):
        if marker != b"MTrk":
            raise ValueError("Invalid MIDI track")
        position = tick = status = 0
        on, off = Counter(), Counter()
        controls = []

        def variable():
            nonlocal position
            value = 0
            while True:
                byte = track[position]
                position += 1
                value = (value << 7) | (byte & 127)
                if byte < 128:
                    return value

        while position < len(track):
            tick += variable()
            if track[position] >= 128:
                status = track[position]
                position += 1
            if status == 255:
                position += 1
                length = variable()
                position += length
            elif status in (240, 247):
                length = variable()
                position += length
            else:
                size = 1 if status & 0xF0 in (0xC0, 0xD0) else 2
                values = track[position:position + size]
                position += size
                if status & 0xF0 == 0x90 and values[1]:
                    on[(tick, values[0], values[1])] += 1
                elif status & 0xF0 == 0x80 or (status & 0xF0 == 0x90 and not values[1]):
                    off[(tick, values[0])] += 1
                else:
                    controls.append([tick, status & 0xF0, *values])
        result.append((on, off, controls))
    return result


def chunks_midi(data):
    at = 14
    while at < len(data):
        length = int.from_bytes(data[at + 4:at + 8], "big")
        yield at, data[at:at + 4], data[at + 8:at + 8 + length], at + 8 + length
        at += 8 + length


def normalise_midi(data):
    """Move end-of-track markers after trailing note-offs in the old export."""
    output = bytearray(data[:14])
    for _, marker, track, _ in chunks_midi(data):
        position = tick = status = 0
        events = []

        def variable():
            nonlocal position
            value = 0
            for _ in range(4):
                byte = track[position]
                position += 1
                value = (value << 7) | (byte & 127)
                if byte < 128:
                    return value
            raise ValueError("Invalid MIDI variable-length quantity")

        def encoded(value):
            out = [value & 127]
            value >>= 7
            while value:
                out.insert(0, 128 | (value & 127))
                value >>= 7
            return bytes(out)

        while position < len(track):
            tick += variable()
            if track[position] >= 128:
                status = track[position]
                position += 1
            if status == 255:
                typ = track[position]
                position += 1
                length = variable()
                value = track[position:position + length]
                position += length
                if typ != 0x2F:
                    events.append((tick, bytes([status, typ]) + encoded(length) + value))
            elif status in (240, 247):
                length = variable()
                value = track[position:position + length]
                position += length
                events.append((tick, bytes([status]) + encoded(length) + value))
            else:
                size = 1 if status & 0xF0 in (0xC0, 0xD0) else 2
                value = track[position:position + size]
                position += size
                if any(v >= 128 for v in value):
                    raise ValueError("Invalid MIDI channel data")
                events.append((tick, bytes([status]) + value))
        body = bytearray()
        previous = 0
        for tick, value in events:
            body += encoded(tick - previous) + value
            previous = tick
        body += b"\0\xff\x2f\0"
        output += marker + len(body).to_bytes(4, "big") + body
    return bytes(output)


def main():
    root = Path("extracted/audio")
    output = Path("Sources/HotelDuskDuoKit/Resources/Original/Audio")
    output.mkdir(parents=True, exist_ok=True)
    inv = json.loads((root / "inventory.json").read_text())
    traces = json.loads((root / "sequence-traces.json").read_text())
    wave_archive = inv["waveArchives"][0]
    source_wave = (root / inv["files"][wave_archive["fileID"]]["path"]).read_bytes()
    samples = []
    legacy_samples = []
    for wave in wave_archive["waves"]:
        assert wave["encoding"] == 2
        start = wave["offset"] + 12
        length = (wave["loopStartWords"] + wave["loopLengthWords"]) * 4
        encoded = source_wave[start:start + length]
        samples.append(decode_adpcm(encoded))
        legacy_samples.append(decode_adpcm(encoded, negative_limit=-32768))

    canonical_pool = None
    repaired_tails = 0
    sequences = []
    for sequence, trace in zip(inv["sequences"], traces):
        symbol = sequence["symbol"]
        bank = inv["banks"][sequence["bankID"]]
        assert bank["waveArchiveIDs"] == [0, None, None, None]
        midi_path = Path("Source/Music") / (symbol + ".mid")
        supplied_midi = midi_path.read_bytes()
        midi = normalise_midi(supplied_midi)
        assert midi_note_events(supplied_midi) == midi_note_events(midi)
        midi_tracks = midi_note_events(midi)
        assert len(midi_tracks) == len(trace["tracks"])
        for track, (on, off, _) in zip(trace["tracks"], midi_tracks):
            expected_on = Counter((t, pitch, velocity) for t, pitch, velocity, duration in track["notes"])
            expected_off = Counter((t + duration, pitch) for t, pitch, velocity, duration in track["notes"])
            assert on == expected_on, (symbol, track["trackID"], "note onset mismatch")
            assert off == expected_off, (symbol, track["trackID"], "note duration mismatch")

        source_bank = Path("Source/Music") / (bank["symbol"] + ".dls")
        dls = source_bank.read_bytes()
        original_bank = (root / inv["files"][bank["fileID"]]["path"]).read_bytes()
        verify_instrument_links(original_bank, dls)
        pool_offset, pool, pool_end = next((start, value, end) for start, marker, value, end in chunks(dls, 12)
                                           if marker == b"LIST" and value[:4] == b"wvpl")
        fixed_waves = bytearray()
        wave_offsets = []
        waves = list(chunks(pool, 4))
        assert len(waves) == len(samples)
        for index, (start, marker, wave, end) in enumerate(waves):
            assert marker == b"LIST" and wave[:4] == b"wave"
            data_offset, original, data_end = next((at, value, z) for at, marker, value, z in chunks(wave, 4) if marker == b"data")
            pcm = samples[index]
            assert len(original) <= len(pcm), (symbol, index, "PCM length differs")
            # The old export left the final 10 samples undefined. Earlier
            # decoded bytes must match so we cannot silently replace a wave.
            assert original[:-20] == legacy_samples[index][:len(original) - 20], (symbol, index, "PCM body differs")
            repaired_tails += original != pcm
            repaired_wave = b"wave"
            for _, tag, value, _ in chunks(wave, 4):
                repaired_wave += chunk(tag, pcm if tag == b"data" else value)
            wave_offsets.append(len(fixed_waves))
            fixed_waves += chunk(b"LIST", repaired_wave)
        fixed_pool = chunk(b"LIST", b"wvpl" + fixed_waves)
        if canonical_pool is None:
            canonical_pool = fixed_pool
        assert canonical_pool == fixed_pool, (symbol, "wave pool metadata differs")
        prefix_body = b""
        for _, marker, value, _ in chunks(dls[:pool_offset], 12):
            if marker == b"ptbl":
                value = struct.pack("<II", 8, len(wave_offsets)) + struct.pack(f"<{len(wave_offsets)}I", *wave_offsets)
            elif marker == b"LIST":
                value = repair_regions(value, wave_archive["waves"])
            prefix_body += chunk(marker, value)
        suffix = dls[pool_end:]
        prefix = b"RIFF" + struct.pack("<I", 4 + len(prefix_body) + len(fixed_pool) + len(suffix)) + b"DLS " + prefix_body
        (output / (bank["symbol"] + ".prefix")).write_bytes(prefix)
        (output / (bank["symbol"] + ".suffix")).write_bytes(suffix)
        (output / (symbol + ".mid")).write_bytes(midi)
        sequences.append({"id": sequence["id"], "symbol": symbol, "bankSymbol": bank["symbol"],
                          "volume": sequence["volume"], "midiSHA256": sha(midi),
                          "suppliedMIDI_SHA256": sha(supplied_midi),
                          "originalSequenceSHA256": inv["files"][sequence["fileID"]]["sha256"],
                          "suppliedDLS_SHA256": sha(dls), "repairedDLS_SHA256": sha(prefix + fixed_pool + suffix),
                          "tracks": [{"trackID": t["trackID"], "hasNotes": bool(t["notes"]),
                                      "hasMIDIEvents": bool(m[0] or m[1] or m[2]),
                                      "program": next((e[2] for e in t["events"] if e[1] == 129), 0),
                                      "endTick": t["endTick"], "loop": t["loop"]} for t, m in zip(trace["tracks"], midi_tracks)]})
    (output / "OriginalWavePool.bin").write_bytes(canonical_pool)
    manifest = {"schemaVersion": 1, "sourceSDAT_SHA256": inv["sha256"], "ticksPerBeat": 48,
                "wavePoolSHA256": sha(canonical_pool), "sequences": sequences,
                "limitations": ["Apple sampler envelopes and mixing are not verified against the DS.",
                                "MIDI control conversion is not fully validated against the original sound driver.",
                                "Sequence IDs have no inferred scene or chapter mapping.",
                                "SSAR sound effect playback is not implemented by this adapter."],
                "repairedWaveTails": repaired_tails}
    (output / "OriginalAudioManifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    shutil.copy2(root / "inventory.json", output / "OriginalSDATInventory.json")
    shutil.copytree(root / "files", output / "Nitro", dirs_exist_ok=True)
    print(json.dumps({"sequences": len(sequences), "noteEventsVerified": sum(len(t["notes"]) for s in traces for t in s["tracks"]),
                      "repairedWaveTails": repaired_tails, "wavePoolBytes": len(canonical_pool),
                      "resourceBytes": sum(p.stat().st_size for p in output.rglob("*") if p.is_file())}, indent=2))


if __name__ == "__main__":
    main()
