import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Bounded CAD22 campaigns with immutable attempt logs and actual exit receipts."""
import sys,os,time,subprocess,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad22');OUT.mkdir(parents=True,exist_ok=True)
GODOT=r'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
env=os.environ.copy();env.update(APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'),UNICORE_PYTHON=sys.executable)
mode=sys.argv[1];attempt=OUT/(mode+'-'+str(time.time_ns()));attempt.mkdir()
if mode in ['validation','lifecycle','independent']:steps=[(mode,[sys.executable,'tests/cad22_'+mode+'.py'],'CAD22_'+mode.upper()+'_PASS')]
elif mode in ['numerical','persistence','gui']:
    steps=[(mode,[GODOT,*([] if mode=='gui' else ['--headless']),'--path',str(ROOT),'-s','res://tests/cad22_'+mode+'.gd'],'CAD22_'+mode.upper()+'_PASS')]
elif mode=='scan':steps=[('scan',[GODOT,'--headless','--editor','--path',str(ROOT),'--quit'],None)]
elif mode=='preservation':
    steps=[('cad21-geometry',[sys.executable,'tests/run_cad21.py','geometry'],'PASS'),('cad21-integration',[sys.executable,'tests/run_cad21.py','integration'],'PASS'),('step-modal-transient',[sys.executable,'tests/run_cad21.py','preservation'],'PASS')]
elif mode=='regressions':steps=[('default-regressions',[sys.executable,'native/run_regressions.py','--godot',GODOT,'--output',str(attempt/'default')],None)]
else:raise SystemExit('Unknown CAD22 mode')
rows=[]
for name,cmd,marker in steps:
    start=time.monotonic()
    try:
        p=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,timeout=900 if mode in ['numerical','regressions'] else 240);code=p.returncode;stdout=p.stdout;stderr=p.stderr
    except subprocess.TimeoutExpired as e:code=None;stdout=e.stdout or b'';stderr=e.stderr or b''
    (attempt/(name+'.stdout.txt')).write_bytes(stdout);(attempt/(name+'.stderr.txt')).write_bytes(stderr)
    log=(stdout+stderr).decode(errors='replace');passed=code==0 and 'SCRIPT ERROR:' not in log and (marker is None or marker in log)
    row=dict(test=name,outcome='PASS' if passed else 'FAIL',exit_code=code,seconds=time.monotonic()-start,command=cmd,evidence=str(attempt));rows.append(row);print(json.dumps(row),flush=True)
    (attempt/'receipt.json').write_text(json.dumps(rows,indent=2));(OUT/(mode+'-latest.json')).write_text(json.dumps(rows,indent=2))
raise SystemExit(0 if all(r['outcome']=='PASS' for r in rows) else 1)
