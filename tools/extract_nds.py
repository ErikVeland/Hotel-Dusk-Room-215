#!/usr/bin/env python3
import os
import struct
import sys

def parse_nds(rom_path, output_dir):
    print(f"Reading ROM: {rom_path}")
    with open(rom_path, "rb") as f:
        header = f.read(0x200)

        title = header[0:12].decode("latin-1", errors="replace").rstrip("\x00")
        gamecode = header[12:16].decode("latin-1", errors="replace")
        maker = header[16:18].decode("latin-1", errors="replace")

        arm9_offset, arm9_entry, arm9_ram, arm9_size = struct.unpack_from("<IIII", header, 0x20)
        arm7_offset, arm7_entry, arm7_ram, arm7_size = struct.unpack_from("<IIII", header, 0x30)
        fnt_offset, fnt_size = struct.unpack_from("<II", header, 0x40)
        fat_offset, fat_size = struct.unpack_from("<II", header, 0x48)
        arm9_ovl_offset, arm9_ovl_size = struct.unpack_from("<II", header, 0x50)
        arm7_ovl_offset, arm7_ovl_size = struct.unpack_from("<II", header, 0x58)
        banner_offset = struct.unpack_from("<I", header, 0x68)[0]
        rom_size = struct.unpack_from("<I", header, 0x80)[0]

        print(f"Game: {title} ({gamecode})")
        print(f"ARM9 code size: {arm9_size} bytes (RAM entry: 0x{arm9_entry:08X})")
        print(f"ARM7 code size: {arm7_size} bytes (RAM entry: 0x{arm7_entry:08X})")

        os.makedirs(output_dir, exist_ok=True)
        bin_dir = os.path.join(output_dir, "binaries")
        os.makedirs(bin_dir, exist_ok=True)

        # 1. Extract ARM9
        f.seek(arm9_offset)
        arm9_data = f.read(arm9_size)
        with open(os.path.join(bin_dir, "arm9.bin"), "wb") as out:
            out.write(arm9_data)

        # 2. Extract ARM7
        f.seek(arm7_offset)
        arm7_data = f.read(arm7_size)
        with open(os.path.join(bin_dir, "arm7.bin"), "wb") as out:
            out.write(arm7_data)

        # 3. Extract Overlays
        num_arm9_ovl = arm9_ovl_size // 32
        if num_arm9_ovl > 0:
            ovl_dir = os.path.join(bin_dir, "overlays")
            os.makedirs(ovl_dir, exist_ok=True)
            f.seek(arm9_ovl_offset)
            ovl_table = f.read(arm9_ovl_size)
            print(f"Extracting {num_arm9_ovl} ARM9 overlays...")
            
            # Read FAT for overlay files
            f.seek(fat_offset)
            fat_bytes = f.read(fat_size)
            fat = [struct.unpack_from("<II", fat_bytes, i * 8) for i in range(fat_size // 8)]

            for i in range(num_arm9_ovl):
                ovl_id, ram_addr, ram_sz, bss_sz, sinit_init, sinit_end, file_id, flags = struct.unpack_from("<IIIIIIII", ovl_table, i * 32)
                if file_id < len(fat):
                    start, end = fat[file_id]
                    f.seek(start)
                    odata = f.read(end - start)
                    with open(os.path.join(ovl_dir, f"overlay_{ovl_id:04d}.bin"), "wb") as out:
                        out.write(odata)

        # 4. Extract Banner
        if banner_offset > 0:
            f.seek(banner_offset)
            banner_data = f.read(0x840)  # Standard NDS banner size
            with open(os.path.join(output_dir, "banner.bin"), "wb") as out:
                out.write(banner_data)

        # 5. Extract NitroFS
        print("Extracting NitroFS file system...")
        f.seek(fat_offset)
        fat_bytes = f.read(fat_size)
        fat = [struct.unpack_from("<II", fat_bytes, i * 8) for i in range(fat_size // 8)]

        f.seek(fnt_offset)
        fnt_bytes = f.read(fnt_size)

        root_offset, root_first_file, total_dirs = struct.unpack_from("<IHH", fnt_bytes, 0)
        dir_table = [struct.unpack_from("<IHH", fnt_bytes, d * 8) for d in range(total_dirs)]

        dirs = {0xF000: {"name": "", "parent": 0xF000, "first_fid": root_first_file}}
        dir_files = {}

        for d in range(total_dirs):
            dir_id = 0xF000 + d
            off, first_fid, parent = dir_table[d]
            pos = off
            cur_fid = first_fid
            dir_files[dir_id] = []
            
            while pos < len(fnt_bytes):
                b = fnt_bytes[pos]
                pos += 1
                if b == 0:
                    break
                is_dir = (b & 0x80) != 0
                name_len = b & 0x7F
                name = fnt_bytes[pos:pos+name_len].decode("latin-1")
                pos += name_len
                if is_dir:
                    sub_id = struct.unpack_from("<H", fnt_bytes, pos)[0]
                    pos += 2
                    dirs[sub_id] = {"name": name, "parent": dir_id}
                else:
                    dir_files[dir_id].append((cur_fid, name))
                    cur_fid += 1

        def build_path(did):
            if did == 0xF000:
                return ""
            parent = dirs[did]["parent"]
            parent_path = build_path(parent)
            return os.path.join(parent_path, dirs[did]["name"])

        fs_root = os.path.join(output_dir, "root")
        os.makedirs(fs_root, exist_ok=True)
        total_extracted = 0

        for did, files in dir_files.items():
            rel_dir = build_path(did)
            target_dir = os.path.join(fs_root, rel_dir)
            os.makedirs(target_dir, exist_ok=True)
            for fid, fname in files:
                if fid < len(fat):
                    start, end = fat[fid]
                    f.seek(start)
                    data = f.read(end - start)
                    with open(os.path.join(target_dir, fname), "wb") as out:
                        out.write(data)
                    total_extracted += 1

        print(f"Extracted {total_extracted} files from NitroFS into {fs_root}")
        print("ROM extraction complete!")

if __name__ == "__main__":
    rom = sys.argv[1] if len(sys.argv) > 1 else "Source/ROM/Hotel Dusk - Room 215.nds"
    out = sys.argv[2] if len(sys.argv) > 2 else "extracted"
    parse_nds(rom, out)
