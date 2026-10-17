"""Regression fixtures from the supplied ROM and malformed-container checks."""
from pathlib import Path
import hashlib
import struct
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from cing_container import decode_member, decompress
from recover_original_logic import decompress_code, parse_blocks, parse_checks, parse_text


class OriginalRecoveryTests(unittest.TestCase):
    def member(self, name):
        path = ROOT / 'extracted/unpacked_wpf/local/us/textdata_usa' / name
        return decode_member(path.read_bytes())

    def test_initial_dictionary_does_not_read_future_output(self):
        # This original member exposed the old decoder's two-byte corruption.
        data = self.member('EP1_R102.blk')
        self.assertEqual(hashlib.sha256(data).hexdigest(),
                         '54c44a59bb73ff6aa1abea4b49947697cc521621e3a412ced8d0ec932b981e26')
        self.assertEqual(struct.unpack_from('<I', data, 16)[0], 544)
        tables = parse_blocks(data)['tables']
        self.assertEqual([t['count'] for t in tables], [12, 20, 90, 902])

    def test_dictionary_wraps_multiple_times(self):
        for name, expected in [
            ('EP1_R205.txt', '8b88eed23c968e85c61de32e284074a826a77bb69cec13c020ceec28ff023174'),
            ('System.txt', 'd21bb9b5496be60715c24ac6b3615af82853522cfa92b0b28c0f67329b9e8ed5')]:
            with self.subTest(name=name):
                data = self.member(name)
                self.assertEqual(hashlib.sha256(data).hexdigest(), expected)
                self.assertGreater(len(data), 65536)
                parse_text(data)

    def test_original_control_codes_and_empty_strings_survive(self):
        text = parse_text(self.member('EP3_R209.txt'))
        self.assertEqual(text['count'], 578)
        self.assertEqual(text['dataOffset'], 2316)
        self.assertEqual(text['records'][0]['rawText'], '%c0%d1%w1%p0000102%n0%s1012010')
        self.assertEqual(text['records'][1]['rawText'], '')

    def test_malformed_container_is_rejected(self):
        for data in [b'', bytes.fromhex('123dda01') + struct.pack('<3I', 4, 2, 0) + b'\x00\x00',
                     bytes.fromhex('123dda00') + struct.pack('<3I', 2, 0xFFFFFFFF, 0) + b'x']:
            with self.subTest(data=data), self.assertRaises(ValueError):
                decompress(data)

    def test_check_offsets_resolve_from_payload_start(self):
        block = parse_blocks(self.member('EP1_R213.blk'))
        checks = parse_checks(self.member('EP1_R213.chk'), block['tables'][2]['count'])
        records = [record for entry in checks['entries'] if entry['driveConditions']
                   for record in entry['driveConditions']['records']]
        door = next(record for record in records if record['byteOffset'] == 2096)
        self.assertEqual(door['hex'], '06ff01ff2000ffffffffffffffffffff')
        self.assertEqual(door['signedKind'], 6)
        self.assertEqual(door['u16'][2], 32)

    def test_check_span_cannot_point_into_header(self):
        data = struct.pack('<4I', 0, 1, 0xFFFFFFFF, 0xFFFFFFFF)
        with self.assertRaises(ValueError):
            parse_checks(data, 1)

    def test_arm9_code_is_decompressed_before_disassembly(self):
        source = (ROOT / 'extracted/binaries/arm9.bin').read_bytes()
        decoded = decompress_code(source)
        self.assertEqual(len(decoded), 1031352)
        self.assertEqual(hashlib.sha256(decoded).hexdigest(),
                         'b9b7f7e4ddedcb245f7df0d9a953e3fbf5a15cc88436e03b8b3b65cfe872e809')
        self.assertEqual(struct.unpack_from('<I', decoded, 0x0203BEB4 - 0x02004000)[0], 0xE3570035)


if __name__ == '__main__':
    unittest.main()
