"""Literal synthetic controls; fixtures are not measured UIKit sheet radii."""
import copy
import gzip
import hashlib
import json
import tempfile
import sys
from pathlib import Path
import unittest
from test_evidence import fixture
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from geometry_cohort import validate_cohort, summarize, validate_manifest

HASHES={'native_reference/NativeSheetHarness/App.swift':'a'*64}

def run(trial):
    head=fixture(trial)[0];head['scenario_id']='native.geometry.smoke'
    head['geometry_probe']={'schema_version':1,'accepted':False}
    head['provenance']={'attempt_id':f'SYNTHETIC-{trial}','source_hashes':HASHES,'role':'training'}
    rows=[head]
    for ms,name,data in [(0,'present.requested',{}),(500,'present.completed',{}),
        (1500,'detent.requested',{'target':'medium'}),(3000,'detent.requested',{'target':'large'}),
        (4500,'detent.requested',{'target':'medium'}),(6000,'dismiss.requested',{}),(6500,'dismiss.completed',{})]:
        rows.append({'type':'event','name':name,'data':data,'t_ns':ms*1000000,'terminal':name=='dismiss.completed'})
    for boundary,selected in [(1500,'fixed320'),(3000,'medium'),(4500,'large'),(6000,'medium')]:
        for index in range(24):
            rows.append({'type':'frame','t_ns':boundary*1000000-399999984+index*16666667,
                'metrics':{'sheet.radius':None,'barrier.alpha':None},'unavailable':{'sheet.radius':'Unvalidated','barrier.alpha':'Unclassified'},
                'state':{'selected_detent':selected},'geometry_probe':{'schema_version':1,'accepted':False,'sheet_candidates':[
                    {'id':'sheet','effective_radii_model':{'top_left':trial,'top_right':11,'bottom_left':13.25,'bottom_right':17.125},
                     'corner_configuration':{'present':True,'description_diagnostic_only':'SYNTHETIC asymmetric corners'}}]}})
    rows.sort(key=lambda row:row['t_ns'])
    for seq,row in enumerate(rows):row.update(schema_version=1,run_id=head['run_id'],seq=seq)
    return rows

class GeometryCohortTests(unittest.TestCase):
    def setUp(self):self.runs=[run(n) for n in range(1,11)]
    def reject(self,runs=None):self.assertRaises(ValueError,validate_cohort,runs or self.runs,HASHES)
    def test_ten_independent_literal_trials_qualify_model_only(self):
        result=validate_cohort(self.runs,HASHES)
        self.assertEqual(len(result),10)
    def test_one_or_duplicate_trial_or_run_or_attempt_rejects(self):
        self.reject(self.runs[:1])
        original=copy.deepcopy(self.runs)
        for key in ('trial','run','attempt'):
            self.runs=copy.deepcopy(original)
            if key=='trial':self.runs[1][0]['configuration']['trial']=1
            elif key=='attempt':self.runs[1][0]['provenance']['attempt_id']='SYNTHETIC-1'
            else:
                for row in self.runs[1]:row['run_id']=self.runs[0][0]['run_id']
            with self.subTest(key=key):self.reject()
    def test_mixed_os_device_environment_configuration_or_source_rejects(self):
        original=copy.deepcopy(self.runs)
        for section,key,value in [('os','build','DIFFERENT'),('device','scale',2),('environment','orientation','landscape'),('configuration','grabber',False),('provenance','source_hashes',{'other':'b'*64})]:
            self.runs=copy.deepcopy(original);self.runs[1][0][section][key]=value
            with self.subTest(section=section):self.reject()
    def test_combined_corner_loss_or_scalar_promotion_rejects(self):
        for defect in ('combined','scalar'):
            self.setUp();frame=next(r for r in self.runs[0] if r['type']=='frame')
            if defect=='combined':frame['geometry_probe']['sheet_candidates'][0]['effective_radii_model']={'all':17}
            else:frame['metrics']['sheet.radius']=17
            with self.subTest(defect=defect):self.reject()
    def test_candidate_id_churn_in_window_rejects(self):
        next(r for r in self.runs[0] if r['type']=='frame')['geometry_probe']['sheet_candidates'][0]['id']='pointer-changed'
        self.reject()
    def test_gap_exceeding_two_declared_native_frames_rejects(self):
        self.runs[0]=[row for row in self.runs[0] if not row['type']=='frame' or row['t_ns'] not in (1116666683,1133333350)]
        for seq,row in enumerate(self.runs[0]):row['seq']=seq
        self.reject()
    def test_missing_terminal_or_failed_attempt_cannot_be_filtered(self):
        for defect in ('missing','error'):
            self.setUp()
            if defect=='missing':self.runs[0].pop()
            else:self.runs[0][-1]['name']='run.error'
            with self.subTest(defect=defect):self.reject()
    def test_old_task3a_smoke_sequence_cannot_be_reused(self):
        request=next(r for r in self.runs[0] if r.get('name')=='detent.requested');request['data']['target']='large'
        self.reject()
    def test_frame_times_must_be_monotonic_even_outside_windows(self):
        frames=[r for r in self.runs[0] if r['type']=='frame'];frames[1]['t_ns']=frames[0]['t_ns']
        self.reject()
    def test_literal_asymmetric_summary_dispersion_and_pixel_residuals(self):
        result=summarize(self.runs,HASHES)
        self.assertEqual(result.get('capability_status'),'measured_model_radii_contour_unresolved')
        candidate=result.get('phases',{}).get('fixed320',{}).get('sheet',{})
        corners=candidate.get('corners',{})
        self.assertEqual(set(corners),{'top_left','top_right','bottom_left','bottom_right'})
        tl=corners.get('top_left',{})
        self.assertEqual((tl.get('median'),tl.get('min'),tl.get('max')),(5.5,1,10))
        self.assertAlmostEqual(tl.get('stddev_population',0),2.8722813232690143)
        self.assertEqual(corners.get('bottom_left',{}).get('median'),13.25)
        self.assertEqual(corners.get('bottom_right',{}).get('median'),17.125)
        self.assertAlmostEqual(corners.get('bottom_left',{}).get('physical_pixel_quantization',{}).get('max_integer_pixel_residual',0),0.25)
        self.assertEqual(candidate.get('configuration_descriptions'),['SYNTHETIC asymmetric corners'])
        self.assertIs(result.get('rendered_contour_accepted'),False)
    def materialize(self,root):
        entries=[]
        for rows in self.runs:
            raw=('\n'.join(json.dumps(r) for r in rows)+'\n').encode();data=gzip.compress(raw,mtime=0)
            path=root/(rows[0]['run_id']+'.jsonl.gz');path.write_bytes(data)
            entries.append({'path':path.name,'sha256':hashlib.sha256(data).hexdigest(),'raw_sha256':hashlib.sha256(raw).hexdigest(),
                'run_id':rows[0]['run_id'],'trial':rows[0]['configuration']['trial'],'attempt_id':rows[0]['provenance']['attempt_id']})
        return {'schema_version':1,'source_hashes':HASHES,'entries':entries}
    def test_actual_gzip_manifest_hashes_and_identities_are_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);manifest=self.materialize(root)
            self.assertEqual(validate_manifest(manifest,root).get('trial_count'),10)
    def test_changed_gzip_bytes_or_manifest_run_identity_rejects(self):
        for defect in ('bytes','identity'):
            with tempfile.TemporaryDirectory() as directory:
                root=Path(directory);manifest=self.materialize(root)
                if defect=='bytes':(root/manifest['entries'][0]['path']).write_bytes(b'changed')
                else:manifest['entries'][0]['run_id']='not-the-observed-run'
                with self.subTest(defect=defect):self.assertRaises(ValueError,validate_manifest,manifest,root)

if __name__=='__main__':unittest.main()
