import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Bounded final acceptance; machine receipts use real process exit codes."""
import os, sys, subprocess, json, time, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=output_dir('CAD/step-final')
OUT.mkdir(parents=True,exist_ok=True)
GODOT=Path(r'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe')
env=os.environ.copy()
env.update(APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'),UNICORE_PYTHON=sys.executable)
mode=sys.argv[1] if len(sys.argv)>1 else 'engineering'
steps=[]
def gd(name, script, marker, graphical=False, fixture=None):
    steps.append((name,[str(GODOT),*([] if graphical else ['--headless']),'--path',str(ROOT),'-s','res://tests/'+script],marker,fixture))
if mode=='numerical':gd('step-numerical','step_final_numerical.gd','STEP_FINAL_NUMERICAL_PASS')
elif mode=='workbench-lifecycle':gd('workbench-lifecycle','step_final_workbench_lifecycle.gd','STEP_WORKBENCH_LIFECYCLE_PASS')
elif mode=='compatibility':
    for name,binary in [('modal','stage7-modal-test.exe'),('dynamics','dynamics_test.exe'),('numeric-job','job_numeric_test.exe')]:steps.append((name,[str(ROOT/'.tools'/binary)],None,None))
elif mode=='comparison':steps.append(('extreme-comparison-retry',[sys.executable,'tests/compare_godot472_calculix_extreme.py','--output',str(OUT/('extreme-comparison-'+str(time.time_ns())))],None,None))
elif mode=='gui':
    for fixture in ['bar','cylinder']:gd('gui-'+fixture,'step_final_graphical.gd','STEP_CALCULIX_WORKBENCH_PASS '+fixture,True,fixture)
elif mode=='engineering':
    gd('adapter','test_calculix_adapter.gd','CALCULIX_EXPORT_PASS')
    gd('patch','test_godot472_calculix_numerical.gd','CALCULIX_NUMERICAL_PASS')
    gd('canonical','test_mesh_fingerprint.gd','failures=0')
    gd('failure-import','step_final_failures.gd','STEP_FINAL_FAILURES_PASS')
    for name,script in [('step-preview','test_step_preview.py'),('gmsh-repeatability','test_godot472_gmsh_repeatability.py'),('extreme-comparison','compare_godot472_calculix_extreme.py'),('lifecycle','step_final_lifecycle.py')]:
        steps.append((name,[sys.executable,'tests/'+script,*(['--output',str(OUT/('extreme-comparison-'+str(time.time_ns())))] if name=='extreme-comparison' else [])],None,None))
    steps.append(('editor-scan',[str(GODOT),'--headless','--editor','--path',str(ROOT),'--quit'],None,None))
rows=[]
for name,cmd,marker,fixture in steps:
    if fixture:env['UNICORE_STEP_FIXTURE']=fixture
    start=time.monotonic()
    try:
        p=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,timeout=240)
        code=p.returncode;stdout=p.stdout;stderr=p.stderr;state='completed'
    except subprocess.TimeoutExpired as e:
        code=None;stdout=e.stdout or b'';stderr=e.stderr or b'';state='timeout'
    (OUT/(name+'.stdout.txt')).write_bytes(stdout);(OUT/(name+'.stderr.txt')).write_bytes(stderr)
    log=(stdout+stderr).decode(errors='replace')
    passed=code==0 and 'SCRIPT ERROR:' not in log and (marker is None or marker in log)
    row=dict(name=name,command=cmd,exit_code=code,outcome='PASS' if passed else 'FAIL',state=state,seconds=time.monotonic()-start)
    rows.append(row);print(json.dumps(row),flush=True)
    (OUT/(mode+'-receipt.json')).write_text(json.dumps(rows,indent=2))
binary_paths=[GODOT,ROOT/'.tools/engines/calculix/CalculiX-2.23.0-win-x64/bin/ccx.exe',*list((ROOT/'bin').rglob('*.dll')),*list((ROOT/'.tools/engines/gmsh-4.15.2-Windows64-sdk/lib').glob('*.dll'))]
(OUT/'binary-hashes.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in binary_paths},indent=2))
raise SystemExit(0 if all(r['outcome']=='PASS' for r in rows) else 1)
