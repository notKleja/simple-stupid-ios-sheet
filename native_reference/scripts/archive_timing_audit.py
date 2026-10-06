#!/usr/bin/env python3
"""Keep diagnostic audit bytes; never promote a single audited run."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser();parser.add_argument('source');args=parser.parse_args()
source=Path(args.source);raw=source.read_bytes();rows=[json.loads(line) for line in raw.splitlines()]
out=ROOT/'artifacts/native/timing/coalescing_diagnostic';out.mkdir(parents=True,exist_ok=True)
dest=out/(source.name+'.gz');compressed=gzip.compress(raw,mtime=0)
if dest.exists() and dest.read_bytes()!=compressed: raise ValueError('existing immutable diagnostic differs')
dest.write_bytes(compressed)
audits=[r for r in rows if r.get('name') in ('scheduler.audit','recorder.io')]
manifest={'schema_version':1,'status':'diagnostic_not_accepted','path':str(dest.relative_to(ROOT)),
    'sha256':hashlib.sha256(compressed).hexdigest(),'raw_sha256':hashlib.sha256(raw).hexdigest(),
    'session':rows[0],'audits':audits,'limitations':['One instrumented run; recorder.io itself changes recording workload','Retain actual timestamps; no offset correction','This is diagnosis, not a native motion profile']}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'manifest':str(out/'manifest.json'),'audit_events':len(audits)}))
