#!/usr/bin/env python3
"""Run the Chapter 1-to-ending XCTest chain in checkpoint dependency order."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess

import verify

ROOT = Path(__file__).resolve().parents[1]
PLAN = Path(__file__).with_name("full-route-tests.json")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--resume", action="store_true",
                        help="Resume a failed development run. Use a new output directory for final verification.")
    args = parser.parse_args()
    directory = args.output.resolve()
    report_path = directory / "route-report.json"
    checkpoint_dir = directory / "checkpoints"
    steps = json.loads(PLAN.read_text())
    if args.resume:
        report = json.loads(report_path.read_text())
        if report["steps"] != steps:
            parser.error("The route plan changed. Start a fresh run in a new output directory.")
        results = report["results"]
        while results and results[-1]["status"] != "passed":
            results.pop()
    else:
        if checkpoint_dir.exists() or report_path.exists():
            parser.error("The output directory contains route evidence. Use a new directory or --resume.")
        directory.mkdir(parents=True, exist_ok=True)
        checkpoint_dir.mkdir()
        report = {"createdUTC": datetime.now(timezone.utc).isoformat(),
                  "steps": steps, "checkpointDirectory": str(checkpoint_dir), "results": []}
        results = report["results"]
    report["status"] = "running"
    report.setdefault("resumed", False)
    report["resumed"] |= args.resume
    env = dict(os.environ, HOTEL_DUSK_ROUTE_CHECKPOINTS=str(checkpoint_dir))
    env["CLANG_MODULE_CACHE_PATH"] = str(ROOT / ".build/clang-cache")
    env["SWIFTPM_MODULECACHE_OVERRIDE"] = str(ROOT / ".build/module-cache")

    def write_report():
        report_path.write_text(json.dumps(report, indent=2) + "\n")

    write_report()
    with (directory / "build.log").open("w") as log:
        build = subprocess.run(["swift", "build", "--build-tests"], cwd=ROOT,
                               env=env, stdout=log, stderr=subprocess.STDOUT)
    if build.returncode:
        report["status"] = "failed"
        write_report()
        print(f"Test build failed. See {directory / 'build.log'}", flush=True)
        return 1
    prefix = ["swift", "test", *verify.supported_xctest_flags(), "--skip-build"]
    for index in range(len(results), len(steps)):
        step = steps[index]
        pattern = r"\." + re.escape(step) + "$"
        print(f"[{index + 1}/{len(steps)}] {step}", flush=True)
        result = verify.run_group(f"route-{index + 1:03d}",
                                  [*prefix, "--filter", pattern], directory, env, strict=True)
        result["test"] = step
        expected = "HotelDuskDuoTests." + step
        if result["cases"] != {expected: "passed"}:
            result["status"] = "failed"
        results.append(result)
        write_report()
        if result["status"] != "passed":
            report["status"] = "failed"
            write_report()
            print(f"Route stopped at {step}. Report: {report_path}", flush=True)
            return 1
    report["handoffs"] = verify.fresh_route_checkpoint_result(checkpoint_dir)
    report["status"] = report["handoffs"]["status"]
    write_report()
    print(f"Route {report['status']}: {len(results)} sections. Report: {report_path}", flush=True)
    return int(report["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
