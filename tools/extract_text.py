#!/usr/bin/env python3
import json
import os
import re
import struct
import sys

def parse_map_strings(path):
    # Map records contain a two-byte ID and a 32-byte name after the count.
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 4:
        raise ValueError("Map text header is incomplete.")
    count, = struct.unpack_from("<I", data)
    if len(data) != 4 + count * 34:
        raise ValueError("Map text record count does not match the file size.")
    strings = [""] * count
    seen = set()
    for offset in range(4, len(data), 34):
        map_id, name = struct.unpack_from("<H32s", data, offset)
        if not 1 <= map_id <= count or map_id in seen:
            raise ValueError("Map text contains an invalid or duplicate map ID.")
        seen.add(map_id)
        strings[map_id - 1] = name.split(b"\0", 1)[0].decode("latin-1")
    return strings

def parse_txt_file(path):
    with open(path, "r", encoding="latin-1", errors="replace") as f:
        return [line.rstrip("\r\n") for line in f]

def parse_dat_strings(path):
    with open(path, "rb") as f:
        data = f.read()
    strings = []
    for match in re.finditer(rb"[\x20-\x7e\t\r\n]{2,}", data):
        text = match[0].decode("ascii")
        if any(character.isalnum() for character in text):
            strings.append(text)
    return strings

def export_all_text(data_dir, output_json):
    os.makedirs(os.path.dirname(output_json) or ".", exist_ok=True)
    catalog = {
        "system_text": {},
        "dialogues": {},
        "items": [],
        "maps": []
    }

    sl_path = os.path.join(data_dir, "local/us/SL_USA.txt")
    if os.path.exists(sl_path):
        catalog["system_text"]["sl_usa"] = parse_txt_file(sl_path)

    sr_path = os.path.join(data_dir, "local/us/SR_USA.txt")
    if os.path.exists(sr_path):
        catalog["system_text"]["sr_usa"] = parse_txt_file(sr_path)

    items_path = os.path.join(data_dir, "local/us/itemtext.dat")
    if os.path.exists(items_path):
        catalog["items"] = parse_dat_strings(items_path)

    map_path = os.path.join(data_dir, "local/us/maptext.dat")
    if os.path.exists(map_path):
        catalog["maps"] = parse_map_strings(map_path)

    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(catalog, f, indent=2, ensure_ascii=False)

    print(f"Exported text catalog to {output_json}:")
    print(f"  System strings: {len(catalog['system_text'].get('sl_usa', []))} (SL) + {len(catalog['system_text'].get('sr_usa', []))} (SR)")
    print(f"  Items extracted: {len(catalog['items'])}")
    print(f"  Map strings extracted: {len(catalog['maps'])}")

if __name__ == "__main__":
    ddir = sys.argv[1] if len(sys.argv) > 1 else "extracted/root/data"
    out = sys.argv[2] if len(sys.argv) > 2 else "Sources/HotelDuskDuoKit/Resources/GameText.json"
    export_all_text(ddir, out)
