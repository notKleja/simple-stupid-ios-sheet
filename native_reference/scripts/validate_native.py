#!/usr/bin/env python3
"""Integrity gate for the accepted native evidence manifest, not a parity test."""
import gzip
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
manifest = json.loads((ROOT / "native_reference/measurements.json").read_text())
total = 0
gaps = 0
for profile in manifest["profiles"]:
    assert profile["trace_count"] == 10
    for artifact in profile["artifacts"]:
        path = ROOT / artifact["path"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == artifact["sha256"], path
        with gzip.open(path, "rt") as f:
            rows = [json.loads(line) for line in f]
        assert rows[0]["type"] == "session"
        assert rows[0]["implementation"] == "native" and rows[0]["evidence_kind"] == "runtime"
        assert rows[0]["os"]["build"] in {"23E254a", "23G90", "24A434"}
        assert rows[0]["device"]["runtime_kind"] in {"simulator", "virtual_device"}
        assert any(r.get("name") == "dismiss.completed" for r in rows)
        seq = -1
        timestamp = -1
        for row in rows:
            assert row["schema_version"] == 1 and row["run_id"] == rows[0]["run_id"]
            assert type(row["seq"]) is int and row["seq"] > seq
            assert type(row["t_ns"]) is int and row["t_ns"] >= timestamp
            seq, timestamp = row["seq"], row["t_ns"]
            if row["type"] == "frame":
                assert isinstance(row["state"], dict)
                assert all(v is None or isinstance(v, (int, float)) and math.isfinite(v) for v in row["metrics"].values())
                if row["metrics"].get("sheet.y") is None:
                    assert row.get("unavailable")
                    gaps += 1
        total += 1
print(json.dumps({"accepted_trace_files": total, "profiles": len(manifest["profiles"]), "explicit_geometry_gaps": gaps,
                  "integrity": "PASS", "full_geometry_parity": "unresolved"}))
