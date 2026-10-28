#!/usr/bin/env python3
"""Map referenced story process IDs to their original factory resource groups."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FACTORY = ROOT / "extracted/decompiled/arm9/0200b334.c"
COVERAGE = ROOT / "docs/story-process-coverage.json"
OVERLAYS = ROOT / "extracted/decompiled"
RUNTIME_TABLES = ROOT / "extracted/recovered_logic/runtime-tables.json"


def main() -> None:
    factory = FACTORY.read_text()
    overlay_slots = json.loads(RUNTIME_TABLES.read_text())["overlayLoader"]["slotToOverlayID"]
    cases = {
        int(match.group(1), 0): match.group(2)
        for match in re.finditer(
            r"case (0x[0-9a-f]+|\d+):(.*?)(?=\n  case |\n  default:)",
            factory,
            re.S,
        )
    }
    coverage = json.loads(COVERAGE.read_text())
    rows = []
    for chapter in coverage["chapters"]:
        for process_id in chapter["requiredProcesses"]:
            case_id = process_id
            body = cases.get(case_id, "")
            groups = [
                int(value, 0)
                for value in re.findall(
                    r"FUN_0200b2d8\((0x[0-9a-f]+|\d+)\)", body
                )
            ]
            sources = []
            for slot in groups:
                if not 0 <= slot < len(overlay_slots):
                    sources.append(f"slot {slot}: outside the overlay table")
                    continue
                overlay_id = overlay_slots[slot]
                path = OVERLAYS / f"overlay_{overlay_id:04d}" / "globals.json"
                if not path.exists():
                    sources.append(f"slot {slot} -> overlay {overlay_id}: no globals")
                    continue
                globals_data = json.loads(path.read_text())
                names = sorted(
                    {
                        reference["pointedString"].rsplit("/", 1)[-1]
                        for reference in globals_data["references"]
                        if reference.get("pointedString", "").startswith(
                            "/data/trick/"
                        )
                    }
                )
                sources.append(f"slot {slot} -> overlay {overlay_id}: {', '.join(names) or 'no trick assets'}")
            rows.append((chapter["chapter"], process_id, case_id, sources))

    print("chapter\tprocess\tfactory-case\toverlay resources")
    for chapter, process_id, case_id, sources in rows:
        print(
            f"{chapter}\t{process_id}\t0x{case_id:02x}\t"
            f"{' | '.join(sources) if sources else 'no group call'}"
        )


if __name__ == "__main__":
    main()
