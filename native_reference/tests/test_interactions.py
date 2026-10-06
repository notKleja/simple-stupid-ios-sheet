"""Interaction acceptance fixtures are synthetic controls, not Apple measurements."""
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))


class InteractionAcceptanceTests(unittest.TestCase):
    def test_alpha_without_delivered_touch_and_activation_cannot_prove_nonmodal(self):
        from interaction_validation import nonmodal_outcomes
        self.assertRaises(ValueError, nonmodal_outcomes, [{"type":"frame", "metrics":{"barrier.alpha":0}, "state":{"underlying_hit_test":True}}])

    def test_actual_touch_and_control_outcomes_preserve_each_probe(self):
        from interaction_validation import nonmodal_outcomes
        rows = [
            {"type":"event", "name":"background.probe.requested", "data":{"phase":"medium_initial", "activation_before":0}},
            {"type":"event", "name":"input.touch", "data":{"phase":0, "x":100, "y":175}},
            {"type":"event", "name":"background.control.activated", "data":{"count":1}},
            {"type":"event", "name":"background.probe.completed", "data":{"phase":"medium_initial", "activation_after":1, "delivered_target_touch_events":1}},
        ]
        self.assertEqual(nonmodal_outcomes(rows)[0]["activated"], True)

    def test_sheet_button_touches_do_not_prove_background_delivery(self):
        from interaction_validation import nonmodal_outcomes
        rows = [{"type":"event","name":"background.probe.requested","data":{"phase":"large","activation_before":1}},
            {"type":"event","name":"input.touch","data":{"phase":0,"x":300,"y":600}},
            {"type":"event","name":"background.probe.completed","data":{"phase":"large","activation_after":1,"delivered_target_touch_events":0}}]
        self.assertRaises(ValueError, nonmodal_outcomes, rows)


if __name__ == "__main__": unittest.main()
