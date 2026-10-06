#!/usr/bin/env python3
"""Recheck exact compressed/raw hashes and scoped ten-trial acceptance."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
from evidence_contract import require
from interaction_validation import validate_interaction_cohort

ROOT=Path(__file__).resolve().parents[2]

def validate_manifest(path):
    manifest=json.loads(Path(path).read_text())
    require(manifest['status']=='accepted','manifest is not accepted')
    require(manifest.get('acceptance_scope')=='observed_control_and_scroll_outcomes_only' and manifest.get('full_trajectory_acceptance') is False,'explicit scoped acceptance required')
    runs=[]
    for entry in manifest['entries']:
        source=ROOT/entry['path'];compressed=source.read_bytes();raw=gzip.decompress(compressed)
        require(hashlib.sha256(compressed).hexdigest()==entry['sha256'],'compressed hash mismatch')
        require(hashlib.sha256(raw).hexdigest()==entry['raw_sha256'],'raw hash mismatch')
        rows=[json.loads(line) for line in raw.splitlines()];head=rows[0]
        for key,value in [('run_id',head['run_id']),('trial',head['configuration']['trial']),('attempt_id',head['provenance']['attempt_id']),('role',head['provenance']['role']),('native_source_revision',head['provenance']['native_source_revision'])]:
            require(entry[key]==value,'declared identity mismatch: '+key)
        require(head['scenario_id']==manifest['scenario_id'],'scenario mismatch');runs.append(rows)
    reports=validate_interaction_cohort(runs)
    require(all(e['observations']==r for e,r in zip(manifest['entries'],reports)),'declared observation mismatch')
    return {'integrity':'PASS','artifacts':len(runs),'scenario_id':manifest['scenario_id'],'scope':'observed_control_and_scroll_outcomes_only'}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('manifest');args=parser.parse_args()
    try: print(json.dumps(validate_manifest(args.manifest)))
    except (ValueError,KeyError,TypeError,OSError) as error: print(json.dumps({'integrity':'FAIL','issue':str(error)}));raise SystemExit(1)
