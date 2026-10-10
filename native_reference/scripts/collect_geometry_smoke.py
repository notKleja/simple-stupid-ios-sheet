#!/usr/bin/env python3
"""Exactly one diagnostic trial; preserves raw bytes and truthful uncommitted-source pins."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
from validate_geometry_smoke import validate_smoke

ROOT=Path(__file__).resolve().parents[2]
BUNDLE='dev.notkleja.NativeSheetHarness'

def digest(raw): return hashlib.sha256(raw).hexdigest()
def sim(*args,env=None): return subprocess.check_output(['xcrun','simctl',*args],text=True,env=env).strip()

def main():
    p=argparse.ArgumentParser();p.add_argument('udid');p.add_argument('--output',required=True);a=p.parse_args()
    inventory=json.loads(sim('list','-j'))
    runtime_id=next(k for k,v in inventory['devices'].items() if any(d['udid']==a.udid for d in v))
    runtime=next(r for r in inventory['runtimes'] if r['identifier']==runtime_id)
    if not runtime['version'].startswith('26.'):raise ValueError('Only the requested iOS26 smoke is authorized')
    sources=sorted((ROOT/'native_reference/NativeSheetHarness').glob('*.swift'))+[ROOT/'native_reference/NativeSheetHarness/Info.plist']
    source_hashes={str(p.relative_to(ROOT)):digest(p.read_bytes()) for p in sources}
    binary=ROOT/'build/native/iphonesimulator/NativeSheetHarness.app/NativeSheetHarness'
    sim('bootstatus',a.udid,'-b')
    subprocess.run(['xcrun','simctl','terminate',a.udid,BUNDLE],capture_output=True)
    sim('install',a.udid,str(binary.parent))
    container=Path(sim('get_app_container',a.udid,BUNDLE,'data'))/'Documents'
    before=set(container.glob('native.geometry.smoke-*.jsonl'))
    env=dict(os.environ,SIMCTL_CHILD_NATIVE_AUTORUN='1',SIMCTL_CHILD_NATIVE_TRIALS='1',
        SIMCTL_CHILD_NATIVE_SCENARIO='native.geometry.smoke',SIMCTL_CHILD_NATIVE_OS_BUILD=runtime['buildversion'],
        SIMCTL_CHILD_NATIVE_ROLE='diagnostic',
        SIMCTL_CHILD_NATIVE_SOURCE_REVISION='uncommitted-task3a-source-files-pinned-by-manifest')
    start=time.monotonic();fresh=set()
    try:
        sim('launch',a.udid,BUNDLE,env=env)
        while time.monotonic()-start<20:
            fresh=set(container.glob('native.geometry.smoke-*.jsonl'))-before
            if len(fresh)==1 and '"batch.completed"' in next(iter(fresh)).read_text()[-700:]:break
            time.sleep(.25)
    finally:
        subprocess.run(['xcrun','simctl','terminate',a.udid,BUNDLE],capture_output=True)
    if len(fresh)!=1:raise ValueError('Expected exactly one new diagnostic trace; no retries performed')
    path=next(iter(fresh));raw=path.read_bytes();rows=[json.loads(l) for l in raw.splitlines()]
    out=ROOT/a.output;out.mkdir(parents=True,exist_ok=True)
    dest=out/(path.name+'.gz');compressed=gzip.compress(raw,mtime=0)
    if dest.exists() and dest.read_bytes()!=compressed:raise ValueError('Immutable smoke artifact differs')
    dest.write_bytes(compressed)
    result=None;failure=None
    try:result=validate_smoke(rows)
    except (ValueError,KeyError,TypeError) as error:failure=str(error)
    if source_hashes!={str(p.relative_to(ROOT)):digest(p.read_bytes()) for p in sources}:raise ValueError('Sources changed during smoke')
    manifest={'schema_version':1,'status':'diagnostic_not_accepted','source_base':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'source_state':'uncommitted; exact source file hashes pinned, not mislabeled as base commit implementation',
        'source_hashes':source_hashes,'binary_sha256':digest(binary.read_bytes()),'udid':a.udid,'runtime':runtime,
        'path':str(dest.relative_to(ROOT)),'sha256':digest(compressed),'raw_sha256':digest(raw),
        'session':rows[0],'collector_elapsed_s':time.monotonic()-start,'validation':result,'failure':failure,
        'limits':['One smoke only; no radius, contour, barrier or presenter acceptance','No native profile fitted or published','Only own harness app installed/launched/terminated; simulator not erased']}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'manifest':str(out/'manifest.json'),'validation':result,'failure':failure}))
    return 1 if failure else 0

if __name__=='__main__':raise SystemExit(main())
