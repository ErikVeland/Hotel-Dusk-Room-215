#!/usr/bin/env python3
"""Capture the two source control hit areas for process 52."""
import hashlib
import itertools
import json
from pathlib import Path
import re
import struct

from capture_bowling_component import ROOT, ROM, WALKING, find_process, run

UPDATE = 0x021FD888
PROCESS_BASE = 0x022D1C20
INPUT_STATE = 0x67
CASES = {
    "first": (47, 47, 0),
    "second": (47, 143, 1),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def camera_fields(data, base):
    """Capture the four fixed-point vectors copied into the source camera."""
    return {
        "positionAtCameraOffset3C": list(struct.unpack_from("<3i", data, base + 0x2B0)),
        "vectorAtCameraOffset48": list(struct.unpack_from("<3i", data, base + 0x2C8)),
        "vectorAtCameraOffset54": list(struct.unpack_from("<3i", data, base + 0x2BC)),
        "vectorAtCameraOffset60": list(struct.unpack_from("<3i", data, base + 0x2D4)),
    }


def capture(name, point):
    x, y, expected_selector = point
    commands = [
        f"load {WALKING}",
        "release",
        "frames 1",
        "write32 0227d2f0 34",
        "write32 0227d2f4 34",
        "frames 300",
        "capture ready",
        f"write16 {PROCESS_BASE + 0x43E:08x} {INPUT_STATE:x}",
        f"touch {x} {y}",
        "frames 1",
        "capture selected",
    ]
    directory = run(f"component-cassette02-{name}", commands)
    data = (directory / "selected-ram.bin").read_bytes()
    base = find_process(data, UPDATE)
    if base + 0x43E != PROCESS_BASE - 0x02000000 + 0x43E:
        raise ValueError("Process 52 did not use the expected checkpoint address")
    input_state = struct.unpack_from("<h", data, base + 0x43E)[0]
    selector = struct.unpack_from("<h", data, base + 0x5B4)[0]
    manager = 0x020FD85A - 0x02000000
    if input_state != 0x68 or selector != expected_selector or data[manager + 0x11] == 0:
        raise ValueError(f"Unexpected source control result for {name}")
    return {
        "rawTouch": [x, y],
        "inputStateAfter": input_state,
        "selectorAfter": selector,
        "touchActive": True,
        "commandsSHA256": digest(directory / "commands.txt"),
        "readyFrameSHA256": digest(directory / "ready-ram.bin"),
        "selectedFrameSHA256": digest(directory / "selected-ram.bin"),
    }


def capture_normal_input_path():
    commands = [
        f"load {WALKING}",
        "release",
        "frames 1",
        "write32 0227d2f0 34",
        "write32 0227d2f4 34",
        "frames 300",
        "capture opening",
        "touch 76 156",
        "frames 1",
    ]
    for y in range(155, 107, -1):
        commands.extend([f"touch 76 {y}", "frames 1"])
    commands.extend([
        "frames 180",
        "capture controls-ready",
        "release",
        "frames 8",
        "keys ffe",
        "frames 1",
        "keys fff",
        "frames 500",
        "capture playback",
        "release",
        "frames 1",
        "touch 15 177",
        "frames 1",
        "capture exit-requested",
        "release",
        "frames 240",
        "capture after-exit",
    ])
    directory = run("component-cassette02-normal-input", commands)
    states = {}
    for name in ("opening", "controls-ready", "playback", "exit-requested", "after-exit"):
        data = (directory / f"{name}-ram.bin").read_bytes()
        base = find_process(data, UPDATE)
        def model_transform(rotation_offset):
            return {
                "rotationFloat": list(struct.unpack_from("<3f", data, base + rotation_offset)),
                "translationFloat": list(struct.unpack_from("<3f", data, base + rotation_offset + 12)),
            }
        states[name] = {
            "mainPhase": struct.unpack_from("<h", data, base + 0x2AE)[0],
            "inputState": struct.unpack_from("<h", data, base + 0x43E)[0],
            "exitFlag": struct.unpack_from("<h", data, base + 0x43C)[0],
            "selector": struct.unpack_from("<h", data, base + 0x5B4)[0],
            "renderState": {
                "cameraFieldsFixed20_12": camera_fields(data, base),
                "models": {
                    "radio": model_transform(0x4D8),
                    "front": model_transform(0x468),
                    "tape": model_transform(0x4A0),
                },
                "modelOrder": ["radio", "front", "tape"],
            },
            "ramSHA256": digest(directory / f"{name}-ram.bin"),
        }
    ready_ram = (directory / "controls-ready-ram.bin").read_bytes()
    base = find_process(ready_ram, UPDATE)
    ready_frame = re.search(r"captured controls-ready frame (\d+)",
                             (directory / "runner.log").read_text())
    if ready_frame is None:
        raise ValueError("The source runner did not report the controls-ready frame")
    def transform(rotation_offset):
        return {
            "rotationFloat": list(struct.unpack_from("<3f", ready_ram, base + rotation_offset)),
            "translationFloat": list(struct.unpack_from("<3f", ready_ram, base + rotation_offset + 12)),
        }
    return {
        "commandsSHA256": digest(directory / "commands.txt"),
        "states": states,
        "controlsReadyRenderState": {
            "captureFrame": int(ready_frame.group(1)),
            "cameraFieldsFixed20_12": camera_fields(ready_ram, base),
            "models": {
                "radio": transform(0x4D8),
                "front": transform(0x468),
                "tape": transform(0x4A0),
            },
            "modelOrder": ["radio", "front", "tape"],
        },
        "audioCueLog": (directory / "audio-cues.csv").read_text().splitlines(),
    }


def capture_scene_hit_probes():
    points = list(itertools.product((60, 68, 76, 84, 92, 100), (96, 108, 120, 132, 144, 156, 168)))
    commands = []
    for index, (x, y) in enumerate(points):
        commands.extend([
            f"load {WALKING}",
            "release",
            "frames 1",
            "write32 0227d2f0 34",
            "write32 0227d2f4 34",
            "frames 300",
            f"touch {x} {y}",
            "frames 1",
            f"peek16 {PROCESS_BASE + 0x43E:08x}",
            "peek8 020fd86b",
        ])
    directory = run("component-cassette02-scene-hit-probes", commands)
    samples = []
    reads = re.findall(
        rf"peek16 {PROCESS_BASE + 0x43E:x} ([0-9a-fA-F]+)",
        (directory / "runner.log").read_text())
    touch_reads = re.findall(r"peek8 20fd86b ([0-9a-fA-F]+)", (directory / "runner.log").read_text())
    if len(reads) != len(points) or len(touch_reads) != len(points):
        raise ValueError(f"Expected {len(points)} source reads, got {len(reads)} and {len(touch_reads)}")
    for (x, y), state, touch in zip(points, reads, touch_reads):
        state_value = int(state, 16)
        samples.append({
            "rawTouch": [x, y],
            "touchActive": int(touch, 16) != 0,
            "inputStateAfter": state_value if state_value < 0x8000 else state_value - 0x10000,
            "sceneHit": state_value == 2,
        })
    return {
        "commandsSHA256": digest(directory / "commands.txt"),
        "points": samples,
    }


def main():
    results = {name: capture(name, point) for name, point in CASES.items()}
    normal_input_path = capture_normal_input_path()
    scene_hit_probes = capture_scene_hit_probes()
    payload = {
        "evidenceType": "isolated process fixtures",
        "processID": 52,
        "overlay": 28,
        "variant": 6,
        "update": f"0x{UPDATE:08X}",
        "injectedInputState": INPUT_STATE,
        "controlBounds": {
            "first": [192, 16, 224, 80],
            "second": [192, 112, 224, 176],
        },
        "controlBoundsOrder": "[minimumTransformedX, minimumTransformedY, maximumTransformedX, maximumTransformedY]",
        "orientationFlag": 0,
        "romSHA256": digest(ROM),
        "checkpointSHA256": digest(WALKING),
        "results": results,
        "normalInputPath": normal_input_path,
        "sceneHitProbes": scene_hit_probes,
        "limitations": [
            "The control-bound probes write the internal input state directly.",
            "The normal-input trace injects process 52 from a walking checkpoint.",
            "It does not verify the story route or parent state after process return.",
            "It does not identify the visible object masks for the native view.",
            "The audio cue log records BGM state, not cassette sound fidelity.",
        ],
    }
    destination = ROOT / "Tests/Fixtures/Cassette/process-52-control-hit-probes.json"
    destination.write_text(json.dumps(payload, indent=2) + "\n")
    print(destination)


if __name__ == "__main__":
    main()
