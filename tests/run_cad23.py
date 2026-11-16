import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Bounded Checkpoint 2.3 receipts, immutable failed/successful attempts."""
import sys,os,time,subprocess,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad23');OUT.mkdir(parents=True,exist_ok=True)
GODOT=r'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
env=os.environ.copy();env.update(APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'),UNICORE_PYTHON=sys.executable)
mode=sys.argv[1];attempt=OUT/(mode+'-'+str(time.time_ns()));attempt.mkdir()
if mode=='gui' and '--inspect' in sys.argv:mode='gui_inspect'
if mode in ['unit','independent','lifecycle','shutdown']:steps=[(mode,[sys.executable,'tests/cad23_'+mode+'.py'],'CAD23_'+mode.upper()+'_PASS')]
elif mode in ['numerical','persistence','gui','gui_inspect','smoke']:
    steps=[(mode,[GODOT,*([] if mode.startswith('gui') else ['--headless']),'--path',str(ROOT),'-s','res://tests/cad23_'+mode+'.gd'],'CAD23_'+mode.upper()+'_PASS')]
elif mode=='scan':steps=[('scan',[GODOT,'--headless','--editor','--path',str(ROOT),'--quit'],None)]
elif mode=='regressions':steps=[('regressions',[sys.executable,'native/run_regressions.py','--godot',GODOT,'--output',str(attempt/'default')],None)]
elif mode=='preservation':steps=[('cad22-preservation',[sys.executable,'tests/run_cad22.py','preservation'],'PASS'),('cad22-validation',[sys.executable,'tests/run_cad22.py','validation'],'PASS')]
else:raise SystemExit('Unknown mode')
rows=[]
for name,cmd,marker in steps:
    start=time.monotonic()
    try:p=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,timeout=1800 if mode=='numerical' else 300);code=p.returncode;out=p.stdout;err=p.stderr
    except subprocess.TimeoutExpired as e:code=None;out=e.stdout or b'';err=e.stderr or b''
    (attempt/(name+'.stdout.txt')).write_bytes(out);(attempt/(name+'.stderr.txt')).write_bytes(err);log=(out+err).decode(errors='replace')
    row=dict(test=name,outcome='PASS' if code==0 and 'SCRIPT ERROR:' not in log and (marker is None or marker in log) else 'FAIL',exit_code=code,command=cmd,seconds=time.monotonic()-start,evidence=str(attempt));rows.append(row);print(json.dumps(row),flush=True)
    (attempt/'receipt.json').write_text(json.dumps(rows,indent=2));(OUT/(mode+'-latest.json')).write_text(json.dumps(rows,indent=2))
raise SystemExit(0 if all(r['outcome']=='PASS' for r in rows) else 1)
