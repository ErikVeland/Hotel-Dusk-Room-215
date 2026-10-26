#!/usr/bin/env python3
"""Bundle supplied MP3s with measured repeats and native sequence timing.

Requires ffmpeg and numpy. Audio bytes are copied without re-encoding. The
repeat check uses energy envelopes to tolerate the DS driver's modulation.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Source/hoteldusk-soundtrack"
OUTPUT = ROOT / "Sources/HotelDuskDuoKit/Resources/RecordedMusic"
# Median measured repeat/native-duration ratio across the supplied recordings.
TIME_SCALE = 1.0002916666666666


def variable(data, position):
    value = 0
    for _ in range(4):
        byte = data[position]
        position += 1
        value = (value << 7) | (byte & 127)
        if byte < 128:
            return value, position
    raise ValueError("Invalid MIDI variable integer")


def midi_timing(path):
    data = path.read_bytes()
    division = int.from_bytes(data[12:14], "big")
    assert division == 48
    position = 14
    tempos = []
    first_note = None
    for _ in range(int.from_bytes(data[10:12], "big")):
        size = int.from_bytes(data[position + 4:position + 8], "big")
        track = data[position + 8:position + 8 + size]
        position += size + 8
        at = tick = running = 0
        while at < len(track):
            delta, at = variable(track, at)
            tick += delta
            status = track[at]
            if status >= 128:
                at += 1
            else:
                status = running
            if status == 255:
                kind = track[at]
                size, at = variable(track, at + 1)
                if kind == 81:
                    tempos.append((tick, int.from_bytes(track[at:at + size], "big")))
                at += size
            elif status in (240, 247):
                size, at = variable(track, at)
                at += size
            else:
                running = status
                if status & 240 == 144 and track[at + 1] > 0:
                    first_note = min(first_note if first_note is not None else tick, tick)
                at += 1 if status & 240 in (192, 208) else 2
    return sorted(dict(tempos).items()), first_note or 0


def seconds(tick, tempos):
    total = previous = 0
    tempo = 500_000
    for at, value in tempos:
        if at > tick:
            break
        total += (at - previous) * tempo / 48_000_000
        previous, tempo = at, value
    return total + (tick - previous) * tempo / 48_000_000


def decode(path, rate):
    return np.frombuffer(subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(rate),
        "-f", "f32le", "-"], stderr=subprocess.PIPE), dtype="<f4")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    native = json.loads((ROOT / "Sources/HotelDuskDuoKit/Resources/Original/Audio/OriginalAudioManifest.json").read_text())
    tracks = []
    for sequence in native["sequences"]:
        identifier = sequence["id"]
        matches = list(SOURCE.glob(f"{identifier + 1:02d} - *.mp3"))
        assert len(matches) == 1, (identifier, matches)
        source = matches[0]
        tempos, first_note = midi_timing(ROOT / "Source/Music" / (sequence["symbol"] + ".mid"))
        mono = decode(source, 1000).astype("float64")
        # Locate initial audio to account for recording/encoder start latency.
        envelope = np.sqrt(np.convolve(mono * mono, np.ones(5) / 5, "same"))
        onset = int(np.flatnonzero(envelope > max(envelope.max() * .005, 1e-5))[0]) / 1000
        offset = onset - seconds(first_note, tempos) * TIME_SCALE
        assert -.05 <= offset <= .25, (identifier, offset)
        pcm = decode(source, 44100)
        row = {"id": identifier, "symbol": sequence["symbol"], "title": source.stem[5:],
               "file": f"{identifier:02d}.mp3", "sourceFile": source.name,
               "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
               "sampleRate": 44100, "frameCount": len(pcm), "timeScale": TIME_SCALE,
               "offsetSeconds": offset,
               "nativeEndSeconds": seconds(max(t["endTick"] for t in sequence["tracks"]), tempos)}
        loops = [track["loop"] for track in sequence["tracks"] if track["loop"]]
        if loops:
            assert all((loop["startTick"], loop["endTick"]) ==
                       (loops[0]["startTick"], loops[0]["endTick"]) for loop in loops)
            start = seconds(loops[0]["startTick"], tempos)
            end = seconds(loops[0]["endTick"], tempos)
            period = (end - start) * TIME_SCALE
            # Shift the repeat into settled audio, preserving the introduction
            # and avoiding the recording's initial silence and album fade.
            a = start * TIME_SCALE + offset + 2
            b = a + period
            assert b < len(mono) / 1000 - 5, (identifier, b)
            energy = np.sqrt(np.convolve(mono * mono, np.ones(31) / 31, "same"))
            at = round(a * 1000)
            template = energy[at:at + 12000]
            template = template - template.mean()
            lower = round(at + period * 1000 - 50)
            candidate = energy[lower:lower + len(template) + 100]
            n = len(template)
            numerator = np.correlate(candidate, template, "valid")
            variance = np.convolve(candidate * candidate, np.ones(n), "valid")
            variance -= np.convolve(candidate, np.ones(n), "valid") ** 2 / n
            correlation = numerator / np.sqrt(variance + 1e-16) / np.linalg.norm(template)
            best = int(correlation.argmax())
            assert correlation[best] > .94, (identifier, correlation[best])
            measured = (lower + best - at) / 1000
            assert abs(measured - period) < .01, (identifier, measured, period)
            loop_start = round(a * 44100)
            loop_end = loop_start + round(period * 44100)
            row.update(nativeLoopStartSeconds=start, nativeLoopEndSeconds=end,
                       loopStartFrame=loop_start, loopEndFrame=loop_end,
                       repeatCorrelation=round(float(correlation[best]), 6),
                       repeatTimingErrorSeconds=round(measured - period, 6))
        shutil.copyfile(source, OUTPUT / row["file"])
        tracks.append(row)
        print(f"{identifier + 1:02d} {row['title']}: {'loop verified' if loops else 'plays once'}", flush=True)
    (OUTPUT / "manifest.json").write_text(json.dumps({"schemaVersion": 1, "tracks": tracks}, indent=2) + "\n")


if __name__ == "__main__":
    main()
