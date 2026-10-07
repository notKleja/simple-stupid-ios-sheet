"""Diagnostic completeness only; never accepts a radius/contour/barrier profile."""
import argparse
import json
from evidence_contract import read, require, finite

def validate_smoke(rows):
    require(bool(rows),'empty diagnostic trace')
    head=rows[0]
    require(head.get('type')=='session' and head.get('scenario_id')=='native.geometry.smoke','explicit diagnostic scenario required')
    require(head.get('implementation')=='native' and head.get('evidence_kind')=='runtime','native runtime required')
    require(head.get('native_contract_version')==2,'native recorder v2 required')
    require(head.get('os',{}).get('version','').startswith('26.') and bool(head['os'].get('build')),'iOS26 OS/build required')
    require(head.get('device',{}).get('runtime_kind')=='simulator','simulator smoke required')
    require(head.get('geometry_probe',{}).get('accepted') is False,'session must label diagnostic-only')
    frames=[];events=[];previous=-1
    for seq,row in enumerate(rows):
        require(row.get('seq')==seq and row.get('schema_version')==1 and row.get('run_id')==head['run_id'],'complete envelope required')
        require(type(row.get('t_ns')) is int and row['t_ns']>=max(0,previous),'monotonic timestamp required');previous=row['t_ns']
        if row['type']=='event':
            require(row.get('name')!='run.error','explicit recorder failure');events.append(row)
        elif row['type']=='frame':
            probe=row.get('geometry_probe',{})
            require(probe.get('schema_version')==1 and probe.get('accepted') is False,'frame probe missing or promoted')
            candidates=probe.get('sheet_candidates',[])
            require(bool(candidates) and candidates[0].get('id')=='sheet','presented-view root required')
            require(len({c['id'] for c in candidates})==len(candidates),'duplicate candidate IDs')
            for candidate in candidates:
                radii=candidate.get('effective_radii_model',{})
                require(set(radii)=={'top_left','top_right','bottom_left','bottom_right'} and all(finite(v) for v in radii.values()),'four independent effective-radius observations required')
            require(all(row['metrics'].get(key) is None for key in ('sheet.radius','barrier.alpha')),'canonical unvalidated scalar promoted')
            frames.append(row)
    terminal=[r for r in rows if r.get('terminal') is True]
    require(len(terminal)==1 and terminal[0].get('name')=='dismiss.completed','successful diagnostic terminal required')
    boundary=next((e['t_ns'] for e in events if e.get('name')=='detent.requested'),None)
    require(boundary is not None,'complete deterministic recipe required')
    window=[f for f in frames if boundary-400000000<=f['t_ns']<boundary]
    require(len(window)>=2,'resting diagnostic observation window missing')
    ids=[c['id'] for c in window[0]['geometry_probe']['sheet_candidates']]
    require(all([c['id'] for c in f['geometry_probe']['sheet_candidates']]==ids for f in window),'unstable public ancestry IDs')
    return {'diagnostic_only':True,'accepted_profile':False,'sampled_frames':len(frames),'stable_candidate_ids':ids,
        'identity_window_frames':len(window),'max_frame_gap_ns':max((b['t_ns']-a['t_ns'] for a,b in zip(frames,frames[1:])),default=0),
        'limitations':['One diagnostic trial, not a profile or acceptance cohort','Model corner parameters are not guaranteed interpolated display contour','Sampling quality is reported, not waived into trajectory acceptance']}

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('trace');a=p.parse_args()
    try: print(json.dumps(validate_smoke(read(a.trace))))
    except (ValueError,KeyError,TypeError,OSError) as error: print(json.dumps({'diagnostic_only':True,'valid':False,'reason':str(error)}));raise SystemExit(1)
