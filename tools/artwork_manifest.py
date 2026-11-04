"""Shared filename checks for artwork manifests."""
from pathlib import Path
import re


def valid_artwork_filename(record):
    key, filename = record.get('key'), record.get('file')
    if not isinstance(key, str) or not isinstance(filename, str) or Path(filename).name != filename:
        return False
    if filename in (key + '.png', key + '.webp'):
        return True
    width, height = record.get('width'), record.get('height')
    if not all(type(value) is int and value > 0 for value in (width, height)):
        return False
    return re.fullmatch(rf'{width}x{height}-[0-9a-f]{{64}}\.(?:png|webp)', filename) is not None
