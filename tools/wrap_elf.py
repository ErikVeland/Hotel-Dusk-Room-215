#!/usr/bin/env python3
import os
import struct
import sys

def create_arm_elf(bin_path, elf_path, load_addr, entry_addr):
    with open(bin_path, "rb") as f:
        code = f.read()

    code_size = len(code)
    # ELF32 Header (52 bytes) + 1 Program Header (32 bytes) = 84 bytes header
    e_ident = b"\x7fELF\x01\x01\x01\x00" + b"\x00" * 8
    # e_type=2 (EXEC), e_machine=40 (ARM), e_version=1, e_entry, e_phoff=52, e_flags=0x05000000 (EABI v5)
    ehdr = struct.pack(
        "<16sHHIIIIIHHHHHH",
        e_ident, 2, 40, 1, entry_addr, 52, 0, 0x05000000, 52, 32, 1, 0, 0, 0
    )
    # Elf32_Phdr: p_type=1 (LOAD), p_offset=84, p_vaddr, p_paddr, p_filesz, p_memsz, p_flags=7 (RWX), p_align=4
    phdr = struct.pack(
        "<IIIIIIII",
        1, 84, load_addr, load_addr, code_size, code_size, 7, 4
    )

    with open(elf_path, "wb") as f:
        f.write(ehdr)
        f.write(phdr)
        f.write(code)
    print(f"Generated {elf_path}: load=0x{load_addr:08X}, entry=0x{entry_addr:08X}, size={code_size} bytes")

def wrap_all(binaries_dir):
    arm9_bin = os.path.join(binaries_dir, "arm9.bin")
    arm7_bin = os.path.join(binaries_dir, "arm7.bin")
    
    if os.path.exists(arm9_bin):
        create_arm_elf(arm9_bin, os.path.join(binaries_dir, "arm9.elf"), 0x02004000, 0x02004800)
    if os.path.exists(arm7_bin):
        create_arm_elf(arm7_bin, os.path.join(binaries_dir, "arm7.elf"), 0x02380000, 0x02380000)

if __name__ == "__main__":
    bdir = sys.argv[1] if len(sys.argv) > 1 else "extracted/binaries"
    wrap_all(bdir)
