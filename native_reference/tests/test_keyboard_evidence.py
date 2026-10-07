import copy
import json
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from keyboard_evidence import validate_cohort

def trial(i):
    return dict(run_id=str(i), trial=i + 1, evidence_kind='runtime', implementation='native',
        conditions=dict(os_build='iOS 27.0 (24A123)', device=dict(model='iPhone18,3', runtime_kind='simulator'),
        orientation='portrait', scale=3.0, safe_area=dict(top=62, left=0, bottom=34, right=0),
        keyboard=dict(visible=True, frame=dict(x=0, y=600, width=400, height=200)),
        accessibility=dict(reduce_motion=False, voice_over=False, content_size_category='UICTContentSizeCategoryL'),
        configuration=dict(presentation_style='page_sheet', detents=['medium', 'large']), scenario_revision=1,
        gesture_recipe=dict(id='keyboard.focus.blur', revision=1)),
        complete=True, observations=[dict(source='public_notification', timestamp=1., frame=dict(x=0, y=600, width=400, height=200),
        duration=.25, curve=7, focus='focused', inset=200., inset_basis='viewport_intersection_no_safe_area_addition',
        keyboard_presence='software', interactive_phase='unavailable')])

class KeyboardEvidenceTests(unittest.TestCase):
    def setUp(self): self.rows = [trial(i) for i in range(10)]
    def test_ten_matched_contract_records(self): self.assertTrue(validate_cohort(self.rows)['accepted'])
    def reject(self): self.assertFalse(validate_cohort(self.rows)['accepted'])
    def test_short(self): self.rows.pop(); self.reject()
    def test_duplicate(self): self.rows[-1] = copy.deepcopy(self.rows[0]); self.reject()
    def test_mixed_conditions(self): self.rows[-1]['conditions']['os_build']='different'; self.reject()
    def test_missing_condition(self): del self.rows[0]['conditions']['safe_area']; self.reject()
    def test_placeholder_conditions_are_not_a_cohort(self):
        for row in self.rows: row['conditions'] = {key: None for key in row['conditions']}
        self.reject()
    def test_malformed_condition_axis_is_not_a_cohort(self):
        self.rows[0]['conditions']['scale'] = 0
        self.reject()
    def test_zero_scale_is_rejected_even_when_every_trial_matches(self):
        for row in self.rows: row['conditions']['scale'] = 0
        self.reject()
    def test_same_run_is_not_independent(self):
        for row in self.rows: row['run_id'] = 'same-run'
        self.reject()
    def test_trial_sequence_must_be_canonical(self):
        self.rows[-1]['trial'] = 11
        self.reject()
    def test_malformed_trial_identity_is_not_a_cohort(self):
        self.rows[0]['trial'] = True
        self.reject()
    def test_literal_swift_shaped_frame_payload_is_accepted(self):
        observation = json.loads('''{
          "source":"public_notification", "timestamp":1.0,
          "frame":{"x":0,"y":600,"width":400,"height":200},
          "duration":0.25, "curve":7, "focus":"focused", "inset":200.0,
          "inset_basis":"viewport_intersection_no_safe_area_addition",
          "keyboard_presence":"software", "interactive_phase":"unavailable"
        }''')
        self.rows[0]['observations'] = [observation]
        self.assertTrue(validate_cohort(self.rows)['accepted'])
    def test_synthetic_and_launch(self):
        for source in ['synthetic', 'launch_flag']:
            self.rows[0]['observations'][0]['source']=source; self.reject()
    def test_bad_observations(self):
        for key, values in {'frame':[None, [0,0,-1,2], {'x':0,'y':0,'width':-1,'height':2}, {'x':0,'y':0,'width':1,'height':float('nan')}], 'duration':[None,-1,True], 'timestamp':[None,-1,float('inf')], 'focus':[None,'unavailable'], 'inset_basis':[None,'safe_area_added'], 'interactive_phase':['changed','dismissed'], 'curve':[None,-1,1.5]}.items():
            for value in values:
                with self.subTest(key=key,value=value):
                    self.rows=[trial(i) for i in range(10)]; self.rows[0]['observations'][0][key]=value; self.reject()
    def test_zero_does_not_establish_hardware(self):
        self.rows[0]['observations'][0].update(inset=0, keyboard_presence='hardware'); self.reject()
    def test_no_observations(self): self.rows[0]['observations']=[]; self.reject()
    def test_backwards_time(self):
        o=copy.deepcopy(self.rows[0]['observations'][0]); o['timestamp']=.5
        self.rows[0]['observations'].append(o); self.reject()

if __name__ == '__main__': unittest.main()
