"""Source-pinned model/configuration radius qualification, never rendered contour parity."""
import math
import gzip
import hashlib
import json
import re
import statistics
from evidence_contract import CONFIGURATION_KEYS, finite, identity, require

CORNERS=('top_left','top_right','bottom_left','bottom_right')
PHASES=('fixed320','medium_initial','large','medium_return')
DETECT=('fixed320','medium','large','medium')
BOUNDARIES=('present.requested','present.completed','detent.requested','detent.requested','detent.requested','dismiss.requested','dismiss.completed')

def validate_run(rows,source_hashes):
    require(bool(rows),'empty radius trace');head=rows[0]
    require(head.get('type')=='session' and head.get('native_contract_version')==2,'native recorder v2 session required')
    require(head.get('scenario_id')=='native.geometry.smoke' and head.get('implementation')=='native' and head.get('evidence_kind')=='runtime','explicit native geometry runtime required')
    require(str(head.get('os',{}).get('version','')).split('.')[0] in ('26','27') and bool(head['os'].get('build')),'observed OS26/27 build required')
    require(head.get('device',{}).get('runtime_kind')=='simulator','simulator model-radius cohort required')
    require(set(head.get('configuration',{}))==set(CONFIGURATION_KEYS),'exact effective configuration required')
    require(head.get('geometry_probe',{}).get('accepted') is False,'probe must not promote contour acceptance')
    provenance=head.get('provenance',{})
    require(provenance.get('source_hashes')==source_hashes,'exact observed source hashes required')
    require(provenance.get('role')=='training' and isinstance(provenance.get('attempt_id'),str) and provenance['attempt_id'],'independent training attempt required')
    require(isinstance(head.get('run_id'),str) and head['run_id'],'run ID required')
    hz=head['device'].get('refresh_hz');scale=head['device'].get('scale')
    require(finite(hz) and hz>0 and finite(scale) and scale>0,'positive native refresh/scale required')
    # Ceil only the integer-nanosecond representation, not a pacing tolerance.
    max_gap=math.ceil(2_000_000_000/hz)
    frames=[];events=[];previous=-1;previous_frame=-1
    for index,row in enumerate(rows):
        require(type(row.get('seq')) is int and row['seq']==index and row.get('schema_version')==1 and row.get('run_id')==head['run_id'],'complete envelope/sequence required')
        require(type(row.get('t_ns')) is int and row['t_ns']>=max(0,previous),'monotonic record time required');previous=row['t_ns']
        require(row.get('type') in ('session','event','frame') and (row['type']!='session' or index==0),'unknown/duplicate record')
        if row['type']=='event':
            require(row.get('name')!='run.error','failed attempt remains failed')
            require(row.get('name')!='input.touch','uncontrolled user input in programmatic cohort')
            events.append(row)
        elif row['type']=='frame':
            require(row['t_ns']>previous_frame,'frame timestamps must strictly increase');previous_frame=row['t_ns']
            require(all(row.get('metrics',{}).get(k) is None for k in ('sheet.radius','barrier.alpha')),'unvalidated scalar promoted')
            for section in ('metrics','state'):
                for key,value in row.get(section,{}).items():
                    if value is None:require(isinstance(row.get('unavailable',{}).get(key),str) and row['unavailable'][key].strip(),'null lacks unavailable reason')
            frames.append(row)
    terminal=[i for i,r in enumerate(rows) if r.get('terminal') is True]
    require(len(terminal)==1 and rows[terminal[0]].get('name')=='dismiss.completed','successful terminal required')
    require(all(r.get('name')=='batch.completed' for r in rows[terminal[0]+1:]),'observations after terminal')
    core=[e for e in events if e.get('name') in BOUNDARIES]
    require(tuple(e['name'] for e in core)==BOUNDARIES,'exact fixed320/medium/large/medium recipe required')
    require([e['data'].get('target') for e in core if e['name']=='detent.requested']==['medium','large','medium'],'old Task3A smoke is not a repeated radius trial')
    require(all(a['t_ns']<b['t_ns'] for a,b in zip(core,core[1:])),'strict boundary time required')
    windows={}
    for phase,selected,boundary in zip(PHASES,DETECT,core[2:6]):
        end=boundary['t_ns'];start=end-400_000_000
        window=[f for f in frames if start<=f['t_ns']<end]
        require(len(window)>=2,phase+': missing observation window')
        require(window[0]['t_ns']-start<=max_gap and end-window[-1]['t_ns']<=max_gap,phase+': incomplete window endpoints')
        require(all(b['t_ns']-a['t_ns']<=max_gap for a,b in zip(window,window[1:])),phase+': gap exceeds two native frames')
        ids=None
        for frame in window:
            require(frame.get('state',{}).get('selected_detent')==selected,phase+': observed detent mismatch')
            probe=frame.get('geometry_probe',{})
            require(probe.get('schema_version')==1 and probe.get('accepted') is False and not probe.get('descendant_traversal_truncated',False),'complete diagnostic probe required')
            candidates=probe.get('sheet_candidates',[])
            actual=[c.get('id') for c in candidates]
            require(bool(actual) and all(isinstance(v,str) and v for v in actual) and len(set(actual))==len(actual),'unique public candidate IDs required')
            require(ids is None or actual==ids,phase+': candidate-ID churn');ids=actual
            for candidate in candidates:
                values=candidate.get('effective_radii_model',{})
                require(set(values)==set(CORNERS) and all(finite(v) and v>=0 for v in values.values()),'four independent nonnegative model radii required')
                config=candidate.get('corner_configuration',{})
                require(config.get('present') is True and isinstance(config.get('description_diagnostic_only'),str),'observed configuration description required')
        windows[phase]=window
    return windows

def validate_cohort(runs,source_hashes):
    require(isinstance(source_hashes,dict) and bool(source_hashes) and all(isinstance(k,str) and isinstance(v,str) and re.fullmatch('[a-f0-9]{64}',v) for k,v in source_hashes.items()),'content-addressed source hash set required')
    require(len(runs)==10,'exactly ten independent artifacts required')
    windows=[validate_run(r,source_hashes) for r in runs];heads=[r[0] for r in runs]
    require(len({h['run_id'] for h in heads})==10,'unique run IDs required')
    require(all(type(h['configuration']['trial']) is int for h in heads) and {h['configuration']['trial'] for h in heads}==set(range(1,11)),'unique trial IDs1..10 required')
    require(len({h['provenance']['attempt_id'] for h in heads})==10,'unique attempt IDs required')
    require(all(identity(h)==identity(heads[0]) for h in heads),'mixed OS/device/environment/configuration')
    for phase in PHASES:
        ids=[c['id'] for c in windows[0][phase][0]['geometry_probe']['sheet_candidates']]
        require(all([c['id'] for c in w[phase][0]['geometry_probe']['sheet_candidates']]==ids for w in windows),'candidate IDs differ between independent trials')
    return windows

def summarize(runs,source_hashes):
    windows=validate_cohort(runs,source_hashes);phases={};scale=runs[0][0]['device']['scale']
    for phase in PHASES:
        phases[phase]={}
        ids=[c['id'] for c in windows[0][phase][0]['geometry_probe']['sheet_candidates']]
        for candidate_id in ids:
            trials=[[next(c for c in f['geometry_probe']['sheet_candidates'] if c['id']==candidate_id) for f in w[phase]] for w in windows]
            corners={}
            for corner in CORNERS:
                samples=[c['effective_radii_model'][corner] for trial in trials for c in trial]
                medians=[statistics.median(c['effective_radii_model'][corner] for c in trial) for trial in trials]
                residuals=[abs(v*scale-round(v*scale)) for v in samples]
                corners[corner]={'median':statistics.median(medians),'min':min(samples),'max':max(samples),
                    'stddev_population':statistics.pstdev(medians),'trial_medians':medians,
                    'physical_pixel_quantization':{'display_scale':scale,'min_integer_pixel_residual':min(residuals),
                        'max_integer_pixel_residual':max(residuals),'coordinate_system':'model_local_points_times_scale_not_rendered_radius',
                        'source_values_rounded':False}}
            phases[phase][candidate_id]={'corners':corners,'configuration_descriptions':sorted({c['corner_configuration']['description_diagnostic_only'] for trial in trials for c in trial})}
    return {'schema_version':1,'capability_status':'measured_model_radii_contour_unresolved','source_hashes':source_hashes,
        'session':runs[0][0],'trial_count':10,'phases':phases,'rendered_contour_accepted':False,'barrier_accepted':False,'presenter_accepted':False,
        'statistics_method':'median and population dispersion of ten independent trial medians; min/max and pixel residuals over observed window samples',
        'limits':['Four corners never collapsed to one scalar','Model/configuration parameters are not rendered contour or Flutter parity','Configuration descriptions are raw diagnostic strings, not private-class selection rules']}

def validate_manifest(manifest,root):
    require(manifest.get('schema_version')==1 and isinstance(manifest.get('entries'),list),'versioned artifact manifest required')
    runs=[]
    for entry in manifest['entries']:
        require(entry.get('status') not in ('failed','partial','unsupported'),'failed producer attempt is not promoted')
        compressed=(root/entry['path']).read_bytes()
        require(hashlib.sha256(compressed).hexdigest()==entry['sha256'],'compressed artifact hash mismatch')
        raw=gzip.decompress(compressed)
        require(hashlib.sha256(raw).hexdigest()==entry['raw_sha256'],'raw artifact hash mismatch')
        rows=[json.loads(line) for line in raw.splitlines()];head=rows[0]
        require(entry['run_id']==head['run_id'] and entry['trial']==head['configuration']['trial'] and entry['attempt_id']==head['provenance']['attempt_id'],'declared artifact identity differs from observed header')
        runs.append(rows)
    return summarize(runs,manifest['source_hashes'])
