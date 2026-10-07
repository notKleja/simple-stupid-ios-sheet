"""Synthetic real-file applicability controls, never native parity evidence."""
import copy
import unittest
import test_conditions_v2 as fixtures


GROUPS = ("target_detent", "scroll", "hit_testing", "keyboard", "stack_layers", "contour", "performance")
FIELDS = {"target_detent": ("state", "target_detent"), "scroll": ("state", "scroll_owner"),
          "hit_testing": ("state", "underlying_hit_test"), "keyboard": ("observations", "keyboard"),
          "stack_layers": ("observations", "stack_layers"), "contour": ("observations", "contour"),
          "performance": ("observations", "performance")}


class ApplicabilityTests(unittest.TestCase):
    tearDown = fixtures.ConditionsBatchTests.tearDown
    save = fixtures.ConditionsBatchTests.save
    invoke = fixtures.ConditionsBatchTests.invoke
    execute = fixtures.ConditionsBatchTests.execute

    def setUp(self):
        fixtures.ConditionsBatchTests.setUp(self)
        self.phase = "present"
        self.rules = {group: "required" for group in GROUPS}
        self.policy_id = "SYNTHETIC-present-all-required"
        self.profile["applicability_policies"] = {
            self.policy_id: {"phase": "present", "observables": copy.deepcopy(self.rules)}}
        self.contract = self.matrix["cases"][0]["required_checks"][0]
        self.contract.update(phase="present", applicability_policy_id=self.policy_id)
        self.recipe["conditions"]["applicability"] = {"present": copy.deepcopy(self.rules)}

    def cohort(self, role, change=None):
        def declared(records):
            records[0]["conditions"]["applicability"] = {self.phase: copy.deepcopy(self.rules)}
            for row in records:
                if row["type"] == "frame":
                    row["metrics"]["scroll.offset"] = 0
                    row["observations"] = {"keyboard": {"visible": False}, "stack_layers": [{"id": "one"}],
                        "contour": {"source": "SYNTHETIC-not-native-contour"}, "performance": {"source": "SYNTHETIC"}}
            if change:
                change(records)
        return fixtures.ConditionsBatchTests.cohort(self, role, declared)

    def test_unknown_policy_cannot_be_ignored(self):
        self.contract["applicability_policy_id"] = "unknown-policy"
        result = self.execute()
        self.assertEqual(result.get("coverage_counts", {}).get("PASS", 0), 0)
        self.assertIn("policy", str(result))

    def test_unknown_or_mismatched_phase_cannot_be_ignored(self):
        self.contract["phase"] = "unknown-phase"
        result = self.execute()
        self.assertEqual(result.get("coverage_counts", {}).get("PASS", 0), 0)
        self.assertIn("phase", str(result))

    def test_each_required_observable_omission_is_explicitly_unresolved(self):
        for group in GROUPS:
            with self.subTest(group=group):
                self.tmp.cleanup(); self.setUp()
                section, field = FIELDS[group]
                def absent(records):
                    for row in records:
                        if row["type"] == "frame": row[section].pop(field)
                result = self.execute(self.cohort("native", absent), self.cohort("flutter", absent))
                self.assertEqual(result["phase_counts"]["UNRESOLVED"], 1)
                self.assertIn(group, result["phases"][0].get("applicability", {}).get("unresolved_observables", []))

    def test_caller_cannot_relax_a_required_observable(self):
        def relax(records):
            records[0]["conditions"]["applicability"]["present"]["target_detent"] = "not_applicable"
        result = self.execute(candidate=self.cohort("flutter", relax))
        self.assertEqual(result.get("coverage_counts", {}).get("PASS", 0), 0)

    def test_required_null_is_unresolved_not_zero(self):
        def absent(records):
            for row in records:
                if row["type"] == "frame":
                    row["state"]["target_detent"] = None
                    row["unavailable"] = {"target_detent": "SYNTHETIC observer missing"}
        result = self.execute(self.cohort("native", absent), self.cohort("flutter", absent))
        self.assertEqual(result["phase_counts"]["UNRESOLVED"], 1)
        self.assertIn("target_detent", result["phases"][0].get("applicability", {}).get("unresolved_observables", []))

    def test_unavailable_requires_a_reason_even_if_a_placeholder_value_exists(self):
        self.rules["target_detent"] = "unavailable"
        self.profile["applicability_policies"][self.policy_id]["observables"] = copy.deepcopy(self.rules)
        self.recipe["conditions"]["applicability"]["present"] = copy.deepcopy(self.rules)
        result = self.execute()
        self.assertEqual(result["phase_counts"]["UNRESOLVED"], 1)
        self.assertIn("missing_reason", result["phases"][0].get("applicability", {}).get("reason_failures", []))

    def test_approved_dismissal_target_exemption_preserves_other_gates(self):
        self.phase = "dismiss"
        self.rules = {group: "not_applicable" for group in GROUPS}
        self.profile["applicability_policies"] = {"SYNTHETIC-dismiss": {"phase": "dismiss", "observables": copy.deepcopy(self.rules)}}
        self.contract.update(phase="dismiss", applicability_policy_id="SYNTHETIC-dismiss",
            window={"start_event": "dismiss.requested", "end_event": "dismiss.completed"})
        self.recipe["conditions"]["applicability"] = {"dismiss": copy.deepcopy(self.rules)}
        def dismissed(records):
            for row in records:
                if row["type"] == "frame":
                    row["state"]["target_detent"] = None
                    row["state"].pop("scroll_owner", None)
                    row["metrics"].pop("scroll.offset", None)
                    row["unavailable"] = {"target_detent": "SYNTHETIC dismissal has no target"}
        result = self.execute(self.cohort("native", dismissed), self.cohort("flutter", dismissed))
        self.assertEqual(result["phase_counts"]["PASS"], 1)
        self.assertIn("state.target_detent", result["phases"][0]["applicability"]["approved_exemptions"])
        self.assertIn("state.scroll_owner", result["phases"][0]["applicability"]["approved_exemptions"])
        self.assertIn("metrics.scroll.offset", result["phases"][0]["applicability"]["approved_exemptions"])
        self.assertFalse(result["phases"][0]["analyzer"]["native_parity_eligible"])

    def test_profile_policy_identity_is_hash_pinned(self):
        self.execute()
        self.profile["applicability_policies"] = {}
        self.save("profile.json", self.profile)
        _, result = self.invoke("run", str(self.base / "frozen/index.json"))
        self.assertIn("hash", str(result["issues"]))

    def test_dismissal_label_cannot_authorize_an_exemption_in_presentation(self):
        self.phase = "dismiss"
        self.rules = {group: "not_applicable" for group in GROUPS}
        self.profile["applicability_policies"] = {"SYNTHETIC-dismiss": {"phase": "dismiss", "observables": copy.deepcopy(self.rules)}}
        self.contract.update(phase="dismiss", applicability_policy_id="SYNTHETIC-dismiss")
        self.recipe["conditions"]["applicability"] = {"dismiss": copy.deepcopy(self.rules)}
        result = self.execute()
        self.assertEqual(result.get("coverage_counts", {}).get("PASS", 0), 0)
        self.assertTrue(result["issues"])

    def test_required_structured_diagnostics_do_not_become_comparison_acceptance(self):
        result = self.execute()
        self.assertEqual(result["phase_counts"]["PASS"], 0)
        self.assertIn("contour", result["phases"][0]["applicability"]["unsupported_comparisons"])


if __name__ == "__main__":
    unittest.main()
