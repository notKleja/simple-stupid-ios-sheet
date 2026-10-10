"""Public model-geometry transfer candidates. Never a rendered contour or Flutter profile."""
import math
import statistics
from geometry_cohort import CORNERS
from evidence_contract import require,finite

NUMERIC=('height','width','top','bottom_inset','side_inset')
ALLOWED=set(NUMERIC)|{'detent','direction'}
LIMIT=0.5

def validate(samples):
    require(bool(samples),'empty model samples')
    trials=set()
    for sample in samples:
        require(type(sample.get('trial')) is int and 1<=sample['trial']<=10,'explicit trial1..10 required')
        trials.add(sample['trial']);features=sample.get('features',{})
        require(bool(features) and not set(features)-ALLOWED,'private class/time/trial-order predictors forbidden')
        require(any(k in features for k in NUMERIC),'public numeric geometry required')
        require(all(finite(v) for k,v in features.items() if k in NUMERIC),'nonfinite geometry')
        require(all(isinstance(v,str) for k,v in features.items() if k not in NUMERIC),'categorical observation required')
        values=sample.get('radii',{})
        require(set(values)==set(CORNERS) and all(finite(v) and v>=0 for v in values.values()),'four independent finite model radii required')
    require(trials==set(range(1,11)),'all ten trials including untouched9–10 required')

def affine(rows,feature,corner):
    x=[r['features'][feature] for r in rows];y=[r['radii'][corner] for r in rows]
    if len(set(x))<3 or max(x)-min(x)<1e-6:return None
    mx=statistics.mean(x);my=statistics.mean(y)
    denominator=math.fsum((v-mx)**2 for v in x)
    slope=math.fsum((a-mx)*(b-my) for a,b in zip(x,y))/denominator
    return [my-slope*mx,slope]

def predict(model,features):
    family=model['family']
    if family=='constant':return model['coefficients'][0]
    if family in ('affine_geometry','inset_concentric'):
        a,b=model['coefficients'];return a+b*features[model['feature']]
    if family=='piecewise_affine':
        x=features[model['feature']];a,b=model['left'] if x<=model['threshold'] else model['right'];return a+b*x
    if family=='direction_affine':
        a,b=model['branches'][features['direction']];return a+b*features[model['feature']]
    raise ValueError('unapproved candidate family')

def error(model,rows,corner):
    try:return max(abs(predict(model,r['features'])-r['radii'][corner]) for r in rows)
    except KeyError:return math.inf

def fit_corner(samples,corner):
    validate(samples);require(corner in CORNERS,'unknown corner')
    train=[r for r in samples if r['trial']<=8];holdout=[r for r in samples if r['trial']>=9]
    # Candidate availability is frozen from training only. A missing holdout
    # feature makes validation unresolved; it can never alter model selection.
    features=[k for k in NUMERIC if all(k in r['features'] for r in train)]
    candidates=[{'family':'constant','complexity':1,'coefficients':[statistics.mean(r['radii'][corner] for r in train)]}]
    for feature in features:
        coefficients=affine(train,feature,corner)
        if coefficients is not None:
            candidates.append({'family':'affine_geometry','complexity':2,'feature':feature,'coefficients':coefficients})
        if feature in ('bottom_inset','side_inset','top') and len({r['features'][feature] for r in train})>=3:
            candidates.append({'family':'inset_concentric','complexity':2,'feature':feature,
                'coefficients':[statistics.mean(r['radii'][corner]+r['features'][feature] for r in train),-1]})
    if 'height' in features:
        unique=sorted({r['features']['height'] for r in train})
        # Predeclared bounded grid derived only from training geometry, never holdout.
        boundaries=[(a+b)/2 for a,b in zip(unique,unique[1:])]
        if len(boundaries)>32:boundaries=[boundaries[round(i*(len(boundaries)-1)/31)] for i in range(32)]
        for threshold in boundaries:
            left=[r for r in train if r['features']['height']<=threshold];right=[r for r in train if r['features']['height']>threshold]
            a=affine(left,'height',corner);b=affine(right,'height',corner)
            if a is not None and b is not None:
                candidates.append({'family':'piecewise_affine','complexity':5,'feature':'height','threshold':threshold,'left':a,'right':b})
        groups=sorted({r['features'].get('direction') for r in train if 'direction' in r['features']})
        if len(groups)>=2:
            branches={group:affine([r for r in train if r['features'].get('direction')==group],'height',corner) for group in groups}
            if all(branches.values()):candidates.append({'family':'direction_affine','complexity':2*len(branches),'feature':'height','branches':branches})
    assessed=[{'model':c,'training_max_error':error(c,train,corner)} for c in candidates]
    # Lowest complexity within tolerance wins. More complex forms must improve a
    # simpler alternative by >=0.5pt on training, not by inspecting holdout.
    passing=[c for c in assessed if c['training_max_error']<=LIMIT]
    chosen=min(passing or assessed,key=lambda c:(c['model']['complexity'] if passing else c['training_max_error'],c['training_max_error'],str(c['model'])))
    simpler=[c for c in assessed if c['model']['complexity']<chosen['model']['complexity']]
    improvement=min((c['training_max_error']-chosen['training_max_error'] for c in simpler),default=math.inf)
    def meaningful_support(feature):
        values=sorted(r['features'][feature] for r in train)
        support=[]
        for value in values:
            if not support or value-support[-1]>=1e-6:support.append(value)
        return len(support)
    distinct_geometry=max((meaningful_support(f) for f in features),default=0)
    result={'selected_model':chosen['model'],'selection_train_only':True,'train_trials':list(range(1,9)),'holdout_trials':[9,10],
        'training_max_error':chosen['training_max_error'],'holdout_max_error':None,'candidates':assessed,
        'domain':{f:{'min':min(r['features'][f] for r in train),'max':max(r['features'][f] for r in train)} for f in features},
        'corner':corner,'units':'logical_points_model_configuration','status':'unresolved','reason':None}
    holdout_error=error(chosen['model'],holdout,corner);result['holdout_max_error']=holdout_error if math.isfinite(holdout_error) else None
    if chosen['training_max_error']>LIMIT:result['reason']='Simple candidate families cannot explain training; no forced overfit'
    elif holdout_error>LIMIT:result['reason']='Untouched holdout exceeds0.5pt; no alternate model selected using holdout'
    elif distinct_geometry<3:
        result['status']='lookup_domain';result['reason']='Underdetermined geometry; constant value valid only at observed domain'
        result['lookup']={'observed_domain':result['domain'],'value':chosen['model']['coefficients'][0] if chosen['model']['family']=='constant' else None}
    elif simpler and improvement<LIMIT:
        result['status']='lookup_domain';result['reason']='Not materially distinguishable from a simpler alternative; formula withheld'
        result['lookup']={'observed_domain':result['domain'],'training_model_diagnostic_only':chosen['model']}
    else:result['status']='formula'
    result['limits']=['Model configuration transfer only, not rendered radius or contour','No extrapolation or Flutter parity claim','All selection/thresholds derive from trials1–8 only']
    return result

def fit_four(samples):return {corner:fit_corner(samples,corner) for corner in CORNERS}
