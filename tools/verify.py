#!/usr/bin/env python3
"""Run native verification and report passed, failed and skipped coverage.

Examples:
  python3 tools/verify.py --profile fast
  python3 tools/verify.py --profile audio --strict
  python3 tools/verify.py --profile reference --checkpoint-dir .build/route-checkpoints --strict
  python3 tools/verify.py --profile all --ios --strict
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
CASE = re.compile(r"Test Case '-\[(\S+) (\S+)\]' (passed|failed|skipped)(?: \([^)]*\))?\.")
PY_TOTAL = re.compile(r"Ran (\d+) tests? in")
PY_RESULT = re.compile(r"^(OK|FAILED)(?: \((.*)\))?$")


def parse_tests(output):
    cases = {}
    for match in CASE.finditer(output):
        suite, name, status = match.groups()
        cases[f"{suite}/{name}"] = status
    if cases:
        return {"passed": sum(v == "passed" for v in cases.values()),
                "failed": sum(v == "failed" for v in cases.values()),
                "skipped": sum(v == "skipped" for v in cases.values()), "cases": cases}
    total = PY_TOTAL.search(output)
    result = next((PY_RESULT.match(line) for line in reversed(output.splitlines()) if PY_RESULT.match(line)), None)
    counts = {"passed": 0, "failed": 0, "skipped": 0, "cases": {}}
    if total and result:
        details = result[2] or ""
        skipped = re.search(r"skipped=(\d+)", details)
        failures = re.findall(r"(?:failures|errors|unexpected successes)=(\d+)", details)
        counts["skipped"] = int(skipped[1]) if skipped else 0
        counts["failed"] = sum(map(int, failures))
        counts["passed"] = int(total[1]) - counts["skipped"] - counts["failed"]
    return counts


def classify_tests():
    groups = {name: [] for name in ("fast", "audio", "native", "reference")}
    for path in sorted((ROOT / "Tests/HotelDuskDuoTests").glob("*.swift")):
        text = path.read_text()
        classes = re.findall(r"(?:final\s+)?class\s+(\w+)\s*:\s*XCTestCase", text)
        if not classes:
            continue
        if re.search(r"extracted/reference|HOTEL_DUSK_ROUTE_CHECKPOINTS", text):
            group = "reference"
        elif re.search(r"OriginalAudioTests|RecordedMusicTests|OriginalMapAudioTests|AudioProfilingTests", text):
            group = "audio"
        elif re.search(r"MTLCreateSystemDefaultDevice|AVAudioEngine|AudioController|GameSession|OriginalPlaySession|\b\w+Renderer\b", text):
            group = "native"
        else:
            group = "fast"
        groups[group].extend(classes)
    return groups


def group_status(exit_code, counts, strict=False):
    if exit_code != 0 or counts["failed"]:
        return "failed"
    if strict and counts["skipped"]:
        return "failed"
    return "passed"


def run_group(name, command, directory, env, strict, tests=True):
    print(f"Running {name}…", flush=True)
    started = time.monotonic()
    path = directory / f"{name}.log"
    with path.open("w") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        code = process.wait()
    output = path.read_text(errors="replace")
    counts = parse_tests(output)
    status = group_status(code, counts, strict)
    # A successful tool invocation that ran no tests must not claim test coverage.
    if tests and code == 0 and not sum(counts[k] for k in ("passed", "failed", "skipped")):
        status = "failed"
    result = {"name": name, "command": command, "status": status, "exitCode": code,
              "seconds": round(time.monotonic() - started, 2), "log": str(path), **counts}
    print(f"{name}: {status}; {counts['passed']} passed, {counts['failed']} failed, {counts['skipped']} skipped ({result['seconds']} s)", flush=True)
    if status == "failed":
        diagnostics = [line for line in output.splitlines() if "error:" in line or "skipped:" in line]
        print("\n".join(diagnostics[:12]), flush=True)
        print("\n".join(output.splitlines()[-12:]), flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--profile", choices=["fast", "audio", "native", "reference", "all"], default="fast")
    parser.add_argument("--strict", action="store_true", help="Fail if any selected test is skipped")
    parser.add_argument("--checkpoint-dir", type=Path, help="Checkpoints generated through the full native route")
    parser.add_argument("--ios", action="store_true", help="Also build the iOS simulator app")
    parser.add_argument("--output", type=Path, default=ROOT / ".build/verification/latest")
    parser.add_argument("--scratch-path", type=Path, help="Separate Swift build directory for concurrent development checks")
    parser.add_argument("--list", action="store_true", help="Print profile membership without running tests")
    args = parser.parse_args()
    groups = classify_tests()
    if args.list:
        print(json.dumps(groups, indent=2))
        return 0
    directory = args.output.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env["CLANG_MODULE_CACHE_PATH"] = str(ROOT / ".build/clang-cache")
    env["SWIFTPM_MODULECACHE_OVERRIDE"] = str(ROOT / ".build/module-cache")
    env["HOTEL_DUSK_AUDIO_PROFILE"] = str(directory / "audio-profile.json")
    if args.checkpoint_dir:
        env["HOTEL_DUSK_ROUTE_CHECKPOINTS"] = str(args.checkpoint_dir.resolve())
    results = []
    if args.profile in ("fast", "all"):
        results.append(run_group("verification-tool", [sys.executable, "-m", "unittest", "discover", "-s", "tools/tests", "-p", "test_verification.py"], directory, env, args.strict))
    selected = sum(groups.values(), []) if args.profile == "all" else groups[args.profile]
    if selected:
        command = ["swift", "test", "--disable-sandbox"]
        if args.scratch_path:
            command += ["--scratch-path", str(args.scratch_path.resolve())]
        command += ["--filter", "|".join(f"\\b{name}\\b" for name in selected)]
        results.append(run_group("swift", command, directory, env, args.strict))
    else:
        results.append({"name": "swift", "status": "failed", "exitCode": 1, "passed": 0, "failed": 0, "skipped": 0,
                        "seconds": 0, "log": "", "cases": {}, "reason": "No test classes matched the selected profile"})
    if args.profile in ("audio", "all"):
        if (ROOT / "extracted/audio/inventory.json").exists():
            results.append(run_group("source-audio", [sys.executable, "tools/test_original_audio.py"], directory, env, args.strict))
        else:
            results.append({"name": "source-audio", "status": "failed" if args.strict else "skipped", "exitCode": None,
                            "passed": 0, "failed": 0, "skipped": 1, "seconds": 0, "log": "", "cases": {},
                            "reason": "Missing extracted/audio/inventory.json. Run the documented source recovery first."})
    results.append(run_group("story-coverage", [sys.executable, "tools/audit_story_coverage.py", "--output", str(directory / "story-coverage.json"),
                                               "--markdown", str(directory / "story-coverage.md")], directory, env, args.strict, tests=False))
    if args.ios:
        results.append(run_group("ios-build", ["xcodebuild", "-project", "HotelDuskDuo.xcodeproj", "-scheme", "HotelDuskDuoiOS",
                                               "-sdk", "iphonesimulator", "-destination", "generic/platform=iOS Simulator",
                                               "-derivedDataPath", str(ROOT / ".build/verification-ios"), "CODE_SIGNING_ALLOWED=NO", "build"],
                                 directory, env, args.strict, tests=False))
    report = {"schemaVersion": 1, "createdUTC": datetime.now(timezone.utc).isoformat(), "profile": args.profile,
              "strict": args.strict, "checkpointDirectory": env.get("HOTEL_DUSK_ROUTE_CHECKPOINTS"),
              "profileMembership": groups, "results": results,
              "status": "failed" if any(r["status"] == "failed" for r in results) else "passed"}
    (directory / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    lines = ["# Verification results", "", f"Result: **{report['status']}**. Profile: `{args.profile}`. Strict: `{args.strict}`.", "",
             "| Check | Result | Passed | Failed | Skipped | Seconds |", "| --- | --- | ---: | ---: | ---: | ---: |"]
    for r in results:
        lines.append(f"| {r['name']} | {r['status']} | {r['passed']} | {r['failed']} | {r['skipped']} | {r['seconds']} |")
    skipped = [name for result in results for name, status in result["cases"].items() if status == "skipped"]
    if skipped:
        lines += ["", "## Skipped coverage", ""] + [f"- `{name}`" for name in skipped]
    lines += ["", "Logs and individual test outcomes are in report.json. A passing check does not establish complete route or presentation fidelity.", ""]
    (directory / "report.md").write_text("\n".join(lines))
    print(f"Report: {directory / 'report.md'}", flush=True)
    return 1 if report["status"] == "failed" else 0


if __name__ == "__main__":
    raise SystemExit(main())
