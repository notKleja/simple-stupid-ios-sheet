#!/usr/bin/env python3
"""Record native and Flutter sheet demos on two synchronized simulators."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import signal
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from measurement.scripts.validate_demo_timeline import validate_timeline


DEVICE_TYPE = "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
NATIVE_BUNDLE = "dev.notkleja.NativeSheetHarness"
FLUTTER_BUNDLE = "dev.sheetreference.iosSheetCandidate"


def run(command: list[str], *, env: dict[str, str] | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, check=check, text=True, capture_output=True, env=env)


def run_json(command: list[str]) -> dict[str, Any]:
    return json.loads(run(command).stdout)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def find_runtime(inventory: dict[str, Any], version: str) -> dict[str, Any]:
    for runtime in inventory.get("runtimes", []):
        if runtime.get("version") == version and runtime.get("isAvailable") is True:
            return runtime
    raise RuntimeError(f"No exact available runtime for iOS {version}")


def bundled_timeline_paths(native_app: Path, flutter_app: Path) -> dict[str, Path]:
    return {
        "native": native_app / "synchronized_bilingual_demo.json",
        "flutter": flutter_app / "Frameworks/App.framework/flutter_assets/assets/synchronized_bilingual_demo.json",
    }


def verify_timeline_assets(selected: Path, bundled: dict[str, Path]) -> str:
    expected = sha256_file(selected)
    for implementation, path in bundled.items():
        if not path.is_file() or sha256_file(path) != expected:
            raise RuntimeError(f"{implementation} bundled timeline does not match selected timeline")
    return expected


def validate_simulator_identity(
    inventory: dict[str, Any], udids: list[str], runtime_id: str
) -> list[dict[str, Any]]:
    devices = {device.get("udid"): device for device in inventory.get("devices", {}).get(runtime_id, [])}
    resolved = []
    for udid in udids:
        device = devices.get(udid)
        if not device:
            raise RuntimeError(f"Simulator {udid} is not in requested runtime {runtime_id}")
        if device.get("isAvailable") is not True or device.get("deviceTypeIdentifier") != DEVICE_TYPE:
            raise RuntimeError(f"Simulator {udid} is not an available iPhone 17 Pro")
        resolved.append(device)
    return resolved


def validate_ack(value: dict[str, Any], status: str, expected: dict[str, Any]) -> None:
    if value.get("status") != status or any(value.get(key) != wanted for key, wanted in expected.items()):
        raise RuntimeError(f"Invalid {status} acknowledgement: {value!r}")


def app_documents(udid: str, bundle: str) -> Path:
    container = Path(run(["xcrun", "simctl", "get_app_container", udid, bundle, "data"]).stdout.strip())
    return container / "Documents"


def clear_acknowledgements(directory: Path) -> None:
    for name in ("synchronized-demo-armed.json", "synchronized-demo-completed.json"):
        (directory / name).unlink(missing_ok=True)


def wait_for_ack(directory: Path, name: str, status: str, expected: dict[str, Any], deadline: float) -> tuple[Path, dict[str, Any]]:
    path = directory / name
    while time.time() < deadline:
        if path.is_file():
            try:
                value = json.loads(path.read_text())
                validate_ack(value, status, expected)
                return path, value
            except (json.JSONDecodeError, OSError):
                pass
        time.sleep(0.05)
    raise RuntimeError(f"Missing valid {status} acknowledgement before deadline: {path}")


def compose_filter() -> str:
    return (
        "[0:v]setpts=PTS-STARTPTS[native];"
        "[1:v]setpts=PTS-STARTPTS[flutter];"
        "[native][flutter]hstack=inputs=2[out]"
    )


def probe_media(path: Path) -> dict[str, Any]:
    result = run_json([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=codec_name,width,height,avg_frame_rate,nb_frames:format=duration,size",
        "-of", "json", str(path),
    ])
    return {"stream": result.get("streams", [{}])[0], "format": result.get("format", {})}


def build_manifest(
    *,
    run_id: str,
    start_epoch_ms: int,
    recorder_started_ns: dict[str, int],
    simulators: dict[str, dict[str, Any]],
    runtime: dict[str, Any],
    timeline: Path,
    outputs: dict[str, Path],
    media: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "run_id": run_id,
        "start_epoch_ms": start_epoch_ms,
        "recording_start_monotonic_ns": recorder_started_ns,
        "recording_start_delta_ns": abs(recorder_started_ns["native"] - recorder_started_ns["flutter"]),
        "device_type": DEVICE_TYPE,
        "runtime": {key: runtime.get(key) for key in ("identifier", "version", "buildversion")},
        "simulators": simulators,
        "timeline": {"path": str(timeline), "sha256": sha256_file(timeline)},
        "outputs": {
            name: {"path": str(path), "sha256": sha256_file(path), "media": media[name]}
            for name, path in outputs.items()
        },
        "evidence_boundary": [
            "Video demonstrates synchronized visible scenarios; numerical parity remains trace-analyzer work.",
            "Programmatic scrolling is not finger-driven scroll-handoff proof.",
            "Property labels do not by themselves prove native hit testing.",
        ],
    }


def simulator_create_command(name: str, runtime_id: str, clone_source: str | None) -> list[str]:
    if clone_source:
        return ["xcrun", "simctl", "clone", clone_source, name]
    return ["xcrun", "simctl", "create", name, DEVICE_TYPE, runtime_id]


def explicit_simulators(native_udid: str | None, flutter_udid: str | None) -> tuple[str, str] | None:
    if native_udid is None and flutter_udid is None:
        return None
    if not native_udid or not flutter_udid:
        raise ValueError("both --native-udid and --flutter-udid are required together")
    if native_udid == flutter_udid:
        raise ValueError("native and Flutter must use two different simulators")
    return native_udid, flutter_udid


def create_simulator(name: str, runtime_id: str, clone_source: str | None = None) -> str:
    return run(simulator_create_command(name, runtime_id, clone_source)).stdout.strip()


def boot_and_install(udid: str, app: Path) -> None:
    run(["xcrun", "simctl", "boot", udid], check=False)
    run(["xcrun", "simctl", "bootstatus", udid, "-b"])
    run(["xcrun", "simctl", "ui", udid, "appearance", "light"])
    run(["xcrun", "simctl", "ui", udid, "increase_contrast", "disabled"])
    run(["xcrun", "simctl", "ui", udid, "content_size", "large"])
    run(["xcrun", "simctl", "install", udid, str(app)])


def start_recording(udid: str, path: Path) -> tuple[subprocess.Popen[str], int]:
    started = time.monotonic_ns()
    process = subprocess.Popen(
        ["xcrun", "simctl", "io", udid, "recordVideo", "--codec=h264", "--force", str(path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return process, started


def stop_recording(process: subprocess.Popen[str]) -> None:
    if process.poll() is None:
        process.send_signal(signal.SIGINT)
    try:
        process.communicate(timeout=15)
    except subprocess.TimeoutExpired:
        process.kill()
        process.communicate(timeout=5)


def launch_command(udid: str, bundle: str) -> list[str]:
    return ["xcrun", "simctl", "launch", "--terminate-running-process", udid, bundle]


def launch(udid: str, bundle: str, start_epoch_ms: int, build: str) -> dict[str, Any]:
    env = os.environ.copy()
    env.update({
        "SIMCTL_CHILD_SHEET_DEMO": "1",
        "SIMCTL_CHILD_SHEET_DEMO_START_MS": str(start_epoch_ms),
        "SIMCTL_CHILD_NATIVE_OS_BUILD": build,
        "SIMCTL_CHILD_SHEET_OS_BUILD": build,
    })
    started = time.monotonic_ns()
    result = run(launch_command(udid, bundle), env=env)
    return {"started_monotonic_ns": started, "output": result.stdout.strip()}


def compose(native: Path, flutter: Path, output: Path) -> None:
    run([
        "ffmpeg", "-y", "-i", str(native), "-i", str(flutter),
        "-filter_complex", compose_filter(), "-map", "[out]", "-an",
        "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", str(output),
    ])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--native-app", type=Path, required=True)
    parser.add_argument("--flutter-app", type=Path, required=True)
    parser.add_argument("--timeline", type=Path, default=ROOT / "measurement/scenarios/synchronized_bilingual_demo.json")
    parser.add_argument("--runtime-version", default="26.4.1")
    parser.add_argument("--clone-source", help="Ready, shutdown simulator UDID to clone twice")
    parser.add_argument("--native-udid", help="Existing initialized iPhone 17 Pro for native")
    parser.add_argument("--flutter-udid", help="Existing initialized iPhone 17 Pro for Flutter")
    parser.add_argument("--output-root", type=Path, default=ROOT / "artifacts/video")
    args = parser.parse_args()

    if not args.native_app.is_dir() or not args.flutter_app.is_dir():
        raise RuntimeError("Both built .app bundles are required")
    timeline_value = json.loads(args.timeline.read_text())
    timeline_summary = validate_timeline(timeline_value)
    runtime = find_runtime(run_json(["xcrun", "simctl", "list", "runtimes", "-j"]), args.runtime_version)
    timeline_asset_hash = verify_timeline_assets(args.timeline, bundled_timeline_paths(args.native_app, args.flutter_app))
    run_id = time.strftime("%Y%m%d-%H%M%S")
    output_dir = args.output_root / run_id
    output_dir.mkdir(parents=True, exist_ok=False)
    native_video = output_dir / "native-iphone17pro.mp4"
    flutter_video = output_dir / "flutter-iphone17pro.mp4"
    composite_video = output_dir / "native-vs-flutter-iphone17pro-bilingual.mp4"

    supplied = explicit_simulators(args.native_udid, args.flutter_udid)
    if supplied:
        native_udid, flutter_udid = supplied
        native_name, flutter_name = "Existing iPhone 17 Pro — Native", "Existing iPhone 17 Pro — Flutter"
    else:
        native_name, flutter_name = f"Sheet Native 17 Pro {run_id}", f"Sheet Flutter 17 Pro {run_id}"
        native_udid = create_simulator(native_name, runtime["identifier"], args.clone_source)
        flutter_udid = create_simulator(flutter_name, runtime["identifier"], args.clone_source)
    device_records = validate_simulator_identity(
        run_json(["xcrun", "simctl", "list", "devices", "-j"]),
        [native_udid, flutter_udid],
        runtime["identifier"],
    )
    simulators = {
        "native": {"udid": native_udid, "name": native_name, "bundle": NATIVE_BUNDLE, "device": device_records[0]},
        "flutter": {"udid": flutter_udid, "name": flutter_name, "bundle": FLUTTER_BUNDLE, "device": device_records[1]},
    }

    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = [executor.submit(boot_and_install, native_udid, args.native_app), executor.submit(boot_and_install, flutter_udid, args.flutter_app)]
        for future in futures:
            future.result()

    document_dirs = {
        "native": app_documents(native_udid, NATIVE_BUNDLE),
        "flutter": app_documents(flutter_udid, FLUTTER_BUNDLE),
    }
    for directory in document_dirs.values():
        clear_acknowledgements(directory)

    native_recorder, native_started = start_recording(native_udid, native_video)
    flutter_recorder, flutter_started = start_recording(flutter_udid, flutter_video)
    start_epoch_ms = int(time.time() * 1000) + 12000
    launch_results: dict[str, Any] = {}
    acknowledgements: dict[str, Any] = {}
    try:
        with ThreadPoolExecutor(max_workers=2) as executor:
            launches = {
                "native": executor.submit(launch, native_udid, NATIVE_BUNDLE, start_epoch_ms, runtime["buildversion"]),
                "flutter": executor.submit(launch, flutter_udid, FLUTTER_BUNDLE, start_epoch_ms, runtime["buildversion"]),
            }
            launch_results = {name: future.result() for name, future in launches.items()}
        armed_expected = {
            "start_epoch_ms": start_epoch_ms,
            "duration_ms": timeline_summary["duration_ms"],
            "scene_count": timeline_summary["scene_count"],
        }
        armed_deadline = start_epoch_ms / 1000 - 1
        for implementation, directory in document_dirs.items():
            path, value = wait_for_ack(directory, "synchronized-demo-armed.json", "armed", armed_expected, armed_deadline)
            copied = output_dir / f"{implementation}-armed.json"
            copied.write_bytes(path.read_bytes())
            acknowledgements[f"{implementation}_armed"] = {"path": str(copied), "sha256": sha256_file(copied), "value": value}
        target_end = start_epoch_ms / 1000 + timeline_summary["duration_ms"] / 1000 + 2
        time.sleep(max(0, target_end - time.time()))
        completed_expected = {"start_epoch_ms": start_epoch_ms, "last_scene": timeline_summary["scene_ids"][-1]}
        for implementation, directory in document_dirs.items():
            path, value = wait_for_ack(directory, "synchronized-demo-completed.json", "completed", completed_expected, target_end + 5)
            copied = output_dir / f"{implementation}-completed.json"
            copied.write_bytes(path.read_bytes())
            acknowledgements[f"{implementation}_completed"] = {"path": str(copied), "sha256": sha256_file(copied), "value": value}
    finally:
        stop_recording(native_recorder)
        stop_recording(flutter_recorder)
        run(["xcrun", "simctl", "terminate", native_udid, NATIVE_BUNDLE], check=False)
        run(["xcrun", "simctl", "terminate", flutter_udid, FLUTTER_BUNDLE], check=False)
    compose(native_video, flutter_video, composite_video)

    outputs = {"native": native_video, "flutter": flutter_video, "composite": composite_video}
    media = {name: probe_media(path) for name, path in outputs.items()}
    manifest = build_manifest(
        run_id=run_id,
        start_epoch_ms=start_epoch_ms,
        recorder_started_ns={"native": native_started, "flutter": flutter_started},
        simulators=simulators,
        runtime=runtime,
        timeline=args.timeline,
        outputs=outputs,
        media=media,
    )
    manifest["launches"] = launch_results
    manifest["timeline_summary"] = timeline_summary
    manifest["verified_bundled_timeline_sha256"] = timeline_asset_hash
    manifest["acknowledgements"] = acknowledgements
    manifest["git_revision"] = run(["git", "rev-parse", "HEAD"], check=True).stdout.strip()
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({"output_dir": str(output_dir), "composite": str(composite_video), "manifest": str(manifest_path), "simulators": simulators}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
