import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Checkpoint receipts: unique bounded attempts, raw streams and actual exits."""
import os,sys,json,time,subprocess,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad21');OUT.mkdir(parents=True,exist_ok=True)
GODOT=r'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
env=os.environ.copy();env.update(APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'),UNICORE_PYTHON=sys.executable)
mode=sys.argv[1];attempt=OUT/(mode+'-'+str(time.time_ns()));attempt.mkdir();rows=[]
if mode=='geometry':steps=[('geometry',[sys.executable,'tests/cad21_geometry.py'],'CAD21_GEOMETRY_PASS')]
elif mode=='integration':steps=[('integration',[GODOT,'--headless','--path',str(ROOT),'-s','res://tests/cad21_integration.gd'],'CAD21_INTEGRATION_PASS')]
elif mode=='gui':steps=[('gui',[GODOT,'--path',str(ROOT),'-s','res://tests/cad21_gui.gd'],'CAD21_GUI_PASS')]
elif mode=='lifecycle':steps=[('lifecycle',[sys.executable,'tests/cad21_lifecycle.py'],'CAD21_LIFECYCLE_PASS')]
elif mode=='scan':steps=[('scan',[GODOT,'--headless','--editor','--path',str(ROOT),'--quit'],None)]
elif mode=='preservation':
    steps=[]
    for name,script,marker in [('fingerprint','test_mesh_fingerprint.gd','failures=0'),('step-bar','test_godot472_step_workbench.gd','STEP_CALCULIX_WORKBENCH_PASS bar'),('step-cylinder','test_godot472_step_workbench.gd','STEP_CALCULIX_WORKBENCH_PASS cylinder')]:steps.append((name,[GODOT,'--headless','--path',str(ROOT),'-s','res://tests/'+script],marker))
    for name,binary in [('modal','stage7-modal-test.exe'),('dynamics','dynamics_test.exe')]:steps.append((name,[str(ROOT/'.tools'/binary)],None))
else:raise SystemExit('Unknown mode')
for name,cmd,marker in steps:
    if name in ['step-bar','step-cylinder']:env['UNICORE_STEP_FIXTURE']=name.removeprefix('step-')
    start=time.monotonic()
    try:
        p=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,timeout=240);code=p.returncode;stdout=p.stdout;stderr=p.stderr
    except subprocess.TimeoutExpired as e:code=None;stdout=e.stdout or b'';stderr=e.stderr or b''
    (attempt/(name+'.stdout.txt')).write_bytes(stdout);(attempt/(name+'.stderr.txt')).write_bytes(stderr)
    log=(stdout+stderr).decode(errors='replace');passed=code==0 and 'SCRIPT ERROR:' not in log and (marker is None or marker in log)
    row=dict(case=name,outcome='PASS' if passed else 'FAIL',exit_code=code,command=cmd,seconds=time.monotonic()-start,evidence=str(attempt));rows.append(row);print(json.dumps(row),flush=True)
(attempt/'receipt.json').write_text(json.dumps(rows,indent=2));(OUT/(mode+'-latest.json')).write_text(json.dumps(rows,indent=2))
raise SystemExit(0 if all(r['outcome']=='PASS' for r in rows) else 1)
