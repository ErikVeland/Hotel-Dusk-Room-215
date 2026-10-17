#!/usr/bin/env python3
import os
from collections import Counter

def inspect():
    exts = Counter()
    sizes = Counter()
    sample_files = {}

    for root, dirs, files in os.walk("extracted/root/data"):
        for f in files:
            path = os.path.join(root, f)
            ext = os.path.splitext(f)[1].lower()
            if not ext:
                ext = "(no extension)"
            exts[ext] += 1
            sz = os.path.getsize(path)
            sizes[ext] += sz
            if ext not in sample_files:
                sample_files[ext] = []
            if len(sample_files[ext]) < 3:
                sample_files[ext].append(os.path.relpath(path, "extracted/root/data"))

    print(f"{'Extension':<16} {'Count':<8} {'Total Size (MB)':<16} Sample Files")
    print("-" * 80)
    for ext, count in exts.most_common():
        sz_mb = sizes[ext] / (1024 * 1024)
        samples = ", ".join(sample_files[ext][:2])
        print(f"{ext:<16} {count:<8} {sz_mb:<16.2f} {samples}")

if __name__ == "__main__":
    inspect()
