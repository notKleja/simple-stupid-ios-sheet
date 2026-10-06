#!/usr/bin/env python3
"""Index only validated ten-trial observations; retain raw failures separately."""
import argparse
import hashlib
import json
from pathlib import Path
from validate_interactions import validate_manifest
from evidence_contract import require

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser();parser.add_argument('manifests',nargs='+');args=parser.parse_args()
cohorts=[];seen_runs=set();seen_paths=set()
for name in args.manifests:
    path=ROOT/name;validated=validate_manifest(path);manifest=json.loads(path.read_text())
    entries=manifest['entries'];reports=[e['observations'] for e in entries]
    require(name not in seen_paths,'duplicate cohort manifest');seen_paths.add(name)
    for entry in entries:
        require(entry['run_id'] not in seen_runs,'run reused across cohorts');seen_runs.add(entry['run_id'])
    cohort={'manifest':name,'manifest_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'integrity':validated,
        'source_revision':entries[0]['native_source_revision'],'role':entries[0]['role'],
        'max_frame_gap_ns':max(r['max_frame_gap_ns'] for r in reports),
        'unavailable_sheet_y_frames':sum(r['unavailable_sheet_y_frames'] for r in reports),
        'zero_sheet_y_frames':sum(r['zero_sheet_y_frames'] for r in reports)}
    if manifest['scenario_id']=='native.nonmodal.medium':
        cohort['activated_trials_by_phase']={phase:sum(next(p['activated'] for p in r['probes'] if p['phase']==phase) for r in reports) for phase in ('medium_initial','large','medium_return')}
    else:
        for key in ('scroll_start','scroll_end','scroll_min','scroll_max','delivered_drag_events','finger_velocity_samples','probe_max_frame_gap_ns'):
            values=[r[key] for r in reports];cohort[key]={'min':min(values),'max':max(values)}
        cohort['selected_detents_by_trial']={str(e['trial']):e['observations']['selected_detents'] for e in entries}
        cohort['sheet_y_observed_ranges_by_trial']={str(e['trial']):e['observations']['sheet_y_observed_range'] for e in entries}
    cohorts.append(cohort)
result={'schema_version':1,'acceptance_scope':'observed_control_and_scroll_outcomes_only','full_trajectory_acceptance':False,
    'cohorts':cohorts,'accepted_trials':sum(c['integrity']['artifacts'] for c in cohorts),
    'limitations':['Training evidence only; no holdout outcome claims','Private scroll ownership unresolved; derived movement consumers are not ownership','Sampler gaps and y0 anomalies retained, not accepted as native motion','underlying_hit_test stores last completed probe outcome, not a continuous hit-test mask']}
result['preserved_nonaccepted_manifests']=[]
for path in sorted((ROOT/'artifacts/native/interactions').glob('*/manifest.json')):
    manifest=json.loads(path.read_text())
    if manifest.get('status')!='accepted':
        result['preserved_nonaccepted_manifests'].append({'manifest':str(path.relative_to(ROOT)),
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'status':manifest.get('status'),
            'listed_artifacts':len(manifest.get('entries',[])),'issues':manifest.get('issues',[])})
destination=ROOT/'native_reference/interaction_measurements.json';destination.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'index':str(destination),'cohorts':len(cohorts),'accepted_trials':result['accepted_trials']}))
