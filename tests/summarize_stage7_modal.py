"""Collect final receipts without rerunning numerical work or altering historical evidence."""
import hashlib,json,re,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'docs/workbench-2/stage7-checkpoint1'
receipts=[]
summary={}
for phase in ['numerical-verified','materials-verified','provenance-verified','builds-verified','regression-verified']:
    if (out/phase/'failure.txt').exists():raise RuntimeError('Failed acceptance phase: '+phase)
    data=json.loads((out/phase/'results.json').read_text());summary[phase]=dict(assertions=data['assertions'],operations=len(data['rows']))
    if not all(r.get('exit_code')==r['expected_exit'] for r in data['rows']):raise RuntimeError('Unexpected process outcome: '+phase)
    for r in data['rows']:
        r=dict(r);r['phase']=phase
        if 'log' in r:
            log=(root/r['log']).read_text(encoding='utf8');r['assertion_banners']=[s for s in log.splitlines() if re.search(r'PASS|Passed|checks=|failures=',s)];r['diagnostics']=[s for s in log.splitlines() if 'ERROR:' in s or 'WARNING:' in s]
        receipts.append(r)
manifest=json.loads((out/'regression-verified/default/results.json').read_text());summary['default_manifest']=dict(passed=sum(r['passed'] for r in manifest),total=len(manifest))
if not manifest or not all(r['passed'] for r in manifest):raise RuntimeError('Default manifest failed')
for r in manifest:
    r=dict(r);r['command']=[str(root/'.tools/godot/Godot_v4.0-stable_win64.exe'),'--headless','--path',str(root),'-s','res://'+r['script']];r['APPDATA']=str(root/'.tools/cae-appdata')
    p=out/'regression-verified/default'/(Path(r['script']).stem+'.log');r['log']=str(p.relative_to(root));log=p.read_text(encoding='utf8');r['assertion_banners']=[s for s in log.splitlines() if re.search(r'PASS|Passed|checks=|failures=',s)];r['diagnostics']=[s for s in log.splitlines() if 'ERROR:' in s or 'WARNING:' in s];receipts.append(r)
(out/'all-final-receipts.json').write_text(json.dumps(receipts,indent=2))
summary['source_sha256']={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [root/'native/src/math/symmetric_modes.hpp',root/'native/src/kernels/modal_solver.hpp',root/'native/extreme/modal_output.hpp',root/'native/extreme/main.cpp',root/'native/extreme/build.ps1',root/'native/extreme/CMakeLists.txt']}
summary['verdict']='PASS — CHECKPOINT 1 COMPLETE (bounded native constrained TET4 scope)'
summary['stage6_crash']='UNRESOLVED'
(out/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False))
print(json.dumps(summary,indent=2,ensure_ascii=False))
