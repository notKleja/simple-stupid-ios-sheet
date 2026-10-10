#!/usr/bin/env python3
"""Validate frozen bytes before publishing model-only radius capability."""
import argparse
import hashlib
import json
from pathlib import Path
from geometry_cohort import validate_manifest

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('manifests',nargs='+');a=p.parse_args()
cohorts=[];issues=[]
for name in a.manifests:
    path=ROOT/name;manifest=json.loads(path.read_text());summary=None
    try:
        if manifest['status']!='measured_model_radii_contour_unresolved':raise ValueError(manifest.get('failure') or 'unqualified preserved attempt')
        summary=validate_manifest(manifest,ROOT)
        if summary!=manifest['summary']:raise ValueError('Declared summary differs from hashed observations')
    except (ValueError,KeyError,TypeError,OSError) as error:issues.append({'manifest':name,'reason':str(error)})
    cohorts.append({'manifest':name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'status':manifest['status'],'summary':summary})
majors={c['summary']['session']['os']['version'].split('.')[0] for c in cohorts if c['summary']}
valid=len(cohorts)==2 and not issues and majors=={'26','27'}
result={'schema_version':1,'capability_status':'measured_model_radii_contour_unresolved' if valid else 'unresolved_failed_cohort',
    'cohorts':cohorts,'issues':issues,'rendered_contour_accepted':False,'scalar_radius_accepted':False,'flutter_parity_proven':False,
    'analysis_source_hashes':{str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in [Path(__file__),ROOT/'native_reference/scripts/geometry_cohort.py']}}
(ROOT/'native_reference/geometry_measurements.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'capability_status':result['capability_status'],'issues':issues,'cohorts':len(cohorts)}))
raise SystemExit(0 if valid else 1)
