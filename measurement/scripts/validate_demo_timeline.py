#!/usr/bin/env python3
"""Validate the shared native/Flutter synchronized demo timeline."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


class TimelineError(ValueError):
    pass


KINDS = {"intro", "page", "custom", "scroll", "properties", "components", "outro"}
ACTIONS = {"present", "select", "scroll", "background_pulse", "toggle", "dismiss_attempt", "dismiss"}
LANGUAGES = {"en", "ar"}


def _integer(value: Any, label: str, *, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        raise TimelineError(f"{label} must be an integer >= {minimum}")
    return value


def validate_timeline(value: dict[str, Any]) -> dict[str, Any]:
    if value.get("schema_version") != 1:
        raise TimelineError("schema_version must equal 1")
    duration = _integer(value.get("duration_ms"), "duration_ms", minimum=1)
    scenes = value.get("scenes")
    if not isinstance(scenes, list) or not scenes:
        raise TimelineError("scenes must be a nonempty array")

    seen_ids: set[str] = set()
    seen_languages: set[str] = set()
    prior_end = 0
    for index, scene in enumerate(scenes):
        if not isinstance(scene, dict):
            raise TimelineError(f"scene {index} must be an object")
        scene_id = scene.get("id")
        if not isinstance(scene_id, str) or not scene_id or scene_id in seen_ids:
            raise TimelineError(f"scene {index} requires a unique nonempty id")
        seen_ids.add(scene_id)
        language = scene.get("language")
        if language not in LANGUAGES:
            raise TimelineError(f"scene {scene_id} has unknown language")
        seen_languages.add(language)
        direction = scene.get("direction")
        if direction not in {"ltr", "rtl"}:
            raise TimelineError(f"scene {scene_id} has invalid direction")
        if language == "ar" and direction != "rtl":
            raise TimelineError("Arabic scenes must be rtl")
        if language == "en" and direction != "ltr":
            raise TimelineError("English scenes must be ltr")
        kind = scene.get("kind")
        if kind not in KINDS:
            raise TimelineError(f"scene {scene_id} has unknown kind {kind!r}")
        if not isinstance(scene.get("title"), str) or not isinstance(scene.get("subtitle"), str):
            raise TimelineError(f"scene {scene_id} needs localized title and subtitle")
        start = _integer(scene.get("start_ms"), f"scene {scene_id} start_ms")
        scene_duration = _integer(scene.get("duration_ms"), f"scene {scene_id} duration_ms", minimum=1)
        if start < prior_end:
            raise TimelineError(f"scene {scene_id} overlap: starts {start} before {prior_end}")
        if start + scene_duration > duration:
            raise TimelineError(f"scene {scene_id} extends beyond duration_ms")
        prior_end = start + scene_duration

        actions = scene.get("actions")
        if not isinstance(actions, list):
            raise TimelineError(f"scene {scene_id} actions must be an array")
        prior_action = -1
        for action_index, action in enumerate(actions):
            if not isinstance(action, dict):
                raise TimelineError(f"scene {scene_id} action {action_index} must be an object")
            at = _integer(action.get("at_ms"), f"scene {scene_id} action at_ms")
            if at <= prior_action:
                raise TimelineError(f"scene {scene_id} actions must be strictly increasing")
            if at >= scene_duration:
                raise TimelineError(f"scene {scene_id} action must occur inside its scene")
            prior_action = at
            action_type = action.get("type")
            if action_type not in ACTIONS:
                raise TimelineError(f"scene {scene_id} has unknown action {action_type!r}")
            if action_type in {"present", "select"} and not isinstance(action.get("detent"), str):
                raise TimelineError(f"scene {scene_id} {action_type} requires detent")

    if seen_languages != LANGUAGES:
        raise TimelineError("timeline must include English and Arabic scenes")
    if prior_end != duration:
        raise TimelineError("final scene must end at duration_ms")
    return {
        "scene_count": len(scenes),
        "languages": sorted(seen_languages),
        "duration_ms": duration,
        "scene_ids": [scene["id"] for scene in scenes],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    value = json.loads(args.path.read_text())
    print(json.dumps(validate_timeline(value), indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

