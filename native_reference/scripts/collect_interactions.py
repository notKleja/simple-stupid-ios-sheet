#!/usr/bin/env python3
"""Archive exact native interaction attempts and immutable source hashes."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
from interaction_validation import nonmodal_outcomes

ROOT=Path(__file__).resolve().parents[2]

def main():
    p=argparse.ArgumentParser();p.add_argument('udid');p.add_argument('--scenario',required=True);p.add_argument('--output',required=True);p.add_argument('--status',default='diagnostic',choices=['diagnostic','accepted','failed']);a=p.parse_args()
    container=Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.udid,'dev.notkleja.NativeSheetHarness','data'],text=True).strip())/'Documents'
    out=ROOT/a.output;out.mkdir(parents=True,exist_ok=True)
    entries=[]
    for path in sorted(container.glob(a.scenario+'-*.jsonl')):
        raw=path.read_bytes();rows=[json.loads(l) for l in raw.splitlines()];head=rows[0]
        entry={'run_id':head['run_id'],'trial':head['configuration']['trial'],'attempt_id':head.get('provenance',{}).get('attempt_id'),'role':head.get('provenance',{}).get('role'),'native_source_revision':head.get('provenance',{}).get('native_source_revision'), 'terminal':any(r.get('name')=='dismiss.completed' for r in rows)}
        name=path.name+'.gz';dest=out/name
        with gzip.open(dest,'wb') as f:f.write(raw)
        entry.update(path=str(dest.relative_to(ROOT)),sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),raw_sha256=hashlib.sha256(raw).hexdigest())
        try:
            if a.scenario=='native.nonmodal.medium':entry['outcomes']=nonmodal_outcomes(rows)
        except ValueError as error:entry['failure']=str(error)
        entries.append(entry)
    manifest={'schema_version':1,'scenario_id':a.scenario,'status':a.status,'collection_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'entries':entries,'limitations':['Pilot/source-uncommitted attempts cannot become accepted native timing evidence','All collected failures and unavailable states retained']}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'manifest':str(out/'manifest.json'),'attempts':len(entries),'status':a.status}))

if __name__=='__main__':main()
