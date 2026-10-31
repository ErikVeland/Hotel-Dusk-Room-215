import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from chapter_one_art import selected_clips


class ChapterOneArtSelectionTests(unittest.TestCase):
    def test_shared_system_dialogue_clips_are_included(self):
        clips = selected_clips()
        self.assertIn('hy_tech1_', clips)
        self.assertIn('ro_tere_', clips)


if __name__ == '__main__':
    unittest.main()
