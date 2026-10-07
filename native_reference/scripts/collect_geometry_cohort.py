#!/usr/bin/env python3
"""One complete ten-trial attempt per invocation. Never filters failures into a passing cohort."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
from geometry_cohort import validate_run,validate_cohort,summarize

ROOT=Path(__file__).resolve().parents[2]
BUNDLE='dev.notkleja.NativeSheetHarness'
def digest(raw):return hashlib.sha256(raw).hexdigest()
def sim(*args,env=None):return subprocess.check_output(['xcrun','simctl',*args],text=True,env=env).strip()
def sources():
    files=sorted((ROOT/'native_reference/NativeSheetHarness').glob('*.swift'))+[ROOT/'native_reference/NativeSheetHarness/Info.plist']
    return {str(p.relative_to(ROOT)):digest(p.read_bytes()) for p in files}
def tail(path):
    with path.open('rb') as stream:
        stream.seek(max(0,path.stat().st_size-1000));return stream.read().decode(errors='replace')
def terminate(udid):
    result=subprocess.run(['xcrun','simctl','terminate',udid,BUNDLE],capture_output=True,text=True)
    return {'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr}

def main():
    p=argparse.ArgumentParser();p.add_argument('udid');p.add_argument('--output',required=True);a=p.parse_args()
    out=ROOT/a.output
    if out.exists():raise ValueError('Attempt directory already exists; refuse a hidden retry/overwrite')
    out.mkdir(parents=True)
    inventory=json.loads(sim('list','-j'))
    runtime_id=next(k for k,v in inventory['devices'].items() if any(d['udid']==a.udid for d in v))
    runtime=next(r for r in inventory['runtimes'] if r['identifier']==runtime_id)
    if runtime['version'].split('.')[0] not in ('26','27'):raise ValueError('Only OS26/27 model-radius cohorts are authorized')
    pins=sources();binary=ROOT/'build/native/iphonesimulator/NativeSheetHarness.app/NativeSheetHarness'
    binary_hash=digest(binary.read_bytes());sim('bootstatus',a.udid,'-b')
    lifecycle={'before':terminate(a.udid)};sim('install',a.udid,str(binary.parent))
    container=Path(sim('get_app_container',a.udid,BUNDLE,'data'))/'Documents'
    before=set(container.glob('native.geometry.smoke-*.jsonl'))
    env=dict(os.environ,SIMCTL_CHILD_NATIVE_AUTORUN='1',SIMCTL_CHILD_NATIVE_TRIALS='10',SIMCTL_CHILD_NATIVE_ROLE='training',
        SIMCTL_CHILD_NATIVE_SCENARIO='native.geometry.smoke',SIMCTL_CHILD_NATIVE_OS_BUILD=runtime['buildversion'],
        SIMCTL_CHILD_NATIVE_SOURCE_REVISION='uncommitted-task3b-source-files-pinned-by-manifest',SIMCTL_CHILD_NATIVE_GEOMETRY_SOURCE_HASHES=json.dumps(pins))
    start=time.monotonic();fresh=set();failure=None;batch_completed=False
    try:
        sim('launch',a.udid,BUNDLE,env=env)
        while time.monotonic()-start<120:
            fresh=set(container.glob('native.geometry.smoke-*.jsonl'))-before
            if len(fresh)==10 and any('"batch.completed"' in tail(path) for path in fresh):batch_completed=True;break
            time.sleep(.25)
        if not batch_completed:failure='No complete ten-trial batch within120s; no retry performed'
    except Exception as error:failure=str(error)
    finally:
        lifecycle['after']=terminate(a.udid)
        fresh=set(container.glob('native.geometry.smoke-*.jsonl'))-before
    entries=[];runs=[]
    for path in sorted(fresh):
        raw=path.read_bytes();data=gzip.compress(raw,mtime=0);rows=None;issue=None
        try:
            rows=[json.loads(line) for line in raw.splitlines()];validate_run(rows,pins)
        except (ValueError,KeyError,TypeError) as error:issue=str(error)
        category='failed' if issue else 'traces';dest=out/category/(path.name+'.gz');dest.parent.mkdir(exist_ok=True);dest.write_bytes(data)
        head=rows[0] if rows else {}
        entry={'path':str(dest.relative_to(ROOT)),'sha256':digest(data),'raw_sha256':digest(raw),'status':'failed' if issue else 'model_window_complete',
            'failure':issue,'run_id':head.get('run_id'),'trial':head.get('configuration',{}).get('trial'),'attempt_id':head.get('provenance',{}).get('attempt_id')}
        entries.append(entry)
        if rows:runs.append(rows)
    summary=None
    try:
        if failure:raise ValueError(failure)
        if pins!=sources() or binary_hash!=digest(binary.read_bytes()):raise ValueError('Source/build bytes changed during collection')
        validate_cohort(runs,pins);summary=summarize(runs,pins)
    except (ValueError,KeyError,TypeError) as error:failure=str(error)
    manifest={'schema_version':1,'status':'measured_model_radii_contour_unresolved' if summary else 'failed_attempt_preserved',
        'source_base':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_state':'uncommitted source files pinned by exact hashes, not mislabeled as base implementation',
        'source_hashes':pins,'binary_sha256':binary_hash,'udid':a.udid,'runtime':runtime,'entries':entries,'summary':summary,
        'collector_elapsed_s':time.monotonic()-start,'batch_completed':batch_completed,'lifecycle':lifecycle,'failure':failure,
        'limits':['Ten independent run/trial/attempt IDs; no prior Task3A smoke reused','Every failed trial remains in this full attempt; no favorable substitution','Model/configuration radii only; canonical radius/contour/barrier/presenter acceptance unchanged']}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (out/'inventory.json').write_text(json.dumps(inventory,indent=2)+'\n')
    print(json.dumps({'manifest':str(out/'manifest.json'),'status':manifest['status'],'artifacts':len(entries),'failure':failure}))
    return 0 if summary else 1

if __name__=='__main__':raise SystemExit(main())
