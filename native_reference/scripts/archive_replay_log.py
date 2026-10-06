#!/usr/bin/env python3
"""Archive final XCTest logs and observed build bytes, not a success assertion."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('log');p.add_argument('--name',required=True);p.add_argument('--products',required=True);p.add_argument('--source',required=True);a=p.parse_args()
revision=subprocess.check_output(['git','rev-parse','--verify',a.source+'^{commit}'],cwd=ROOT,text=True).strip()
raw=(ROOT/a.log).read_bytes();text=raw.decode();out=ROOT/'artifacts/native/interactions/replay_logs';out.mkdir(parents=True,exist_ok=True)
dest=out/(a.name+'.log.gz');compressed=gzip.compress(raw,mtime=0)
if dest.exists() and dest.read_bytes()!=compressed: raise ValueError('final log already archived with different bytes')
dest.write_bytes(compressed)
products=ROOT/a.products
files=[products/'NativeSheetHarness.app/NativeSheetHarness',products/'NativeInteractionUITests-Runner.app/PlugIns/NativeInteractionUITests.xctest/NativeInteractionUITests',products/'NativeInteractionUITests-Runner.app/PlugIns/NativeInteractionUITests.xctest/Info.plist']
manifest={'schema_version':1,'source_revision':revision,'log_path':str(dest.relative_to(ROOT)),'log_sha256':hashlib.sha256(compressed).hexdigest(),'raw_log_sha256':hashlib.sha256(raw).hexdigest(),
    'test_case_results':re.findall(r"Test Case '[^\n]+(?:passed|failed) \([^\n]+",text),
    'execution_summaries':re.findall(r'Executed [^\n]+',text),
    'xcodebuild_succeeded':'** TEST EXECUTE SUCCEEDED **' in text,
    'observed_build_files':[{'path':str(file.relative_to(ROOT)),'sha256':hashlib.sha256(file.read_bytes()).hexdigest()} for file in files],
    'limitations':['XCTest success is not full native trajectory acceptance','Accepted cohorts separately validate actual delivered outcomes, source header and terminal integrity']}
(out/(a.name+'.json')).write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest))
