"""Synthetic controls for diagnostic-only smoke completeness; no measured radius constants."""
import copy
import sys
from pathlib import Path
import unittest
from test_evidence import fixture
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from validate_geometry_smoke import validate_smoke

def smoke():
    rows=fixture(1);rows[0]['scenario_id']='native.geometry.smoke';rows[0]['geometry_probe']={'accepted':False,'schema_version':1}
    rows[-1]['terminal']=True
    for row in rows:
        if row['type']=='frame':
            row['metrics'].update({'sheet.radius':None,'barrier.alpha':None})
            row['unavailable']={'sheet.radius':'Unvalidated clip candidate','barrier.alpha':'Unclassified barrier'}
            row['geometry_probe']={'accepted':False,'schema_version':1,'sheet_candidates':[{'id':'sheet','effective_radii_model':{'top_left':0,'top_right':0,'bottom_left':0,'bottom_right':0}}]}
    return rows

class GeometrySmokeTests(unittest.TestCase):
    def test_valid_output_is_diagnostic_not_an_accepted_profile(self):
        result=validate_smoke(smoke())
        self.assertIs(result['diagnostic_only'],True)
        self.assertIs(result['accepted_profile'],False)
    def test_missing_probe_combined_corners_or_promoted_metric_rejects(self):
        for defect in ('missing','combined','promoted'):
            rows=smoke();frames=[r for r in rows if r['type']=='frame']
            for row in frames:
                if defect=='missing':del row['geometry_probe']
                elif defect=='combined':row['geometry_probe']['sheet_candidates'][0]['effective_radii_model']={'all':17}
                else:row['metrics']['sheet.radius']=17
            with self.subTest(defect=defect):self.assertRaises(ValueError,validate_smoke,rows)
    def test_ancestry_churn_in_resting_window_is_not_stable(self):
        rows=smoke();f=next(r for r in rows if r['type']=='frame' and r['t_ns']==1440000000)
        f['geometry_probe']['sheet_candidates'][0]['id']='pointer-unstable'
        self.assertRaises(ValueError,validate_smoke,rows)

if __name__=='__main__':unittest.main()
