import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from measurement.scripts.record_synchronized_demo import (
    build_manifest,
    compose_filter,
    find_runtime,
    explicit_simulators,
    launch_command,
    sha256_file,
    simulator_create_command,
)


class SynchronizedRecordingTests(unittest.TestCase):
    def test_runtime_selection_requires_exact_available_version(self):
        inventory = {
            "runtimes": [
                {"version": "26.4.1", "identifier": "runtime26", "buildversion": "23E254a", "isAvailable": True},
                {"version": "27.0", "identifier": "runtime27", "buildversion": "24A434", "isAvailable": True},
            ]
        }
        self.assertEqual(find_runtime(inventory, "26.4.1")["identifier"], "runtime26")
        with self.assertRaisesRegex(RuntimeError, "available runtime"):
            find_runtime(inventory, "26.4")

    def test_composition_keeps_both_inputs_without_retiming_or_optional_filters(self):
        value = compose_filter()
        self.assertIn("[0:v]setpts=PTS-STARTPTS", value)
        self.assertIn("[1:v]setpts=PTS-STARTPTS", value)
        self.assertIn("hstack=inputs=2", value)
        self.assertNotIn("drawtext", value)
        self.assertNotIn("trim", value)

    def test_launch_uses_installed_terminate_running_process_flag(self):
        self.assertEqual(
            launch_command("UDID", "bundle.id"),
            ["xcrun", "simctl", "launch", "--terminate-running-process", "UDID", "bundle.id"],
        )

    def test_clone_source_reuses_ready_device_state(self):
        self.assertEqual(
            simulator_create_command("Demo", "runtime26", "SOURCE"),
            ["xcrun", "simctl", "clone", "SOURCE", "Demo"],
        )

    def test_explicit_simulators_must_be_supplied_as_a_pair(self):
        self.assertEqual(explicit_simulators("N", "F"), ("N", "F"))
        self.assertIsNone(explicit_simulators(None, None))
        with self.assertRaisesRegex(ValueError, "both"):
            explicit_simulators("N", None)
        self.assertEqual(
            simulator_create_command("Demo", "runtime26", None),
            ["xcrun", "simctl", "create", "Demo", "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro", "runtime26"],
        )

    def test_manifest_hashes_exact_files_and_records_launch_delta(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            timeline = root / "timeline.json"
            native = root / "native.mp4"
            flutter = root / "flutter.mp4"
            composite = root / "composite.mp4"
            timeline.write_text('{"schema_version":1}')
            native.write_bytes(b"native")
            flutter.write_bytes(b"flutter")
            composite.write_bytes(b"composite")
            manifest = build_manifest(
                run_id="run",
                start_epoch_ms=1000,
                recorder_started_ns={"native": 10, "flutter": 25},
                simulators={"native": {"udid": "N"}, "flutter": {"udid": "F"}},
                runtime={"version": "26.4.1", "buildversion": "23E254a"},
                timeline=timeline,
                outputs={"native": native, "flutter": flutter, "composite": composite},
                media={"native": {}, "flutter": {}, "composite": {}},
            )
            self.assertEqual(manifest["recording_start_delta_ns"], 15)
            self.assertEqual(manifest["outputs"]["native"]["sha256"], hashlib.sha256(b"native").hexdigest())
            self.assertEqual(sha256_file(timeline), hashlib.sha256(timeline.read_bytes()).hexdigest())
            json.dumps(manifest)


if __name__ == "__main__":
    unittest.main()
