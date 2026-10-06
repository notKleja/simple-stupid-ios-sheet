#!/usr/bin/env python3
"""Hash exact recollected timing inputs; never rewrite runtime records."""
import argparse,gzip,hashlib,json,statistics,subprocess
from pathlib import Path
from evidence_contract import read,validate_cohort

def main():
    p=argparse.ArgumentParser();p.add_argument('directory');p.add_argument('--source-revision',required=True);a=p.parse_args()
    revision=subprocess.check_output(['git','rev-parse','--verify',a.source_revision+'^{commit}'],text=True).strip()
    directory=Path(a.directory);paths=sorted(directory.glob('*.jsonl.gz'));runs=[read(path) for path in paths]
    validate_cohort(runs)
    entries=[];times=[[],[],[]]
    for path,rows in zip(paths,runs):
        h=rows[0];origin=next(r['t_ns'] for r in rows if r.get('name')=='present.requested')
        requests=[r for r in rows if r.get('name')=='detent.requested']+[r for r in rows if r.get('name')=='dismiss.requested']
        for i,row in enumerate(requests):times[i].append((row['t_ns']-origin)/1e6)
        entries.append({'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'run_id':h['run_id'],'trial':h['configuration']['trial'],
            'attempt_id':h['provenance']['attempt_id'],'role':'training','source_revision':revision,'terminal':any(r.get('name')=='dismiss.completed' for r in rows)})
    report={'schema_version':1,'scenario_id':runs[0][0]['scenario_id'],'status':'complete_resting_and_replay_timing_only',
        'source_revision':revision,'scheduler':'strict DispatchSourceTimer, zero requested leeway, shared present boundary',
        'entries':entries,'request_ms':[{'median':statistics.median(v),'min':min(v),'max':max(v)} for v in times],
        'limitations':['Actual raw command timestamps retained','Prior coalesced-timer cohorts invalid for nominal replay timing acceptance','Motion/shape/gesture calibration is separate','Raw header source marker unresolved in this recollection; build/collection revision pinned here without relabeling bytes']}
    (directory/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'manifest':str(directory/'manifest.json'),'trials':len(entries),'request_ms':report['request_ms']}))

if __name__=='__main__':main()
