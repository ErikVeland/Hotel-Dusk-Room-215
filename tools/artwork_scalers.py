"""Model routing for the offline artwork upscaler."""

from __future__ import annotations


MODEL_BY_CATEGORY = {
    "animation": "4x-Manga109Attempt.pth",
    "bitmap": "4x-Manga109Attempt.pth",
    "cinematic": "4x-Nomos8kSC.pth",
    "linear": "4x-Manga109Attempt.pth",
    "map": "4x-Manga109Attempt.pth",
    "png": "4x-Nomos8kSC.pth",
    "texture": "HDCube3.pth",
}
ANIMATION_FINISH_MODEL = "2xHDCube_Compact.pth"


def model_pipeline(category, override="mixed"):
    """Return the ordered model names used for one artwork category."""
    if category not in MODEL_BY_CATEGORY:
        raise ValueError(f"No artwork scaler is configured for category: {category!r}")
    base_model = MODEL_BY_CATEGORY[category] if override == "mixed" else override
    if category == "animation":
        return base_model, ANIMATION_FINISH_MODEL
    return (base_model,)


def routing_settings(override="mixed"):
    """Return the model choices recorded with an artwork pack."""
    models = {
        category: model_pipeline(category, override)[0]
        for category in sorted(MODEL_BY_CATEGORY)
    }
    return {"byCategory": models, "animationFinish": ANIMATION_FINISH_MODEL}
