"""Actual delivery/outcome controls; alpha is never an interaction observation."""
import re
from collections import Counter
from evidence_contract import CONFIGURATION_KEYS, canonical_id, finite, identity, require

SCENARIOS = {'native.nonmodal.medium','native.scroll.medium_large','native.scroll.content_first','native.scroll.handoff.down'}

def nonmodal_outcomes(rows):
    probes = []
    current = None
    for row in rows:
        if row.get("type") != "event": continue
        name, data = row.get("name"), row.get("data", {})
        if name == "background.probe.requested":
            if current is not None: raise ValueError("Unclosed background probe")
            current = {"phase": data["phase"], "before": data["activation_before"], "touches": 0, "activations": []}
        elif name == "input.touch" and current is not None:
            current["touches"] += 1
        elif name == "background.control.activated" and current is not None:
            current['activations'].append(data.get('count'))
        elif name == "background.probe.completed":
            if current is None or current["phase"] != data["phase"]: raise ValueError("Probe boundary mismatch")
            delivery = data.get("delivered_target_touch_events")
            if type(delivery) is not int or delivery <= 0 or current["touches"] == 0:
                raise ValueError("No actual delivered touch in requested background region")
            delta = data["activation_after"] - current["before"]
            if delta not in (0,1): raise ValueError("Ambiguous activation delta")
            if current['activations'] != ([data['activation_after']] if delta else []):
                raise ValueError('Counter disagrees with actual control activation events')
            probes.append({"phase": current["phase"], "activated": delta == 1, "delivered_touch_events": delivery})
            current = None
    if current is not None or not probes: raise ValueError("Missing complete actual touch probes")
    return probes

def validate_interaction_run(rows):
    require(bool(rows), 'empty interaction trace')
    head=rows[0]
    require(head.get('type')=='session' and head.get('native_contract_version')==2, 'canonical v2 session required')
    require(head.get('implementation')=='native' and head.get('evidence_kind')=='runtime', 'native runtime evidence required')
    require(head.get('scenario_id') in SCENARIOS, 'unsupported interaction scenario')
    require(isinstance(head.get('run_id'),str) and head['run_id'], 'run ID required')
    require(all(isinstance(head.get('os',{}).get(k),str) and head['os'][k].strip() for k in ('version','build')), 'observed OS/build required')
    require(head.get('device',{}).get('runtime_kind') in ('simulator','virtual_device','physical_device'), 'runtime provenance required')
    device=head['device'];environment=head.get('environment',{})
    require(isinstance(device.get('model'),str) and device['model'], 'observed device model required')
    for key in ('logical_size','physical_size'):
        require(isinstance(device.get(key),dict) and all(finite(device[key].get(axis)) and device[key][axis]>0 for axis in ('width','height')), 'positive device dimensions required')
    require(all(finite(device.get(key)) and device[key]>0 for key in ('scale','refresh_hz')), 'scale/refresh capability required')
    require(environment.get('orientation') in ('portrait','landscape','portrait_upside_down'), 'observed orientation required')
    require(all(finite(environment.get('safe_area',{}).get(k)) and environment['safe_area'][k]>=0 for k in ('top','left','bottom','right')), 'complete safe area required')
    require(all(environment.get('size_classes',{}).get(k) in ('compact','regular','unspecified') for k in ('horizontal','vertical')), 'complete size classes required')
    require(isinstance(environment.get('status_bar'),dict) and type(environment['status_bar'].get('hidden')) is bool, 'observed status bar required')
    keyboard=environment.get('keyboard',{})
    require(type(keyboard.get('visible')) is bool and isinstance(keyboard.get('frame'),dict) and all(finite(keyboard['frame'].get(k)) for k in ('x','y','width','height')), 'observed keyboard metadata required')
    require(all(k in head.get('configuration',{}) for k in CONFIGURATION_KEYS), 'complete effective configuration required')
    provenance=head.get('provenance',{})
    require(isinstance(provenance.get('attempt_id'),str) and provenance['attempt_id'], 'attempt ID required')
    require(provenance.get('role') in ('training','holdout'), 'training/holdout role required')
    require(re.fullmatch('[0-9a-f]{40}',provenance.get('native_source_revision','')) is not None, 'immutable source revision required')
    previous_seq=previous_time=previous_frame=-1
    frames=[];events=[]
    for index,row in enumerate(rows):
        require(row.get('schema_version')==1 and row.get('run_id')==head['run_id'], 'envelope/run mismatch')
        require(type(row.get('seq')) is int and row['seq']>previous_seq, 'increasing sequence required')
        require(type(row.get('t_ns')) is int and row['t_ns']>=max(0,previous_time), 'monotonic timestamp required')
        previous_seq,previous_time=row['seq'],row['t_ns']
        require(row.get('type') in ('session','event','frame') and (row['type']!='session' or index==0), 'duplicate/unknown record')
        if row['type']=='event':
            require(row.get('name')!='run.error', 'recorder invalidated run')
            require(isinstance(row.get('data'),dict), 'event data required');events.append(row)
        elif row['type']=='frame':
            require(row['t_ns']>previous_frame, 'increasing frame times required');previous_frame=row['t_ns']
            for section in ('metrics','state'):
                require(isinstance(row.get(section),dict), 'frame fields required')
                for key,value in row[section].items():
                    if value is None:
                        reason=row.get('unavailable',{}).get(key)
                        require(isinstance(reason,str) and bool(reason.strip()), 'null lacks unavailable reason: '+key)
                    elif section=='metrics': require(finite(value), 'nonfinite metric')
            for key in ('selected_detent','target_detent'):
                value=row['state'].get(key);require(value==canonical_id(value), 'noncanonical detent')
            frames.append(row)
    require(len(frames)>=2, 'observed frames required')
    require(rows[-1].get('name')=='dismiss.completed' and rows[-1].get('terminal') is True, 'explicit terminal required')
    require(sum(e['name']=='dismiss.completed' for e in events)==1, 'duplicate terminal')
    require(sum(e['name']=='present.requested' for e in events)==1 and sum(e['name']=='present.completed' for e in events)==1, 'complete presentation boundaries required')
    gaps=[b['t_ns']-a['t_ns'] for a,b in zip(frames,frames[1:])]
    report={'scope':'observed_control_and_scroll_outcomes_only','max_frame_gap_ns':max(gaps,default=0),
        'unavailable_sheet_y_frames':sum(f['metrics'].get('sheet.y') is None for f in frames),
        'zero_sheet_y_frames':sum(f['metrics'].get('sheet.y')==0 for f in frames), 'private_scroll_owner':'unresolved', 'full_trajectory_acceptance':False}
    if head['scenario_id']=='native.nonmodal.medium':
        require(head['configuration']['largest_undimmed']=='medium', 'nonmodal medium threshold required')
        probes=nonmodal_outcomes(rows)
        require([p['phase'] for p in probes]==['medium_initial','large','medium_return'], 'complete ordered background phases required')
        report['probes']=probes
    else:
        require(head['configuration']['scroll_expansion']==(head['scenario_id']!='native.scroll.content_first'), 'scenario scroll policy mismatch')
        begin=[e for e in events if e['name']=='scroll.probe.requested'];end=[e for e in events if e['name']=='scroll.probe.completed']
        require(len(begin)==len(end)==1 and begin[0]['t_ns']<end[0]['t_ns'], 'one complete scroll probe required')
        touched=[e for e in events if e['name']=='input.touch' and begin[0]['t_ns']<e['t_ns']<end[0]['t_ns']]
        observed=[f for f in frames if begin[0]['t_ns']<f['t_ns']<end[0]['t_ns']]
        require(len(touched)>=3 and any(e['data'].get('phase')==1 for e in touched), 'actual delivered drag samples required')
        offsets=[f['metrics'].get('scroll.offset') for f in observed]
        require(len(offsets)>=2 and all(finite(v) for v in offsets), 'actual scroll offsets required')
        require(any(finite(f['metrics'].get('scroll.pan_velocity_y')) for f in observed), 'native pan samples required')
        start,finish=begin[0]['data'].get('scroll_offset'),end[0]['data'].get('scroll_offset')
        require(finite(start) and finite(finish), 'actual boundary offsets required')
        report.update(scroll_start=start,scroll_end=finish,scroll_min=min(offsets),scroll_max=max(offsets),delivered_drag_events=len(touched),
            selected_detents=sorted({f['state']['selected_detent'] for f in observed if f['state'].get('selected_detent') is not None}))
        y=[f['metrics'].get('sheet.y') for f in observed if finite(f['metrics'].get('sheet.y'))]
        report['sheet_y_observed_range']={'min':min(y),'max':max(y)} if y else None
        report['movement_consumer_samples']=dict(Counter(f['state'].get('observed_movement_consumer','unavailable') for f in observed))
        report['finger_velocity_samples']=sum(finite(f['metrics'].get('finger.velocity_y')) for f in observed)
        report['probe_max_frame_gap_ns']=max((b['t_ns']-a['t_ns'] for a,b in zip(observed,observed[1:])),default=0)
    return report

def validate_interaction_cohort(runs):
    require(len(runs)==10, 'exactly ten interaction artifacts required')
    reports=[validate_interaction_run(rows) for rows in runs]
    heads=[rows[0] for rows in runs]
    require(len({h['run_id'] for h in heads})==10, 'unique run IDs required')
    require(all(type(h['configuration']['trial']) is int for h in heads) and set(h['configuration']['trial'] for h in heads)==set(range(1,11)), 'unique integer trials1..10 required')
    require(len({h['provenance']['attempt_id'] for h in heads})==10, 'unique attempts required')
    require(all(identity(h)==identity(heads[0]) for h in heads), 'mixed OS/device/config/environment cohort')
    require(all(h['provenance']['native_source_revision']==heads[0]['provenance']['native_source_revision'] and h['provenance']['role']==heads[0]['provenance']['role'] for h in heads), 'mixed source/role cohort')
    return reports
