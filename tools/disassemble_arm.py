#!/usr/bin/env python3
import os
import subprocess
import sys

def disassemble(elf_path, asm_path):
    print(f"Disassembling {elf_path} into {asm_path}...")
    llvm_objdump = "/Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/llvm-objdump"
    if not os.path.exists(llvm_objdump):
        llvm_objdump = "objdump"
    
    cmd = [
        llvm_objdump,
        "-d",
        "--no-show-raw-insn",
        elf_path
    ]
    with open(asm_path, "w") as out:
        subprocess.run(cmd, stdout=out, check=True)
    
    lines = 0
    with open(asm_path, "r") as f:
        for _ in f:
            lines += 1
    print(f"Disassembly complete: {lines:,} assembly lines written to {asm_path}")

if __name__ == "__main__":
    elf = sys.argv[1] if len(sys.argv) > 1 else "extracted/binaries/arm9.elf"
    out = sys.argv[2] if len(sys.argv) > 2 else "extracted/binaries/arm9_disassembly.asm"
    disassemble(elf, out)
