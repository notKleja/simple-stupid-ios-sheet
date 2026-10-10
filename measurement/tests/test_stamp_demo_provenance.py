import json
import tempfile
import unittest
from pathlib import Path

from measurement.scripts.stamp_demo_provenance import build_payload, write_payload


class StampDemoProvenanceTests(unittest.TestCase):
    def test_writes_identical_clean_revision_payload_to_both_bundles(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            native = root / "Native.app" / "synchronized-demo-provenance.json"
            flutter = root / "Runner.app" / "Frameworks/App.framework/flutter_assets/assets/synchronized-demo-provenance.json"
            payload = build_payload("a" * 40, "b" * 64, source_tree_clean=True)
            write_payload({"native": native, "flutter": flutter}, payload)
            self.assertEqual(json.loads(native.read_text()), payload)
            self.assertEqual(json.loads(flutter.read_text()), payload)
            self.assertNotIn("source_tree_fingerprint", payload)

    def test_refuses_dirty_or_malformed_source_identity(self):
        with self.assertRaisesRegex(RuntimeError, "clean committed source"):
            build_payload("a" * 40, "b" * 64, source_tree_clean=False)
        for revision, timeline in (("short", "b" * 64), ("a" * 40, "short")):
            with self.subTest(revision=revision, timeline=timeline), self.assertRaises(ValueError):
                build_payload(revision, timeline, source_tree_clean=True)


if __name__ == "__main__":
    unittest.main()
