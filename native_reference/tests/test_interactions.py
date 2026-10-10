"""Interaction acceptance fixtures are synthetic controls, not Apple measurements."""
import unittest
from pathlib import Path
import sys
import copy
from test_evidence import fixture

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))


class InteractionAcceptanceTests(unittest.TestCase):
    def cohort(self):
        runs=[]
        for trial in range(1,11):
            rows=fixture(trial)
            rows[0]['scenario_id']='native.nonmodal.medium'
            rows[0]['configuration']['largest_undimmed']='medium'
            rows[0]['environment'].update(size_classes={'horizontal':'compact','vertical':'regular'},status_bar={'hidden':False},keyboard={'visible':False,'frame':{'x':0,'y':0,'width':0,'height':0}})
            rows[0]['provenance']={'attempt_id':f'attempt-{trial}','role':'training','native_source_revision':'a'*40}
            rows=[r for r in rows if r['type']!='event']
            for name,ms in [('present.requested',1),('present.completed',50)]:
                rows.append({'schema_version':1,'type':'event','run_id':rows[0]['run_id'],'t_ns':ms*1000000,'name':name,'data':{}})
            for i,phase in enumerate(('medium_initial','large','medium_return')):
                before=i
                for j,(name,data) in enumerate([
                    ('background.probe.requested',{'phase':phase,'activation_before':before}),
                    ('input.touch',{'phase':0}),
                    ('background.control.activated',{'count':before+1}),
                    ('background.probe.completed',{'phase':phase,'activation_after':before+1,'delivered_target_touch_events':2})]):
                    rows.append({'schema_version':1,'type':'event','run_id':rows[0]['run_id'],'t_ns':(i*1000+100+j)*1000000,'name':name,'data':data})
            rows.append({'schema_version':1,'type':'event','run_id':rows[0]['run_id'],'t_ns':6000000000,'name':'dismiss.completed','terminal':True,'data':{}})
            rows.sort(key=lambda r:r['t_ns'])
            for seq,row in enumerate(rows): row['seq']=seq
            runs.append(rows)
        return runs

    def test_complete_interaction_cohort_is_validated_not_declared(self):
        from interaction_validation import validate_interaction_cohort
        self.assertEqual(len(validate_interaction_cohort(self.cohort())),10)

    def test_cohort_rejects_missing_duplicate_mixed_or_unpinned_trials(self):
        from interaction_validation import validate_interaction_cohort
        cases=[self.cohort()[:1]]
        for section,key,value in [('configuration','trial',1),('os','build','different'),('provenance','attempt_id','attempt-1'),('provenance','native_source_revision','unresolved')]:
            runs=copy.deepcopy(self.cohort());runs[1][0][section][key]=value;cases.append(runs)
        for runs in cases:
            with self.subTest(): self.assertRaises(ValueError,validate_interaction_cohort,runs)

    def test_error_missing_terminal_or_unexplained_null_invalidates_cohort(self):
        from interaction_validation import validate_interaction_cohort
        runs=self.cohort();runs[1][-1]['name']='run.error'
        self.assertRaises(ValueError,validate_interaction_cohort,runs)
        runs=self.cohort();runs[1].pop()
        self.assertRaises(ValueError,validate_interaction_cohort,runs)
        runs=self.cohort();next(r for r in runs[1] if r['type']=='frame')['state']['scroll_owner']=None
        self.assertRaises(ValueError,validate_interaction_cohort,runs)

    def test_incomplete_probe_phase_sequence_is_rejected(self):
        from interaction_validation import validate_interaction_cohort
        runs=self.cohort()
        for row in runs[1]:
            if row.get('data',{}).get('phase')=='medium_return': row['data']['phase']='large'
        self.assertRaises(ValueError,validate_interaction_cohort,runs)

    def test_counter_without_actual_control_activation_is_rejected(self):
        from interaction_validation import nonmodal_outcomes
        rows=[r for r in self.cohort()[0] if r.get('name')!='background.control.activated']
        self.assertRaises(ValueError,nonmodal_outcomes,rows)

    def test_incomplete_nested_runtime_metadata_is_rejected(self):
        from interaction_validation import validate_interaction_cohort
        for section,key in [('device','physical_size'),('environment','keyboard'),('environment','size_classes')]:
            runs=self.cohort();del runs[1][0][section][key]
            with self.subTest(key=key): self.assertRaises(ValueError,validate_interaction_cohort,runs)

    def scroll_cohort(self):
        runs=self.cohort()
        for rows in runs:
            rows[0]['scenario_id']='native.scroll.content_first'
            rows[0]['configuration'].update(largest_undimmed=None,scroll_expansion=False)
            rows[:]=[r for r in rows if not r.get('name','').startswith('background.') and r.get('name')!='input.touch']
            for row in rows:
                if row['type']=='frame': row['metrics'].update({'scroll.offset':100 if row['t_ns']>1000000000 else 0,'scroll.pan_velocity_y':500})
            for name,ms,data in [('scroll.probe.requested',500,{'scroll_offset':0}),('input.touch',510,{'phase':0}),('input.touch',520,{'phase':1}),('input.touch',530,{'phase':3}),('scroll.probe.completed',2000,{'scroll_offset':100})]:
                rows.append({'schema_version':1,'type':'event','run_id':rows[0]['run_id'],'t_ns':ms*1000000,'name':name,'data':data})
            rows.sort(key=lambda r:r['t_ns'])
            for seq,row in enumerate(rows):row['seq']=seq
        return runs

    def test_actual_scroll_samples_are_scoped_not_private_ownership(self):
        from interaction_validation import validate_interaction_cohort
        report=validate_interaction_cohort(self.scroll_cohort())[0]
        self.assertEqual(report['scroll_end'],100)
        self.assertEqual(report['private_scroll_owner'],'unresolved')
        self.assertIs(report['full_trajectory_acceptance'],False)

    def test_scroll_control_taps_or_missing_pan_cannot_prove_drag(self):
        from interaction_validation import validate_interaction_cohort
        runs=self.scroll_cohort()
        for row in runs[1]:
            if row.get('name')=='input.touch':row['data']['phase']=0
        self.assertRaises(ValueError,validate_interaction_cohort,runs)
        runs=self.scroll_cohort()
        for row in runs[1]:
            if row['type']=='frame':del row['metrics']['scroll.pan_velocity_y']
        self.assertRaises(ValueError,validate_interaction_cohort,runs)

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
