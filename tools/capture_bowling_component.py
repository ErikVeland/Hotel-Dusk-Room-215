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
PIN_COUNT = 10


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
        "pinCollisionRadiusFloat": struct.unpack_from("<f", data, 0x02204D90 - 0x02000000)[0],
        "cameraMatrix": list(struct.unpack_from("<16i", data, base + 0x2B4)),
        # 0x021FDA10 copies both blocks to a 24-word stack buffer immediately
        # before calling 0x02202F88. Keep the source bytes intact while the
        # decompiler's fifth-argument layout and vertex stride remain unclear.
        "dragHitTestInputBlock498Words": list(struct.unpack_from("<24I", data, base + 0x498)),
        "dragHitTestInputBlock4F8Words": list(struct.unpack_from("<24I", data, base + 0x4F8)),
        "modelTransform468Words": list(struct.unpack_from("<6I", data, base + 0x468)),
        "modelTransform4A0Words": list(struct.unpack_from("<6I", data, base + 0x4A0)),
        "drawParameters448Words": list(struct.unpack_from("<8I", data, base + 0x448)),
        "drawParameters480Words": list(struct.unpack_from("<8I", data, base + 0x480)),
        "pinStates": [pin_state(data, base, index) for index in range(10)],
    }


def pin_state(data, base, index):
    """Capture the source pin simulation fields at +0x558 with a 0x60 stride."""
    pin = base + 0x558 + index * 0x60
    position = struct.unpack_from("<3i", data, pin)
    motion = struct.unpack_from("<3i", data, pin + 0x24)
    return {
        "positionFixed20_12": list(position),
        "motionFixed20_12": list(motion),
        "rotationFloat": struct.unpack_from("<f", data, pin + 0x3C)[0],
        "angularVelocityFloat": struct.unpack_from("<f", data, pin + 0x48)[0],
        "needsUpdate": data[pin + 0x5C] != 0,
        "active": data[pin + 0x5D] != 0,
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


def capture_camera_input_trace(ready_checkpoint):
    """Capture the camera and ball state at selected points in a normal roll gesture."""
    commands = [f"load {ready_checkpoint}", "capture ready"]
    commands += ["touch 15 90", "frames 8", "capture down"]
    for x in range(23, 120, 8):
        commands += [f"touch {x} 90", "frames 8"]
        if x in (47, 79, 111, 119):
            commands.append(f"capture drag-{x}")
    commands += ["touch 125 90", "frames 8", "capture drag-125"]
    commands += ["release", "frames 1", "capture released"]
    for frame in range(2, 41):
        commands += ["frames 1", f"capture roll-{frame}"]
        if frame == 23:
            commands.append("save roll-23")
    for delay, name in ((50, "roll-60"), (120, "roll-180")):
        commands += [f"frames {delay}", f"capture {name}"]

    trace = run("component-bowling-camera-input", commands)
    states = {}
    names = ("ready", "down", "drag-47", "drag-79", "drag-111", "drag-119", "drag-125",
             "released", *(f"roll-{frame}" for frame in range(2, 41)), "roll-60", "roll-180")
    for name in names:
        data = (trace / f"{name}-ram.bin").read_bytes()
        base = find_process(data, 0x021FD530)
        states[name] = {
            "stage": struct.unpack_from("<h", data, base + 0x2AC)[0],
            "substage": struct.unpack_from("<h", data, base + 0x2AE)[0],
            "roundIndex": struct.unpack_from("<h", data, base + 0x9AE)[0],
            "pinCollisionRadiusFloat": struct.unpack_from("<f", data, 0x02204D90 - 0x02000000)[0],
            "cameraMatrix": list(struct.unpack_from("<16i", data, base + 0x2B4)),
            "modelTransform468Words": list(struct.unpack_from("<6I", data, base + 0x468)),
            "modelTransform4A0Words": list(struct.unpack_from("<6I", data, base + 0x4A0)),
            "drawParameters448Words": list(struct.unpack_from("<8I", data, base + 0x448)),
            "drawParameters480Words": list(struct.unpack_from("<8I", data, base + 0x480)),
            "lanePlaneTemplate20_12": list(struct.unpack_from("<18i", data, base + 0x300)),
            "ballPlaneTemplate20_12": list(struct.unpack_from("<18i", data, base + 0x348)),
            "touchPoint918": list(struct.unpack_from("<3i", data, base + 0x918)),
            "previousTouchPoint924": list(struct.unpack_from("<3i", data, base + 0x924)),
            "dragDelta20_12": list(struct.unpack_from("<6i", data, base + 0x504)),
            "launchVelocity20_12": list(struct.unpack_from("<3i", data, base + 0x51C)),
            "pinStates": [pin_state(data, base, index) for index in range(10)],
            "pinRotations": [struct.unpack_from("<i", data, base + 0x594 + index * 0x60)[0]
                             for index in range(10)],
        }
    return {
        "kind": "modified-checkpoint camera and roll input trace",
        "romSHA256": digest(ROM),
        "checkpointSHA256": digest(ready_checkpoint),
        "preCollisionCheckpointSHA256": digest(trace / "roll-23.mln"),
        "commandsSHA256": digest(trace / "commands.txt"),
        "touchPath": "From the process-ready checkpoint, press at raw touch (15, 90), hold eight frames, move in eight-pixel steps from X 23 through 119 at Y 90, then move to (125, 90). Hold each point for eight frames, release, then wait 180 frames.",
        "states": states,
    }


def capture_turn_phase_probe(ready_checkpoint):
    """Capture one isolated roll as the bowling controller changes phases."""
    frame_samples = [(180, "after-roll"), (1, "roll-plus-1"), (2, "roll-plus-3"),
                     (7, "roll-plus-10"), (20, "roll-plus-30"), (30, "roll-plus-60"),
                     (60, "roll-plus-120"), (120, "roll-plus-240"),
                     (360, "roll-plus-600")]
    commands = [f"load {ready_checkpoint}", "touch 15 90", "frames 8"]
    for x in range(23, 120, 8):
        commands += [f"touch {x} 90", "frames 8"]
    commands += ["touch 125 90", "frames 8", "release"]
    for frames, name in frame_samples:
        commands += [f"frames {frames}", f"capture {name}"]
    commands += ["keys ffe", "frames 2", "keys fff", "frames 121",
                 "capture player-dialogue-continued", "keys ffe", "frames 2", "keys fff",
                 "frames 300", "capture louie-turn"]

    trace = run("component-bowling-turn-phase-probe", commands)
    states = {}
    for _, name in frame_samples:
        data = (trace / f"{name}-ram.bin").read_bytes()
        base = find_process(data, 0x021FD530)
        states[name] = {
            "processStage": struct.unpack_from("<h", data, base + 0x2AC)[0],
            "processSubstage": struct.unpack_from("<h", data, base + 0x2AE)[0],
            "bowlingState": struct.unpack_from("<h", data, base + 0x2B0)[0],
            "dialogueRequestId": struct.unpack_from("<h", data, base + 0xC56)[0],
            "dialogueCallbackPending": struct.unpack_from("<h", data, base + 0xC58)[0] != 0,
            "dialogueCallbackDelay": struct.unpack_from("<h", data, base + 0xC5A)[0],
            "throwIndex": struct.unpack_from("<h", data, base + 0x9AE)[0],
            "scores": list(struct.unpack_from("<6i", data, base + 0x990)),
            "roundStatuses": list(struct.unpack_from("<3h", data, base + 0x9A8)),
            "ballPositionFixed20_12": list(struct.unpack_from("<3i", data, base + 0x4F8)),
            "ballVelocityFixed20_12": list(struct.unpack_from("<3i", data, base + 0x51C)),
            "pinRotations": [struct.unpack_from("<f", data, base + 0x594 + index * 0x60)[0]
                             for index in range(PIN_COUNT)],
        }
    for name in ("player-dialogue-continued", "louie-turn"):
        data = (trace / f"{name}-ram.bin").read_bytes()
        base = find_process(data, 0x021FD530)
        states[name] = {
            "processStage": struct.unpack_from("<h", data, base + 0x2AC)[0],
            "processSubstage": struct.unpack_from("<h", data, base + 0x2AE)[0],
            "bowlingState": struct.unpack_from("<h", data, base + 0x2B0)[0],
            "dialogueRequestId": struct.unpack_from("<h", data, base + 0xC56)[0],
            "dialogueCallbackPending": struct.unpack_from("<h", data, base + 0xC58)[0] != 0,
            "dialogueCallbackDelay": struct.unpack_from("<h", data, base + 0xC5A)[0],
            "throwIndex": struct.unpack_from("<h", data, base + 0x9AE)[0],
            "scores": list(struct.unpack_from("<6i", data, base + 0x990)),
            "roundStatuses": list(struct.unpack_from("<3h", data, base + 0x9A8)),
            "ballPositionFixed20_12": list(struct.unpack_from("<3i", data, base + 0x4F8)),
            "ballVelocityFixed20_12": list(struct.unpack_from("<3i", data, base + 0x51C)),
            "pinRotations": [struct.unpack_from("<f", data, base + 0x594 + index * 0x60)[0]
                             for index in range(PIN_COUNT)],
        }
    return {
        "schemaVersion": 1,
        "kind": "modified-checkpoint one-roll phase trace",
        "note": "This isolated process capture records controller phases after one ball roll. It does not establish a complete bowling turn or normal Chapter 8 route.",
        "romSHA256": digest(ROM),
        "checkpointSHA256": digest(ready_checkpoint),
        "commandsSHA256": digest(trace / "inputs.txt"),
        "touchPath": "Press at (15,90), move in eight-pixel steps through X 119, touch (125,90), then release.",
        "states": states,
    }


def capture_pin_state_write_probes(ready_checkpoint):
    """Record pin-state writes during an active source roll for collision analysis."""
    ready_ram = ready_checkpoint.parent / f"{ready_checkpoint.stem}-ram.bin"
    base = find_process(ready_ram.read_bytes(), 0x021FD530)
    process = base + 0x02000000
    probes = {
        "unpaired-x-motion": {
            "positions": [(0, 0, 0), (20_000, 0, 20_000)],
            "motions": [(200, 0, 0), (0, 0, 0)],
        },
        "unpaired-z-motion": {
            "positions": [(0, 0, 0), (20_000, 0, 20_000)],
            "motions": [(0, 0, 200), (0, 0, 0)],
        },
        "unpaired-diagonal-motion": {
            "positions": [(0, 0, 0), (20_000, 0, 20_000)],
            "motions": [(120, 0, 160), (0, 0, 0)],
        },
        "x-axis-transfer": {
            "positions": [(0, 0, 0), (1_500, 0, 0)],
            "motions": [(200, 0, 0), (0, 0, 0)],
        },
        "z-axis-transfer": {
            "positions": [(0, 0, 0), (0, 0, 1_500)],
            "motions": [(0, 0, 200), (0, 0, 0)],
        },
        "reverse-x-transfer": {
            "positions": [(1_500, 0, 0), (0, 0, 0)],
            "motions": [(-200, 0, 0), (0, 0, 0)],
        },
        "reverse-z-transfer": {
            "positions": [(0, 0, 1_500), (0, 0, 0)],
            "motions": [(0, 0, -200), (0, 0, 0)],
        },
        "diagonal-transfer": {
            "positions": [(0, 0, 0), (900, 0, 1_200)],
            "motions": [(120, 0, 160), (0, 0, 0)],
        },
        "x-dominant-transfer": {
            "positions": [(0, 0, 0), (1_500, 0, 0)],
            "motions": [(160, 0, 80), (0, 0, 0)],
        },
        "z-dominant-transfer": {
            "positions": [(0, 0, 0), (900, 0, 1_200)],
            "motions": [(80, 0, 160), (0, 0, 0)],
        },
        "reverse-diagonal-transfer": {
            "positions": [(900, 0, 1_200), (0, 0, 0)],
            "motions": [(-120, 0, -160), (0, 0, 0)],
        },
    }


def capture_isolated_pin_interactions(roll_checkpoint):
    """Capture one-frame pin motion and pair collisions with the ball parked."""
    roll_ram = roll_checkpoint.with_name(f"{roll_checkpoint.stem}-ram.bin")
    base = find_process(roll_ram.read_bytes(), 0x021FD530)
    process = base + 0x02000000
    cases = {
        "separated-x-motion": ([(0, 0, 0), (3_000, 0, 0)], [(200, 0, 0), (0, 0, 0)]),
        "overlapping-x-motion": ([(0, 0, 0), (1_500, 0, 0)], [(200, 0, 0), (0, 0, 0)]),
        "overlapping-z-motion": ([(0, 0, 0), (0, 0, 1_500)], [(0, 0, 200), (0, 0, 0)]),
        "approaching-x-motion": ([(0, 0, 0), (1_500, 0, 0)], [(200, 0, 0), (-200, 0, 0)]),
        "separating-x-motion": ([(0, 0, 0), (1_500, 0, 0)], [(-200, 0, 0), (200, 0, 0)]),
        "tangential-x-motion": ([(0, 0, 0), (1_500, 0, 0)], [(0, 0, 200), (0, 0, 0)]),
        "diagonal-motion": ([(0, 0, 0), (900, 0, 1_200)], [(120, 0, 160), (0, 0, 0)]),
    }
    traces = {}
    for name, (positions, motions) in cases.items():
        commands = [f"load {roll_checkpoint}"]
        for index in range(PIN_COUNT):
            pin = process + 0x558 + index * 0x60
            position = positions[index] if index < 2 else (1_000_000 + index * 100_000, 0, 1_000_000)
            motion = motions[index] if index < 2 else (0, 0, 0)
            for offset, value in zip((0, 4, 8), position):
                commands.append(f"write32 {pin + offset:x} {value & 0xffffffff:x}")
            for offset, value in zip((0x24, 0x28, 0x2C), motion):
                commands.append(f"write32 {pin + offset:x} {value & 0xffffffff:x}")
            for offset in (0x3C, 0x48):
                commands.append(f"write32 {pin + offset:x} 0")
            commands.extend((f"write8 {pin + 0x5C:x} {int(index < 2):x}",
                             f"write8 {pin + 0x5D:x} 1"))
        for offset, value in ((0x4F8, 1_000_000), (0x4FC, 0), (0x500, 1_000_000),
                              (0x51C, 0), (0x520, 0), (0x524, 0)):
            commands.append(f"write32 {process + offset:x} {value:x}")
        commands.extend(("capture before", "frames 1", "capture after"))
        trace = run(f"component-bowling-isolated-pin-{name}", commands)
        states = {}
        for state_name in ("before", "after"):
            data = (trace / f"{state_name}-ram.bin").read_bytes()
            state_base = find_process(data, 0x021FD530)
            states[state_name] = {
                "ballPositionFixed20_12": list(struct.unpack_from("<3i", data, state_base + 0x4F8)),
                "ballVelocityFixed20_12": list(struct.unpack_from("<3i", data, state_base + 0x51C)),
                "pinStates": [pin_state(data, state_base, index) for index in range(PIN_COUNT)],
            }
        traces[name] = {"commandsSHA256": digest(trace / "commands.txt"),
                        "input": {"positionsFixed20_12": positions, "motionsFixed20_12": motions},
                        "states": states}
    return {
        "schemaVersion": 1,
        "kind": "modified-checkpoint isolated pin motion and pair-collision captures",
        "romSHA256": digest(ROM),
        "checkpointSHA256": digest(roll_checkpoint),
        "note": "The ball is parked at fixed-point X/Z 1,000,000 with zero velocity. The two tested pins are separated from all other pin records. Captures cover one source update only, not a normal bowling turn or story return.",
        "cases": traces,
    }
    results = {}
    for name, probe in probes.items():
        commands = [f"load {ready_checkpoint}"]
        for index in range(PIN_COUNT):
            pin = process + 0x558 + index * 0x60
            active = index < 2
            position = probe["positions"][index] if active else (0, 0, 0)
            motion = probe["motions"][index] if active else (0, 0, 0)
            for offset, value in zip((0, 4, 8), position):
                commands.append(f"write32 {pin + offset:x} {value & 0xffffffff:x}")
            for offset, value in zip((0x24, 0x28, 0x2C), motion):
                commands.append(f"write32 {pin + offset:x} {value & 0xffffffff:x}")
            for offset in (0x3C, 0x48):
                commands.append(f"write32 {pin + offset:x} 0")
            commands.extend((f"write8 {pin + 0x5C:x} {int(active):x}",
                             f"write8 {pin + 0x5D:x} {int(active):x}"))
        for offset, value in ((0x4F8, 100_000), (0x500, 100_000),
                              (0x51C, 0), (0x520, 0), (0x524, 0)):
            commands.append(f"write32 {process + offset:x} {value:x}")
        commands.extend(("capture before", "frames 1", "capture after"))
        trace = run(f"component-bowling-pin-state-write-{name}", commands)
        states = {}
        for state_name in ("before", "after"):
            data = (trace / f"{state_name}-ram.bin").read_bytes()
            state_base = find_process(data, 0x021FD530)
            states[state_name] = {
                "pinCollisionRadiusFloat": struct.unpack_from("<f", data, 0x02204D90 - 0x02000000)[0],
                "pinStates": [pin_state(data, state_base, index)
                              for index in range(PIN_COUNT)],
            }
        results[name] = {
            "commandsSHA256": digest(trace / "commands.txt"),
            "states": states,
        }
    return {
        "kind": "modified-checkpoint exploratory pin-state writes",
        "romSHA256": digest(ROM),
        "checkpointSHA256": digest(ready_checkpoint),
        "probes": results,
        "note": "These probes modify pin state while a source ball roll remains active. Writes to the touch-delta and launch-velocity fields do not park the ball, so post-update pin changes cannot be attributed to pin-pair collisions.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reuse-walking-base", action="store_true")
    parser.add_argument("--pin-collision-only", action="store_true")
    parser.add_argument("--turn-phase-probe", action="store_true")
    args = parser.parse_args()
    if args.turn_phase_probe:
        checkpoint = ROOT / "extracted/reference/component-bowling/ready.mln"
        fixture = ROOT / "Tests/Fixtures/Bowling/turn-phase-probe.json"
        fixture.write_text(json.dumps(capture_turn_phase_probe(checkpoint), indent=2) + "\n")
        print(f"Captured the isolated bowling turn phases in {fixture}")
        return
    if args.pin_collision_only:
        roll_checkpoint = ROOT / "extracted/reference/component-bowling-camera-input/roll-23.mln"
        fixture = ROOT / "Tests/Fixtures/Bowling/isolated-pin-interactions.json"
        fixture.write_text(json.dumps(capture_isolated_pin_interactions(roll_checkpoint), indent=2) + "\n")
        print(f"Captured isolated pin interactions in {fixture}")
        return
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
    camera_trace = capture_camera_input_trace(trace / "ready.mln")
    (fixture / "camera-input-trace.json").write_text(json.dumps(camera_trace, indent=2) + "\n")
    pin_state_write_trace = capture_pin_state_write_probes(
        ROOT / "extracted/reference/component-bowling-camera-input/roll-23.mln")
    (fixture / "pin-state-write-probes.json").write_text(json.dumps(pin_state_write_trace, indent=2) + "\n")
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
