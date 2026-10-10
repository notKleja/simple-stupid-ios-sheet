#!/usr/bin/env python3
"""Stamp freshly rebuilt demo bundles with one clean source revision."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

try:
    from measurement.scripts.record_synchronized_demo import (
        ROOT,
        bundled_provenance_paths,
        bundled_timeline_paths,
        run,
        tracked_source_is_clean,
        verify_timeline_assets,
    )
except ModuleNotFoundError:  # Direct execution from measurement/scripts.
    from record_synchronized_demo import (  # type: ignore[no-redef]
        ROOT,
        bundled_provenance_paths,
        bundled_timeline_paths,
        run,
        tracked_source_is_clean,
        verify_timeline_assets,
    )


def build_payload(
    revision: str,
    timeline_sha256: str,
    *,
    source_tree_clean: bool,
) -> dict[str, object]:
    if not source_tree_clean:
        raise RuntimeError("demo provenance stamping requires clean committed source")
    if re.fullmatch(r"[0-9a-f]{40}", revision) is None:
        raise ValueError("git revision must be a full lowercase SHA-1")
    if re.fullmatch(r"[0-9a-f]{64}", timeline_sha256) is None:
        raise ValueError("timeline hash must be a lowercase SHA-256")
    return {
        "schema_version": 1,
        "git_revision": revision,
        "timeline_sha256": timeline_sha256,
    }


def write_payload(paths: dict[str, Path], payload: dict[str, object]) -> None:
    encoded = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    for path in paths.values():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(encoded)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-app", type=Path, required=True)
    parser.add_argument("--flutter-app", type=Path, required=True)
    parser.add_argument(
        "--timeline",
        type=Path,
        default=ROOT / "measurement/scenarios/synchronized_bilingual_demo.json",
    )
    args = parser.parse_args()
    if not args.native_app.is_dir() or not args.flutter_app.is_dir():
        raise RuntimeError("both freshly rebuilt .app bundles are required")
    timeline_sha256 = verify_timeline_assets(
        args.timeline,
        bundled_timeline_paths(args.native_app, args.flutter_app),
    )
    clean = tracked_source_is_clean()
    revision = run(["git", "rev-parse", "HEAD"]).stdout.strip()
    payload = build_payload(revision, timeline_sha256, source_tree_clean=clean)
    paths = bundled_provenance_paths(args.native_app, args.flutter_app)
    write_payload(paths, payload)
    print(
        json.dumps(
            {
                "revision": revision,
                "timeline_sha256": timeline_sha256,
                "paths": {name: str(path) for name, path in paths.items()},
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
