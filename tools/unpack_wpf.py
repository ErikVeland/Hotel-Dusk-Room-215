#!/usr/bin/env python3
import os
import struct
import sys

INLINE_HEADER_SIZE = 32

def unpack_wpf(tbl_path, wpf_path, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    with open(tbl_path, "rb") as ftbl, open(wpf_path, "rb") as fwpf:
        tbl_data = ftbl.read()
        num_entries = len(tbl_data) // 32
        for i in range(num_entries):
            entry = tbl_data[i*32 : (i+1)*32]
            name = entry[:24].decode("latin-1", errors="replace").rstrip("\x00").lstrip("\\/")
            if not name:
                name = f"subfile_{i:04d}.bin"
            size, offset = struct.unpack_from("<II", entry, 24)
            if size == 0:
                continue
            # Each record starts with a 32-byte inline copy of the TBL entry that
            # is NOT counted in `size`. Keep it (downstream tools strip raw[32:])
            # and read the full payload after it.
            fwpf.seek(offset)
            data = fwpf.read(size + INLINE_HEADER_SIZE)
            sub_path = os.path.join(out_dir, name)
            with open(sub_path, "wb") as out:
                out.write(data)
    return num_entries

def unpack_all(root_data_dir, output_assets_dir):
    print(f"Scanning for WPF/TBL pairs in {root_data_dir}...")
    count = 0
    total_files = 0
    for root, dirs, files in os.walk(root_data_dir):
        for f in files:
            if f.lower().endswith(".tbl"):
                tbl_path = os.path.join(root, f)
                base = os.path.splitext(f)[0]
                wpf_path = os.path.join(root, base + ".wpf")
                if not os.path.exists(wpf_path):
                    # check case insensitive
                    wpf_path = os.path.join(root, base + ".WPF")
                if os.path.exists(wpf_path):
                    rel = os.path.relpath(root, root_data_dir)
                    out_dir = os.path.join(output_assets_dir, rel, base)
                    extracted = unpack_wpf(tbl_path, wpf_path, out_dir)
                    count += 1
                    total_files += extracted
    print(f"Successfully unpacked {count} archives ({total_files} individual resource files) into {output_assets_dir}")

if __name__ == "__main__":
    data_dir = sys.argv[1] if len(sys.argv) > 1 else "extracted/root/data"
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "extracted/unpacked_wpf"
    unpack_all(data_dir, out_dir)
