#!/usr/bin/env python3
import json
import os
import sys

def parse_txt_file(path):
    lines = []
    with open(path, "r", encoding="latin-1", errors="replace") as f:
        for line in f:
            lines.append(line.rstrip("\r\n"))
    return lines

def parse_dat_strings(path):
    # Extracts printable null-terminated strings from binary dat files
    with open(path, "rb") as f:
        data = f.read()
    strings = []
    cur = bytearray()
    for b in data:
        if b == 0:
            if len(cur) >= 2:
                try:
                    s = cur.decode("latin-1")
                    if any(c.isalnum() for c in s):
                        strings.append(s)
                except Exception:
                    pass
            cur = bytearray()
        elif 32 <= b <= 126 or b in (10, 13, 9):
            cur.append(b)
        else:
            if len(cur) >= 2:
                try:
                    s = cur.decode("latin-1")
                    if any(c.isalnum() for c in s):
                        strings.append(s)
                except Exception:
                    pass
            cur = bytearray()
    return strings

def export_all_text(data_dir, output_json):
    os.makedirs(os.path.dirname(output_json), exist_ok=True)
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
        catalog["maps"] = parse_dat_strings(map_path)

    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(catalog, f, indent=2, ensure_ascii=False)

    print(f"Exported text catalog to {output_json}:")
    print(f"  System strings: {len(catalog['system_text'].get('sl_usa', []))} (SL) + {len(catalog['system_text'].get('sr_usa', []))} (SR)")
    print(f"  Items extracted: {len(catalog['items'])}")
    print(f"  Map strings extracted: {len(catalog['maps'])}")

if __name__ == "__main__":
    ddir = sys.argv[1] if len(sys.argv) > 1 else "extracted/root/data"
    out = sys.argv[2] if len(sys.argv) > 2 else "HotelDuskDuo/Resources/GameText.json"
    export_all_text(ddir, out)
