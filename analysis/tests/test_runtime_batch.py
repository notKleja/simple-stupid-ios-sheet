"""Synthetic gate simulations only; runtime marker fixtures are not native evidence."""
import copy
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest

from test_compare import full_config, full_trace

ROOT = Path(__file__).resolve().parents[2]


def rows(role, trial=1, attempt=1, terminal=True, error=False, spike=False):
    header = copy.deepcopy(full_trace(role)[0])
    header.update(native_contract_version=2, run_id=f"SYNTHETIC-{role}-{trial}-{attempt}", scenario_id="synthetic.runtime")
    header["configuration"] = {"trial": trial, "detents": ["fixed320", "medium", "large"], "surface": "opaque.white",
        "grabber": True, "page_sizing": True, "modal_in_presentation": False, "largest_undimmed": None,
        "presentation_style": "page_sheet", "preferred_content_size": {"width": 320, "height": 320}, "placement": "automatic",
        "edge_attached_in_compact_height": False, "width_follows_preferred_content_size": False, "scroll_expansion": True}
    header["provenance"] = {"fixture": "SYNTHETIC gate simulation; no native measurement"}
    records = [header]
    for ms in range(0, 161, 8):
        frame = copy.deepcopy(full_trace(role)[-1])
        frame.update(t_ns=ms*1_000_000, run_id=header["run_id"])
        frame["metrics"].update({"sheet.width": 400, "sheet.height": 300, "sheet.visible_height": 300})
        if spike and ms == 8:
            frame["metrics"]["sheet.y"] = 100
        records.append(frame)
    for ms, name, data in ((0,"present.requested",{}),(8,"present.first_visible",{}),(16,"present.completed",{}),
        (32,"detent.requested",{"target":"large"}),(80,"detent.requested",{"target":"medium"}),
        (128,"dismiss.requested",{}),(160,"dismiss.completed",{})):
        records.append({"schema_version":1,"type":"event","run_id":header["run_id"],"seq":0,"t_ns":ms*1_000_000,"name":name,"data":data})
    if not terminal:
        records = [r for r in records if r.get("name") != "dismiss.completed"]
    records.sort(key=lambda r:r["t_ns"])
    if terminal:
        records[-1]["terminal"] = True
    if error:
        records.append({"schema_version":1,"type":"event","run_id":header["run_id"],"seq":0,"t_ns":161_000_000,
                        "name":"run.error","data":{"reason":"SYNTHETIC error"},"terminal":True})
    for i,r in enumerate(records):
        r["seq"]=i
    return records


class RuntimeBatchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = TemporaryDirectory(prefix="SYNTHETIC-runtime-gates-")
        self.base = Path(self.tmp.name)
        self.matrix = {"schema_version":1,"minimum_trials":1,"environment_axes":{"ios_major":[26],"device_geometry":["iphone_a"],"orientation":["portrait"]},
            "cases":[{"id":"basic","scenario_id":"synthetic.runtime","role":"training","required_check_names":["present"],
                "required_checks":[{"id":"present","window":{"start_event":"present.requested","end_event":"detent.requested"}}]}]}
        self.profile = full_config()
        self.profile["alignment"]={"event":"present.requested","occurrence":0}
        self.recipe={"schema_version":1,"id":"SYNTHETIC","scenario_id":"synthetic.runtime","role":"training","preconditions":{},"steps":[],"provenance":"SYNTHETIC"}

    def tearDown(self):
        self.tmp.cleanup()

    def save(self,name,value):
        path=self.base/name
        path.write_text(json.dumps(value,sort_keys=True))
        return {"path":str(path),"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}

    def cohort(self,role,items,split="training",label=""):
        artifacts=[]
        for trial,attempt,options in items:
            records=rows(role,trial,attempt,**options)
            path=self.base/f"SYNTHETIC-{role}-{trial}-{attempt}-{label}.jsonl.gz"
            path.write_bytes(gzip.compress("".join(json.dumps(r)+"\n" for r in records).encode(),mtime=0))
            artifacts.append({"path":str(path),"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"trial":trial,"attempt":attempt,
                "run_id":records[0]["run_id"],"status":"complete" if options.get("terminal",True) else "partial"})
        return self.save(f"{role}-{label}-manifest.json",{"schema_version":1,"cohort_id":f"SYNTHETIC-{role}-{label}","implementation":role,"split":split,"artifacts":artifacts})

    def invoke(self,*args):
        result=subprocess.run([sys.executable,str(ROOT/"analysis/runtime_batch.py"),*args],text=True,capture_output=True)
        self.assertIn(result.returncode,(0,1),result.stderr)
        return result.returncode,json.loads(result.stdout)

    def execute(self,native,candidate,expected=(1,),split="training",extra=None):
        assignments=[{"split":split,"cell_id":"26/iphone_a/portrait/basic","expected_trials":list(expected),
            "native":native,"candidate":candidate,"recipe":self.save("recipe.json",self.recipe),"runtime_input_verified":True}]
        if extra:
            assignments+=extra
        plan=self.save("plan.json",{"schema_version":1,"batch_id":"SYNTHETIC","matrix":self.save("matrix.json",self.matrix),
            "profile":self.save("profile.json",self.profile),"assignments":assignments})
        code,freeze=self.invoke("freeze",plan["path"],"--output-directory",str(self.base/"frozen"))
        self.assertEqual(code,0,freeze)
        return self.invoke("run",freeze["index_path"])[1]

    def test_trial_pairing_is_deterministic_not_manifest_order(self):
        n=self.cohort("native",[(2,1,{}),(1,1,{})])
        c=self.cohort("flutter",[(1,1,{}),(2,1,{})])
        report=self.execute(n,c,expected=(1,2))
        self.assertEqual([p["trial"] for p in report["pairs"]],[1,2])
        self.assertEqual(report["pair_counts"]["paired"],2)

    def test_partial_attempt_is_audited_then_first_complete_retry_selected(self):
        n=self.cohort("native",[(1,1,{})])
        c=self.cohort("flutter",[(1,1,{"terminal":False}),(1,2,{})])
        report=self.execute(n,c)
        self.assertEqual(report["pairs"][0]["candidate"]["attempt"],2)
        self.assertTrue(any(a["status"]=="partial" for a in report["artifact_audit"]))

    def test_complete_numerical_failure_is_never_replaced_by_better_retry(self):
        n=self.cohort("native",[(1,1,{})])
        c=self.cohort("flutter",[(1,1,{"spike":True}),(1,2,{})])
        report=self.execute(n,c)
        self.assertEqual(report["pairs"][0]["candidate"]["attempt"],1)
        self.assertEqual(report["phase_counts"]["FAIL"],1)

    def test_run_error_invalidates_even_successful_terminal(self):
        report=self.execute(self.cohort("native",[(1,1,{})]),self.cohort("flutter",[(1,1,{"error":True})]))
        self.assertEqual(report["pair_counts"]["paired"],0)
        self.assertEqual(report["coverage_counts"]["UNRESOLVED"],1)

    def test_missing_expected_trial_remains_unresolved(self):
        report=self.execute(self.cohort("native",[(1,1,{})]),self.cohort("flutter",[(1,1,{})]),expected=(1,2))
        self.assertEqual(report["pair_counts"]["unresolved"],1)

    def test_manifest_hash_mismatch_cannot_discover_a_pair(self):
        n=self.cohort("native",[(1,1,{})]);c=self.cohort("flutter",[(1,1,{})])
        c["sha256"]="0"*64
        report=self.execute(n,c)
        self.assertEqual(report["pair_counts"]["paired"],0)
        self.assertIn("hash",json.dumps(report["artifact_audit"]))

    def test_frozen_split_content_cannot_change_after_freeze(self):
        n=self.cohort("native",[(1,1,{})]);c=self.cohort("flutter",[(1,1,{})])
        self.execute(n,c)
        split=self.base/"frozen/training.json"
        split.write_text(split.read_text()+" ")
        _,report=self.invoke("run",str(self.base/"frozen/index.json"))
        self.assertEqual(report["verdict"],"FAIL")
        self.assertTrue(any("hash" in issue for issue in report["issues"]))

    def test_holdout_artifacts_cannot_be_reassigned_to_training(self):
        n=self.cohort("native",[(1,1,{})]);c=self.cohort("flutter",[(1,1,{})])
        self.matrix["cases"].append({**copy.deepcopy(self.matrix["cases"][0]),"id":"holdout","role":"holdout"})
        extra=[{"split":"holdout","cell_id":"26/iphone_a/portrait/holdout","expected_trials":[1],"native":n,"candidate":c,
            "recipe":self.save("held-recipe.json",{**self.recipe,"role":"holdout"}),"runtime_input_verified":True}]
        report=self.execute(n,c,extra=extra)
        self.assertEqual(report["verdict"],"FAIL")
        self.assertTrue(any("split" in issue for issue in report["issues"]))

    def test_metadata_mismatch_is_not_automatically_normalized(self):
        n=self.cohort("native",[(1,1,{})]);c=self.cohort("flutter",[(1,1,{})])
        manifest=json.loads(Path(c["path"]).read_text());artifact=manifest["artifacts"][0];path=Path(artifact["path"])
        records=[json.loads(r) for r in gzip.decompress(path.read_bytes()).decode().splitlines()]
        records[0]["device"]["model"]="DIFFERENT-SYNTHETIC"
        path.write_bytes(gzip.compress("".join(json.dumps(r)+"\n" for r in records).encode(),mtime=0))
        artifact["sha256"]=hashlib.sha256(path.read_bytes()).hexdigest();c=self.save("flutter--manifest.json",manifest)
        report=self.execute(n,c)
        self.assertEqual(report["pair_counts"]["paired"],0)

    def test_phase_and_cell_counts_aggregate_without_absent_cells_passing(self):
        self.matrix["cases"].append({**copy.deepcopy(self.matrix["cases"][0]),"id":"absent"})
        report=self.execute(self.cohort("native",[(1,1,{})]),self.cohort("flutter",[(1,1,{"spike":True})]))
        self.assertEqual(report["coverage_counts"],{"PASS":0,"FAIL":1,"UNRESOLVED":1})
        self.assertEqual(report["phase_counts"],{"PASS":0,"FAIL":1,"UNRESOLVED":0})


if __name__=="__main__":
    unittest.main()
