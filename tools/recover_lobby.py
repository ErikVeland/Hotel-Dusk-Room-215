#!/usr/bin/env python3
"""Bundle the supported original map collision members and record their source hashes."""
import hashlib
import json
from pathlib import Path

from cing_container import decode_member
from decode_dtx import Texture

ROOT = Path(__file__).resolve().parents[1]


def main():
    output = ROOT / "Sources/HotelDuskDuoKit/Resources/Original/GameData"
    path = output / "manifest.json"
    manifest = json.loads(path.read_text())
    for name in ["R102", "R103", "R114", "R115", "R117", "R119", "R213", "R205", "R211"]:
        source = ROOT / f"extracted/unpacked_wpf/map/{name}/{name}/{name}.col"
        member = source.read_bytes()
        decoded = decode_member(member)
        if decoded[:16] != b"MDF_COL_100" + bytes(5):
            raise ValueError(f"Unexpected collision format: {name}")
        # Retain the original compressed payload, as the other runtime libraries do.
        payload = member[32:]
        (output / f"{name}.col").write_bytes(payload)
        manifest["files"] = [record for record in manifest["files"] if record["name"] != f"{name}.col"]
        manifest["files"].append({"name": f"{name}.col", "source": str(source.relative_to(ROOT)),
            "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest(),
            "sourceMemberSHA256": hashlib.sha256(member).hexdigest(),
            "decodedSHA256": hashlib.sha256(decoded).hexdigest()})
    path.write_text(json.dumps(manifest, indent=2) + "\n")
    print("Bundled R102.col, R103.col, R114.col, R115.col, R117.col, R119.col, R213.col, R205.col and R211.col")

    for source in sorted((ROOT / "extracted/root/data/map/sdata").glob("*.upv")):
        payload = source.read_bytes()
        name = f"sdata/{source.name}"
        (output / name).write_bytes(payload)
        manifest["files"] = [record for record in manifest["files"] if record["name"] != name]
        manifest["files"].append({"name": name, "source": str(source.relative_to(ROOT)),
            "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()})

    source = ROOT / "extracted/root/data/local/us/itemtext.dat"
    payload = source.read_bytes()
    (output / "itemtext.dat").write_bytes(payload)
    manifest["files"] = [record for record in manifest["files"] if record["name"] != "itemtext.dat"]
    manifest["files"].append({"name": "itemtext.dat", "source": str(source.relative_to(ROOT)),
        "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()})

    source = ROOT / "extracted/root/data/map/sdata/standplace.dat"
    payload = source.read_bytes()
    (output / "standplace.dat").write_bytes(payload)
    manifest["files"] = [record for record in manifest["files"] if record["name"] != "standplace.dat"]
    manifest["files"].append({"name": "standplace.dat", "source": str(source.relative_to(ROOT)),
        "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()})
    source = ROOT / "extracted/root/data/map/sdata/touchevent.lst"
    payload = source.read_bytes()
    (output / "touchevent.lst").write_bytes(payload)
    manifest["files"] = [record for record in manifest["files"] if record["name"] != "touchevent.lst"]
    manifest["files"].append({"name": "touchevent.lst", "source": str(source.relative_to(ROOT)),
        "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()})
    source = ROOT / "extracted/root/data/system/trickitem.bin"
    payload = source.read_bytes()
    (output / "trickitem.bin").write_bytes(payload)
    manifest["files"] = [record for record in manifest["files"] if record["name"] != "trickitem.bin"]
    manifest["files"].append({"name": "trickitem.bin", "source": str(source.relative_to(ROOT)),
        "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()})
    source = ROOT / "extracted/recovered_logic/binaries/arm9.bin"
    payload = source.read_bytes()[0x020DF940 - 0x02004000:0x020DF940 - 0x02004000 + 47]
    (output / "map_search_permissions.bin").write_bytes(payload)
    manifest["files"] = [record for record in manifest["files"] if record["name"] != "map_search_permissions.bin"]
    manifest["files"].append({"name": "map_search_permissions.bin", "source": str(source.relative_to(ROOT)),
        "address": "0x020DF940", "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()})
    path.write_text(json.dumps(manifest, indent=2) + "\n")

    # Refresh the partial-height textures used by the supported route.
    for source_path in ["map/R102/R102/laungr.dtx", "map/R205/R205/telephoe.dtx"]:
        source = ROOT / "extracted/unpacked_wpf" / source_path
        member = source.read_bytes()
        texture = Texture(member[32:])
        digest = lambda data: hashlib.sha256(data).hexdigest()
        record = {"source": source_path, "sourceSHA256": digest(member),
            "payloadSHA256": digest(member[32:]), "payloadBytes": len(member) - 32,
            "status": "decoded", "mode": texture.mode,
            "allocatedWidth": texture.allocated_width, "allocatedHeight": texture.allocated_height,
            "logicalWidth": texture.logical_width, "logicalHeight": texture.logical_height,
            "storedWidth": texture.width, "storedHeight": texture.height,
            "decodedSHA256": digest(texture.data), "paletteSHA256": digest(texture.palette),
            "pixelDataSHA256": digest(texture.pixel_data), "rgbaSHA256": digest(texture.rgba())}
        for target in ["Sources/HotelDuskDuoKit/Resources/OriginalTextures/OriginalTextureManifest.json",
                       "docs/original-texture-report.json"]:
            path = ROOT / target
            manifest = json.loads(path.read_text())
            old = next(item for item in manifest["textures"] if item["source"] == source_path)
            if old["status"] != "decoded":
                manifest["coverage"]["decoded"] += 1
                manifest["coverage"]["unsupported"] -= 1
                manifest["coverage"]["mode7"] += 1
            old.clear()
            old.update(record)
            path.write_text(json.dumps(manifest, indent=2) + "\n")



if __name__ == "__main__":
    main()
