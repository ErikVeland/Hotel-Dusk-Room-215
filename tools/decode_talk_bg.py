#!/usr/bin/env python3
import glob
import os
import struct
import zlib

def write_png(width, height, rgba_data, out_path):
    raw_scanlines = bytearray()
    for y in range(height):
        raw_scanlines.append(0)
        start = y * width * 4
        raw_scanlines.extend(rgba_data[start : start + width * 4])
    
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw_scanlines), 6)
    
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", idat))
        f.write(chunk(b"IEND", b""))

def decode_talk_bgs(src_dir, dest_dir):
    os.makedirs(dest_dir, exist_ok=True)
    bin_files = sorted(glob.glob(os.path.join(src_dir, "*.bin")))
    decoded_count = 0

    for path in bin_files:
        try:
            with open(path, "rb") as f:
                raw = f.read()
            if len(raw) < 544:
                continue
            data = raw[32:] # strip unpacker header
            if len(data) < 544:
                continue
            
            w1, h1 = struct.unpack_from("<HH", data, 16)
            if w1 <= 0 or h1 <= 0 or w1 > 512 or h1 > 512:
                # default fallback
                w1, h1 = 128, 96
            
            pal_offset = 32
            pal_data = data[pal_offset : pal_offset + 512]
            palette = []
            for i in range(256):
                b16 = struct.unpack_from("<H", pal_data, i * 2)[0]
                r = (b16 & 0x1F) << 3
                g = ((b16 >> 5) & 0x1F) << 3
                b = ((b16 >> 10) & 0x1F) << 3
                a = 255
                palette.append((r, g, b, a))
            
            pixel_offset = 544
            pixel_size = w1 * h1
            if len(data) < pixel_offset + pixel_size:
                continue
            
            pixels = data[pixel_offset : pixel_offset + pixel_size]

            # The DS is held sideways (book mode), so Cing stores every
            # background rotated 90° clockwise. Rotate 90° counter-clockwise
            # to write an upright portrait image: (x, y) -> (y, w1 - 1 - x).
            out_w, out_h = h1, w1
            rgba = bytearray(out_w * out_h * 4)
            for y in range(h1):
                row = y * w1
                for x in range(w1):
                    i = ((w1 - 1 - x) * out_w + y) * 4
                    rgba[i : i + 4] = bytes(palette[pixels[row + x]])

            base = os.path.splitext(os.path.basename(path))[0]
            out_file = os.path.join(dest_dir, f"{base}.png")
            write_png(out_w, out_h, rgba, out_file)
            decoded_count += 1
        except Exception:
            continue
    
    print(f"Decoded {decoded_count} backgrounds into {dest_dir}")

if __name__ == "__main__":
    src = "extracted/unpacked_wpf/check/TalkBG"
    dst = "Sources/HotelDuskDuoKit/Resources/Images/Backgrounds"
    decode_talk_bgs(src, dst)
