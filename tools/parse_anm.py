#!/usr/bin/env python3
import struct
import sys

def parse_anm(path):
    with open(path, "rb") as f:
        data = f.read()[32:] # strip unpacker header
    
    ver, num_frames, header_sz, frame_rate, width, height = struct.unpack_from("<IIIIHH", data, 0)
    print(f"File: {path}")
    print(f"ANM Header: ver={ver}, frames={num_frames}, header_sz={header_sz}, rate={frame_rate}, resolution={width}x{height}")
    
    # Read frame descriptors starting at offset 32
    print("Frame descriptors:")
    for i in range(num_frames):
        off = 32 + i * 16
        start_off, size, tag = struct.unpack_from("<II8s", data, off)
        clean_tag = tag.decode("latin-1", errors="replace").rstrip("\x00")
        print(f"  Frame {i:02d}: offset=0x{start_off:06X}, size={size:6d} bytes, tag={clean_tag}")

if __name__ == "__main__":
    p = sys.argv[1] if len(sys.argv) > 1 else "extracted/unpacked_wpf/check/hy_anim/Hy_hanas_.anm"
    parse_anm(p)
