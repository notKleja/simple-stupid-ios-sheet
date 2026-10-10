#!/usr/bin/env python3
"""Preserve bounded evidence when guest API cannot export a large failed run."""
import base64,gzip,hashlib,json
from pathlib import Path
from vphone_run import rpc,ROOT

socket='/Users/kleja/.vphone/machines/pinterest-analysis/vphone.sock'
data=rpc(socket,'apps.data_dir',{'bundle_id':'dev.notkleja.NativeSheetHarness'})['data_path']
entries=rpc(socket,'files.list',{'path':data+'/Documents'})['entries']
entry=max([e for e in entries if e['name'].startswith('native.nonmodal.medium-')],key=lambda e:e['mtime'])
reply=rpc(socket,'files.read',{'path':entry['path'],'binary':True,'limit':10000000})
raw=base64.b64decode(reply['content']);complete_lines=raw[:raw.rfind(b'\n')+1]
out=ROOT/'artifacts/native/interactions/vphone_nonmodal_delivery_failure';out.mkdir(parents=True,exist_ok=True)
path=out/'native-prefix.jsonl.gz'
with gzip.open(path,'wb') as stream:stream.write(complete_lines)
rows=[json.loads(l) for l in complete_lines.splitlines()]
manifest={'schema_version':1,'status':'FAILED_NOT_ACCEPTED','reason':'API point/pixel taps returnedsuccess but no native touch delivery/control action observed',
    'raw_guest_file':entry,'export':'bounded complete-line prefix only; full raw remains in guest',
    'prefix':{'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()},
    'run_id':rows[0]['run_id'],'os':rows[0]['os'],'device':rows[0]['device'],'provenance':rows[0].get('provenance'),
    'prefix_touch_events':sum(r.get('name')=='input.touch' for r in rows),'prefix_control_actions':sum(r.get('name')=='background.control.activated' for r in rows),
    'limitation':'Prefix cannot assert absence over unexported tail; current AX controls unchanged, no terminal completion', 'terminal':False}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'manifest':str(out/'manifest.json'),'touches':manifest['prefix_touch_events'],'accepted':False}))
rpc(socket,'apps.terminate',{'bundle_id':'dev.notkleja.NativeSheetHarness'})
