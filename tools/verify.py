#!/usr/bin/env python3
"""Run native verification and report passed, failed and skipped coverage.

Examples:
  python3 tools/verify.py --profile fast
  python3 tools/verify.py --profile audio --strict
  python3 tools/verify.py --profile reference --checkpoint-dir .build/route-checkpoints --strict
  python3 tools/verify.py --profile reference --strict --fresh-checkpoints
  python3 tools/verify.py --profile all --ios --strict
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
CASE = re.compile(r"Test Case '-\[(\S+) (\S+)\]' (passed|failed|skipped)(?: \([^)]*\))?\.")
ROUTE_DEPENDENCY_SKIP = re.compile(
    r"-\[[^\]\s]*\.(\w+) (\w+)\]\s*:\s*Test skipped - [^\n]*(?:checkpoint|route first|native route)",
    re.IGNORECASE,
)
PY_TOTAL = re.compile(r"Ran (\d+) tests? in")
PY_RESULT = re.compile(r"^(OK|FAILED)(?: \((.*)\))?$")
MAX_ROUTE_CHECKPOINT_PASSES = 20
# This interactive probe needs a developer-supplied starting save.
DIAGNOSTIC_TESTS = {"OriginalChapterFourProbe"}


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
        classes = [name for name in classes if name not in DIAGNOSTIC_TESTS]
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


def test_filter(classes):
    # Swift test names use Module.Class/method. Match the class, not its module.
    return r"\.(?:" + "|".join(re.escape(name) for name in classes) + r")/"


def test_filter_cases(cases):
    """Match only the test cases that need another route-checkpoint pass."""
    by_suite = {}
    for suite, name in cases:
        suite = suite.rsplit(".", 1)[-1]
        by_suite.setdefault(suite, []).append(name)
    suites = []
    for suite, names in sorted(by_suite.items()):
        method_pattern = "|".join(re.escape(name) for name in sorted(set(names)))
        suites.append(re.escape(suite) + r"/(?:" + method_pattern + r")")
    return r"\.(?:" + "|".join(suites) + r")"


def route_dependency_cases(output):
    """Return skipped test IDs that could run after an earlier route pass."""
    return set(ROUTE_DEPENDENCY_SKIP.findall(output))


def route_checkpoint_state(directory):
    """Fingerprint saved route files to detect progress between test passes."""
    if directory is None or not directory.exists():
        return ()
    files = sorted(path for path in directory.rglob("resume.*") if path.is_file())
    return tuple((path.relative_to(directory).as_posix(), hashlib.sha256(path.read_bytes()).hexdigest())
                 for path in files)


def fresh_route_checkpoint_result(directory):
    """Require intact saves at the expected fresh-route handoffs."""
    expected = {"chapter3-entry": (2, 31), "chapter10-ending": (9, 31)}
    cases = {}
    reasons = {}
    for name, (chapter, map_id) in expected.items():
        path = directory / name / "resume.json"
        try:
            record = json.loads(path.read_text())
            state = base64.b64decode(record["state"], validate=True)
            valid = record.get("version") in (1, 2) and hashlib.sha256(state).hexdigest() == record.get("stateSHA256")
            if valid and (len(state) != 0x7D58 or struct.unpack_from("<H", state)[0] != chapter or
                          struct.unpack_from("<h", state, 4)[0] != map_id):
                valid = False
                detail = f"save is not at Chapter {chapter + 1}, map {map_id}"
            elif valid and record["version"] == 2:
                progress = record.get("progress")
                progress_bytes = json.dumps(progress, sort_keys=True, separators=(",", ":"),
                                            ensure_ascii=False, allow_nan=False).encode("utf-8")
                progress_digest = hashlib.sha256(progress_bytes).hexdigest()
                if not isinstance(progress, dict) or progress_digest != record.get("progressSHA256"):
                    valid = False
                    detail = "version 2 interaction progress is missing or has an invalid checksum"
                else:
                    detail = "passed"
            elif valid:
                detail = "passed"
            else:
                detail = "state checksum or version is invalid"
        except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
            valid = False
            detail = f"save is missing or invalid: {error}"
        cases[f"fresh-route-checkpoints/{name}"] = "passed" if valid else "failed"
        if not valid:
            reasons[f"fresh-route-checkpoints/{name}"] = detail
    failed = sum(status == "failed" for status in cases.values())
    return {"name": "fresh-route-checkpoints", "command": ["verify", "fresh-route-checkpoints"],
            "status": "failed" if failed else "passed", "exitCode": int(bool(failed)), "seconds": 0,
            "log": "", "passed": len(expected) - failed, "failed": failed, "skipped": 0,
            "cases": cases, "reasons": reasons}


def merge_test_results(name, results, strict=False):
    """Keep each test's latest status across dependency-driven reruns."""
    cases = {}
    for result in results:
        cases.update(result["cases"])
    counts = {"passed": sum(status == "passed" for status in cases.values()),
              "failed": sum(status == "failed" for status in cases.values()),
              "skipped": sum(status == "skipped" for status in cases.values()),
              "cases": cases}
    failed_run = any(result["status"] == "failed" or result["exitCode"] != 0 for result in results)
    exit_code = 1 if failed_run else 0
    return {"name": name, "command": [result["command"] for result in results],
            "status": group_status(exit_code, counts, strict), "exitCode": exit_code,
            "seconds": round(sum(result["seconds"] for result in results), 2),
            "logs": [result["log"] for result in results], "attempts": len(results), **counts}


def run_reference_group(classes, directory, env, strict, checkpoint_directory, command_prefix):
    """Repeat skipped route tests until earlier test passes create their saves."""
    results = []
    pending_cases = None
    stop_reason = "passLimitReached"
    for attempt in range(1, MAX_ROUTE_CHECKPOINT_PASSES + 1):
        name = f"swift-reference-pass-{attempt:02d}"
        command = [*command_prefix, "--filter",
                   test_filter(classes) if pending_cases is None else test_filter_cases(pending_cases)]
        before = route_checkpoint_state(checkpoint_directory)
        result = run_group(name, command, directory, env, strict=False)
        results.append(result)
        output = (directory / f"{name}.log").read_text(errors="replace")
        pending_cases = route_dependency_cases(output)
        if not pending_cases:
            stop_reason = "noDeferredCases"
            break
        if route_checkpoint_state(checkpoint_directory) == before:
            stop_reason = "noCheckpointProgress"
            break
    merged = merge_test_results("swift-reference", results, strict)
    merged["routeCheckpointStopReason"] = stop_reason
    merged["pendingRouteDependencyCases"] = sorted(
        f"{suite}/{name}" for suite, name in (pending_cases or set())
    )
    return merged


def xctest_flags(help_output):
    """Enable XCTest discovery when the installed SwiftPM supports the flags."""
    if "--enable-xctest" not in help_output:
        return []
    flags = ["--enable-xctest"]
    if "--disable-swift-testing" in help_output:
        flags.append("--disable-swift-testing")
    return flags


def xctest_preflight_failure(return_code, output):
    """Describe why the selected compiler cannot build an XCTest import."""
    if return_code == 0:
        return None
    if "no such module 'XCTest'" in output or 'no such module "XCTest"' in output:
        return "The selected Swift toolchain does not provide XCTest."
    if "SDK is not supported by the compiler" in output:
        return "The selected Swift compiler and SDK versions do not match."
    diagnostic = next((line.strip() for line in reversed(output.splitlines())
                       if "error:" in line), "Swift could not import XCTest.")
    return f"The XCTest preflight failed: {diagnostic}"


def xctest_preflight(env):
    """Check XCTest availability before SwiftPM compiles the full test target."""
    result = subprocess.run(["swiftc", "-typecheck", "-"], input="import XCTest\n",
                            capture_output=True, text=True, check=False, env=env)
    output = result.stdout + result.stderr
    return xctest_preflight_failure(result.returncode, output), output


def unavailable_swift_group(name, directory, reason, output):
    """Record a failed test group when its required XCTest module is absent."""
    log = directory / "xctest-preflight.log"
    log.write_text(output or reason + "\n")
    print(f"{name}: failed; {reason}", flush=True)
    return {"name": name, "command": ["swiftc", "-typecheck", "-"], "status": "failed",
            "exitCode": 1, "seconds": 0, "log": str(log), "passed": 0, "failed": 0,
            "skipped": 0, "cases": {}, "reason": reason}


def supported_xctest_flags():
    result = subprocess.run(["swift", "test", "--help"], capture_output=True,
                            text=True, check=False)
    return xctest_flags(result.stdout + result.stderr)


def route_checkpoint_directory(checkpoint_dir, fresh, output_directory):
    """Choose explicit or isolated route checkpoints without reusing old saves."""
    if checkpoint_dir is not None and fresh:
        raise ValueError("--checkpoint-dir and --fresh-checkpoints cannot be used together")
    if checkpoint_dir is not None:
        return checkpoint_dir.resolve()
    if fresh:
        return output_directory / f"route-checkpoints-{uuid.uuid4().hex}"
    return None


def should_use_fresh_route_checkpoints(profile, checkpoint_dir, requested):
    """Avoid stale route saves by default for profiles that execute route tests."""
    return requested or (profile in ("reference", "all") and checkpoint_dir is None)


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
    parser.add_argument("--fresh-checkpoints", action="store_true",
                        help="Use a new, retained checkpoint directory (default for reference and all)")
    parser.add_argument("--ios", action="store_true", help="Also build the iOS simulator app")
    parser.add_argument("--output", type=Path, default=ROOT / ".build/verification/latest")
    parser.add_argument("--scratch-path", type=Path, help="Separate Swift build directory for concurrent development checks")
    parser.add_argument("--list", action="store_true", help="Print profile membership without running tests")
    args = parser.parse_args()
    if args.fresh_checkpoints and args.profile not in ("reference", "all"):
        parser.error("--fresh-checkpoints requires --profile reference or --profile all")
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
    try:
        fresh_checkpoints = should_use_fresh_route_checkpoints(
            args.profile, args.checkpoint_dir, args.fresh_checkpoints
        )
        checkpoint_dir = route_checkpoint_directory(args.checkpoint_dir, fresh_checkpoints, directory)
    except ValueError as error:
        parser.error(str(error))
    if checkpoint_dir is not None:
        checkpoint_dir.mkdir(parents=True, exist_ok=not args.fresh_checkpoints)
        env["HOTEL_DUSK_ROUTE_CHECKPOINTS"] = str(checkpoint_dir)
    results = []
    if args.profile in ("fast", "all"):
        results.append(run_group("verification-tool", [sys.executable, "-m", "unittest", "discover", "-s", "tools/tests", "-p", "test_verification.py"], directory, env, args.strict))
    command_prefix = ["swift", "test", *supported_xctest_flags(), "--disable-sandbox"]
    if args.scratch_path:
        command_prefix += ["--scratch-path", str(args.scratch_path.resolve())]
    swift_groups = ("reference",) if args.profile == "reference" else (
        ("fast", "audio", "native", "reference") if args.profile == "all" else (args.profile,)
    )
    has_swift_tests = any(groups.get(name) for name in swift_groups)
    preflight_reason, preflight_output = xctest_preflight(env) if has_swift_tests else (None, "")
    if preflight_reason:
        if args.profile == "reference":
            results.append(unavailable_swift_group("swift-reference", directory,
                                                   preflight_reason, preflight_output))
        elif args.profile == "all":
            if any(groups[name] for name in ("fast", "audio", "native")):
                results.append(unavailable_swift_group("swift-non-reference", directory,
                                                       preflight_reason, preflight_output))
            results.append(unavailable_swift_group("swift-reference", directory,
                                                   preflight_reason, preflight_output))
        elif groups.get(args.profile):
            results.append(unavailable_swift_group("swift", directory,
                                                   preflight_reason, preflight_output))
    elif args.profile == "reference":
        results.append(run_reference_group(groups["reference"], directory, env, args.strict,
                                           checkpoint_dir, command_prefix))
    elif args.profile == "all":
        non_reference = groups["fast"] + groups["audio"] + groups["native"]
        if non_reference:
            results.append(run_group("swift-non-reference",
                [*command_prefix, "--filter", test_filter(non_reference)], directory, env, args.strict))
        results.append(run_reference_group(groups["reference"], directory, env, args.strict,
                                           checkpoint_dir, command_prefix))
    elif groups[args.profile]:
        results.append(run_group("swift", [*command_prefix, "--filter", test_filter(groups[args.profile])],
                                 directory, env, args.strict))
    else:
        results.append({"name": "swift", "status": "failed", "exitCode": 1, "passed": 0, "failed": 0, "skipped": 0,
                        "seconds": 0, "log": "", "cases": {}, "reason": "No test classes matched the selected profile"})
    if args.profile == "all" and fresh_checkpoints and checkpoint_dir is not None:
        route_result = fresh_route_checkpoint_result(checkpoint_dir)
        results.append(route_result)
        print(f"fresh-route-checkpoints: {route_result['status']}; "
              f"{route_result['passed']} passed, {route_result['failed']} failed", flush=True)
        for checkpoint, reason in route_result["reasons"].items():
            print(f"{checkpoint}: {reason}", flush=True)
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
    failed_route_checks = [(name, reason) for result in results for name, reason in result.get("reasons", {}).items()]
    if failed_route_checks:
        lines += ["", "## Fresh route checkpoint failures", ""]
        lines += [f"- `{name}`: {reason}" for name, reason in failed_route_checks]
    lines += ["", "Logs and individual test outcomes are in report.json. A passing check does not establish complete route or presentation fidelity.", ""]
    (directory / "report.md").write_text("\n".join(lines))
    print(f"Report: {directory / 'report.md'}", flush=True)
    return 1 if report["status"] == "failed" else 0


if __name__ == "__main__":
    raise SystemExit(main())
