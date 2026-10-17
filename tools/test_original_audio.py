#!/usr/bin/env python3
"""Source audio checks that do not require an Apple audio device."""
from pathlib import Path
import struct
import tempfile
import unittest
from audit_sseq import trace_sequence
from extract_sdat import extract
from prepare_original_audio import decode_adpcm


class OriginalAudioRecoveryTests(unittest.TestCase):
    def test_ima_nibbles_and_ds_negative_saturation(self):
        self.assertEqual(struct.unpack("<2h", decode_adpcm(bytes.fromhex("00000000f0"))), (0, -11))
        encoded = struct.pack("<hH", -32760, 88) + b"\xff"
        self.assertEqual(struct.unpack("<2h", decode_adpcm(encoded)), (-32767, -32767))

    def test_sequence_subroutine_and_nonzero_intro_loop(self):
        data = bytes([0x80, 4, 0x95, 10, 0, 0, 0x94, 2, 0, 0, 60, 100, 8, 0xFD])
        tracks, _ = trace_sequence(data)
        self.assertEqual(tracks[0]["notes"], [[4, 60, 100, 8]])
        self.assertEqual(tracks[0]["loop"]["startTick"], 4)
        self.assertEqual(tracks[0]["loop"]["endTick"], 12)

    def test_unknown_sequence_commands_fail(self):
        with self.assertRaises(ValueError):
            trace_sequence(bytes([0xA0, 0, 0, 0, 0]))

    def test_all_raw_files_and_original_links_are_recovered(self):
        source = Path("extracted/root/data/sound_data.sdat")
        with tempfile.TemporaryDirectory() as destination:
            inventory = extract(source, Path(destination))
            self.assertEqual(len(inventory["files"]), 340)
            self.assertEqual(inventory["counts"]["archiveSequences"], 186)
            self.assertEqual(inventory["counts"]["waveSamples"], 291)
            whole = source.read_bytes()
            for entry in inventory["files"]:
                self.assertEqual((Path(destination) / entry["path"]).read_bytes(),
                                 whole[entry["offset"]:entry["offset"] + entry["length"]])


if __name__ == "__main__":
    unittest.main()
