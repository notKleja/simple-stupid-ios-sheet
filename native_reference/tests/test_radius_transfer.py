"""Literal synthetic transfer controls, never measured Apple formulas."""
import copy
import math
import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from radius_transfer import fit_corner, fit_four

def samples(function):
    return [{'trial':trial,'features':{'height':float(x),'detent':'medium','direction':'up'},
             'radii':{'top_left':function(x),'top_right':function(x)+1,'bottom_left':function(x)+2,'bottom_right':function(x)+3}}
            for trial in range(1,11) for x in range(1,13)]

class RadiusTransferTests(unittest.TestCase):
    def test_literal_constant_is_simplest_accepted_model(self):
        r=fit_corner(samples(lambda x:38),'top_left')
        self.assertEqual(r.get('status'),'formula')
        self.assertEqual(r.get('selected_model',{}).get('family'),'constant')
        self.assertEqual(r.get('selected_model',{}).get('coefficients'),[38])
    def test_known_affine_geometry_is_recovered_without_scalar_collapse(self):
        r=fit_four(samples(lambda x:7+2*x))
        self.assertEqual(set(r),{'top_left','top_right','bottom_left','bottom_right'})
        self.assertEqual(r['top_left'].get('selected_model',{}).get('coefficients'),[7,2])
        self.assertEqual(r['bottom_right'].get('selected_model',{}).get('coefficients'),[10,2])
        self.assertEqual(r['top_left'].get('status'),'formula')
    def test_minimal_piecewise_affine_is_recovered(self):
        r=fit_corner(samples(lambda x:2+x if x<=5 else 17+3*x),'top_left')
        self.assertEqual(r.get('selected_model',{}).get('family'),'piecewise_affine')
        self.assertEqual(r.get('selected_model',{}).get('threshold'),5.5)
        self.assertEqual(r.get('selected_model',{}).get('left'),[2,1])
        self.assertEqual(r.get('selected_model',{}).get('right'),[17,3])
        self.assertEqual(r.get('status'),'formula')
    def test_nonfinite_private_class_or_trial_order_predictors_reject(self):
        for defect in ('nonfinite','private','time','order'):
            rows=samples(lambda x:38)
            if defect=='nonfinite':rows[0]['radii']['top_left']=math.inf
            elif defect=='private':rows[0]['features']['class']='_UIClippingView'
            elif defect=='time':rows[0]['features']['t_ns']=123
            else:rows[0]['features']['trial_order']=1
            with self.subTest(defect=defect):self.assertRaises(ValueError,fit_corner,rows,'top_left')
    def test_underdetermined_geometry_does_not_force_formula(self):
        rows=samples(lambda x:38)
        for row in rows:row['features']['height']=5
        self.assertNotEqual(fit_corner(rows,'top_left').get('status'),'formula')
    def test_sub_epsilon_geometry_jitter_is_still_underdetermined(self):
        rows=samples(lambda x:38)
        for index,row in enumerate(rows):
            row['features']={'height':5.0,'width':390.0+(index%3)*1e-9,'detent':'medium','direction':'up'}
        self.assertEqual(fit_corner(rows,'top_left').get('status'),'lookup_domain')
    def test_training_only_model_selection_is_unchanged_by_holdout(self):
        rows=samples(lambda x:7+2*x);a=fit_corner(rows,'top_left')
        changed=copy.deepcopy(rows)
        for row in changed:
            if row['trial']>=9:row['radii']['top_left']+=10
        b=fit_corner(changed,'top_left')
        self.assertEqual(a.get('selected_model'),b.get('selected_model'))
        self.assertEqual(b.get('status'),'unresolved')
        self.assertGreater(b.get('holdout_max_error',0),0.5)
        self.assertEqual(b.get('train_trials'),list(range(1,9)))
        self.assertEqual(b.get('holdout_trials'),[9,10])
    def test_small_improvement_does_not_force_more_complex_formula(self):
        r=fit_corner(samples(lambda x:38+0.01*x),'top_left')
        self.assertEqual(r.get('selected_model',{}).get('family'),'constant')
    def test_high_frequency_overfit_is_unresolved(self):
        r=fit_corner(samples(lambda x:10 if x%2 else 40),'top_left')
        self.assertEqual(r.get('status'),'unresolved')
    def test_missing_holdout_cannot_be_accepted(self):
        self.assertRaises(ValueError,fit_corner,[r for r in samples(lambda x:38) if r['trial']<=8],'top_left')
    def test_holdout_feature_availability_cannot_change_selected_model(self):
        rows=samples(lambda x:7+2*x);a=fit_corner(rows,'top_left')
        for row in rows:
            if row['trial']>=9:row['features']['width']=row['features'].pop('height')
        b=fit_corner(rows,'top_left')
        self.assertEqual(a['selected_model'],b['selected_model'])
        self.assertEqual(b['status'],'unresolved')
    def test_direction_candidate_uses_observed_direction_not_trial_order(self):
        rows=samples(lambda x:7+2*x)
        for row in copy.deepcopy(rows):
            row['features']['direction']='down'
            row['radii']={corner:value+15 for corner,value in row['radii'].items()};rows.append(row)
        r=fit_corner(rows,'top_left')
        self.assertEqual(r.get('selected_model',{}).get('family'),'direction_affine')
        self.assertEqual(r.get('status'),'formula')
    def test_direction_candidate_compares_three_observed_states(self):
        rows=samples(lambda x:7+2*x)
        for direction,offset in (('down',15),('stationary',30)):
            branch=copy.deepcopy(rows[:120])
            for row in branch:
                row['features']['direction']=direction
                row['radii']={corner:value+offset for corner,value in row['radii'].items()}
            rows.extend(branch)
        r=fit_corner(rows,'top_left')
        self.assertEqual(set(r.get('selected_model',{}).get('branches',{})),{'up','down','stationary'})
        self.assertEqual(r.get('selected_model',{}).get('family'),'direction_affine')
    def test_three_direction_branches_do_not_outrank_simpler_piecewise_fit(self):
        rows=samples(lambda x:2+x if x<=4 else 17+3*x)
        for row in rows:
            height=row['features']['height']
            row['features']['direction']='up' if height<=4 else ('stationary' if height<=8 else 'down')
        r=fit_corner(rows,'top_left')
        self.assertEqual(r.get('selected_model',{}).get('family'),'piecewise_affine')
        direction=next(c['model'] for c in r['candidates'] if c['model']['family']=='direction_affine')
        self.assertEqual(direction['complexity'],6)

if __name__=='__main__':unittest.main()
