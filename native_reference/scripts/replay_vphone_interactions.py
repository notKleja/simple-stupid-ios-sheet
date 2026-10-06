#!/usr/bin/env python3
"""Native-only vPhone replay. UI rectangles are observed, never guessed."""
import argparse,json,subprocess,time,uuid
from pathlib import Path
from vphone_run import rpc,ROOT

def main():
    p=argparse.ArgumentParser();p.add_argument('machine');p.add_argument('--scenario',default='native.nonmodal.medium');p.add_argument('--trials',type=int,default=10);a=p.parse_args()
    inventory=json.loads(subprocess.check_output(['vphone-launchpad-cli','vm','list'],text=True));machine=next(m for m in inventory if m['name']==a.machine);sock=machine['controlSocket']
    revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    data=rpc(sock,'apps.data_dir',{'bundle_id':'dev.notkleja.NativeSheetHarness'})['data_path']
    def element(identifier):
        tree=rpc(sock,'ui.tree',{'max_elements':80,'visible_only':True})
        elements=tree.get('elements',[])
        matches=[e for e in elements if e.get('identifier')==identifier]
        if len(matches)!=1:raise RuntimeError(f'Expected one observed {identifier}: {len(matches)}')
        return matches[0]['frame']
    def tap(identifier):
        r=element(identifier);return rpc(sock,'input.tap',{'x':r['x']+r['width']/2,'y':r['y']+r['height']/2})
    for trial in range(1,a.trials+1):
        request={'scenario_id':a.scenario,'trial':trial,'trials':1,'attempt_id':str(uuid.uuid4()),'role':'training','source_revision':revision}
        rpc(sock,'files.write',{'path':data+'/Documents/interaction_request.json','content':json.dumps(request),'encoding':'utf8'})
        rpc(sock,'notify.post',{'name':'dev.notkleja.native-sheet.start'})
        time.sleep(1.2)
        if a.scenario=='native.nonmodal.medium':
            r=element('background.control');point={'x':r['x']+r['width']/2,'y':r['y']+r['height']/2}
            for phase in range(3):
                if phase==1:tap('sheet.select.large');time.sleep(.8)
                if phase==2:tap('sheet.select.medium');time.sleep(.8)
                tap('probe.begin');rpc(sock,'input.tap',point);tap('probe.end')
        else:
            tap('probe.begin');r=element('sheet.scroll')
            rpc(sock,'input.drag',{'points':[[r['x']+r['width']*.5,r['y']+r['height']*.85],[r['x']+r['width']*.5,r['y']+r['height']*.5]],'seconds':1,'steps':60})
            time.sleep(1);tap('probe.end')
        tap('experiment.finish');time.sleep(.8)
        print(json.dumps({'trial':trial,'attempt_id':request['attempt_id'],'replayed':True}),flush=True)

if __name__=='__main__':main()
