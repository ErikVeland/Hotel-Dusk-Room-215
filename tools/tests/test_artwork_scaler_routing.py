import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from artwork_scalers import model_pipeline, routing_settings


class ArtworkScalerRoutingTests(unittest.TestCase):
    def test_routes_by_artwork_type(self):
        self.assertEqual(model_pipeline("texture"), ("HDCube3.pth",))
        self.assertEqual(model_pipeline("map"), ("4x-Manga109Attempt.pth",))
        self.assertEqual(model_pipeline("linear"), ("4x-Manga109Attempt.pth",))
        self.assertEqual(model_pipeline("bitmap"), ("4x-Manga109Attempt.pth",))
        self.assertEqual(model_pipeline("cinematic"), ("4x-Nomos8kSC.pth",))
        self.assertEqual(model_pipeline("png"), ("4x-Nomos8kSC.pth",))

    def test_animation_uses_line_art_model_then_finisher(self):
        self.assertEqual(
            model_pipeline("animation"),
            ("4x-Manga109Attempt.pth", "2xHDCube_Compact.pth"),
        )

    def test_explicit_model_override_keeps_animation_finisher(self):
        self.assertEqual(
            model_pipeline("animation", "custom.pth"),
            ("custom.pth", "2xHDCube_Compact.pth"),
        )
        self.assertEqual(model_pipeline("texture", "custom.pth"), ("custom.pth",))

    def test_unknown_category_fails_clearly(self):
        with self.assertRaisesRegex(ValueError, "unknown"):
            model_pipeline("unknown")

    def test_settings_capture_category_routes_and_animation_finish(self):
        settings = routing_settings()
        self.assertEqual(settings["byCategory"]["texture"], "HDCube3.pth")
        self.assertEqual(settings["animationFinish"], "2xHDCube_Compact.pth")


if __name__ == "__main__":
    unittest.main()
