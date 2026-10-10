#!/usr/bin/env python3
"""Archive exact native interaction attempts and immutable source hashes."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
from interaction_validation import nonmodal_outcomes, validate_interaction_cohort, validate_interaction_run

ROOT=Path(__file__).resolve().parents[2]

def main():
    p=argparse.ArgumentParser();p.add_argument('udid');p.add_argument('--scenario',required=True);p.add_argument('--output',required=True);p.add_argument('--status',default='diagnostic',choices=['diagnostic','accepted','failed']);source=p.add_mutually_exclusive_group();source.add_argument('--source-revision');source.add_argument('--source-marker',help='Exact unresolved marker, for failed/diagnostic preservation only');p.add_argument('--exclude-manifest',action='append',default=[],help='Preserved earlier full attempt, not individual outcome filtering');a=p.parse_args()
    if a.source_marker and a.status=='accepted': p.error('unresolved source marker cannot request acceptance')
    if a.source_revision:
        a.source_revision=subprocess.check_output(['git','rev-parse','--verify',a.source_revision+'^{commit}'],cwd=ROOT,text=True).strip()
    container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,'dev.notkleja.NativeSheetHarness','data'],text=True).strip())/'Documents'
    excluded=set()
    for manifest in a.exclude_manifest:
        excluded.update(e['run_id'] for e in json.loads((ROOT/manifest).read_text())['entries'])
    out=ROOT/a.output;out.mkdir(parents=True,exist_ok=True)
    entries=[];runs=[]
    for path in sorted(container.glob(a.scenario+'-*.jsonl')):
        with path.open() as stream: head=json.loads(stream.readline())
        if a.source_revision and head.get('provenance',{}).get('native_source_revision')!=a.source_revision: continue
        if a.source_marker and head.get('provenance',{}).get('native_source_revision')!=a.source_marker: continue
        if head['run_id'] in excluded: continue
        raw=path.read_bytes();rows=[json.loads(l) for l in raw.splitlines()]
        entry={'run_id':head['run_id'],'trial':head['configuration']['trial'],'attempt_id':head.get('provenance',{}).get('attempt_id'),'role':head.get('provenance',{}).get('role'),'native_source_revision':head.get('provenance',{}).get('native_source_revision'), 'terminal':any(r.get('name')=='dismiss.completed' for r in rows)}
        name=path.name+'.gz';dest=out/name
        compressed=gzip.compress(raw,mtime=0)
        if dest.exists() and dest.read_bytes()!=compressed: raise ValueError('immutable artifact already exists with different bytes: '+str(dest))
        if not dest.exists(): dest.write_bytes(compressed)
        entry.update(path=str(dest.relative_to(ROOT)),sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),raw_sha256=hashlib.sha256(raw).hexdigest())
        try:
            if a.scenario=='native.nonmodal.medium':entry['outcomes']=nonmodal_outcomes(rows)
            if a.status=='accepted':entry['observations']=validate_interaction_run(rows)
        except ValueError as error:entry['failure']=str(error)
        entries.append(entry)
        runs.append(rows)
    status=a.status;issues=([f'Unresolved runtime source marker: {a.source_marker}'] if a.source_marker else [])
    if status=='accepted':
        try:
            reports=validate_interaction_cohort(runs)
            for entry,report in zip(entries,reports): entry['observations']=report
        except (ValueError,KeyError,TypeError) as error:
            status='failed';issues.append(str(error))
    manifest={'schema_version':1,'scenario_id':a.scenario,'status':status,'selection':{'source_revision':a.source_revision,'source_marker':a.source_marker,'excluded_attempt_manifests':a.exclude_manifest,'excluded_run_ids':sorted(excluded)},'acceptance_scope':'observed_control_and_scroll_outcomes_only','full_trajectory_acceptance':False,'requested_status':a.status,'issues':issues,'collection_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'entries':entries,'limitations':['Acceptance is scoped to actual control/scroll outcomes; no full dynamics or private ownership accepted','Pilot/source-uncommitted attempts cannot become accepted native timing evidence','All collected failures and unavailable states retained']}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'manifest':str(out/'manifest.json'),'attempts':len(entries),'status':status,'issues':issues}))
    return 1 if a.status=='accepted' and status!='accepted' else 0

if __name__=='__main__':raise SystemExit(main())
