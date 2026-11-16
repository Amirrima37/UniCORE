import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Retained CAD24 preservation campaign; never substitutes historical results."""
import os, sys, json, subprocess, time, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=output_dir('CAD/cad24')
OUT.mkdir(parents=True,exist_ok=True)
GODOT=r'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
env=os.environ.copy()
env.update(APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'),UNICORE_PYTHON=sys.executable)
def hashes():
    pins=json.loads((ROOT/'docs/architecture/evidence/cad23/binary-hashes-after.json').read_text())
    return {p:hashlib.sha256(Path(p).read_bytes()).hexdigest() if Path(p).exists() else None for p in pins}
before=hashes()
receipt={'verdict':'PARTIAL','branch':subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'binary_hashes_before':before,'native_validation':False,'native_face_history':False,'cases':[]}
steps=[('boundary',[GODOT,'--headless','--path',str(ROOT),'-s','res://tests/cad24_boundary.gd']),('scan',[GODOT,'--headless','--editor','--path',str(ROOT),'--quit'])]
for checkpoint,modes in [('21',['geometry','integration','lifecycle','preservation']),('22',['validation','persistence','independent','lifecycle']),('23',['unit','numerical','persistence','independent','lifecycle','shutdown','gui'])]:
    for mode in modes:steps.append(('cad'+checkpoint+'-'+mode,[sys.executable,'tests/run_cad'+checkpoint+'.py',mode]))
steps.append(('regressions',[sys.executable,'native/run_regressions.py','--godot',GODOT,'--output',str(OUT/'default-regressions')]))
for name,cmd in steps:
    attempt=OUT/(name+'-'+str(time.time_ns()));attempt.mkdir()
    start=time.monotonic()
    try:
        p=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,timeout=2100)
        code,out,err=p.returncode,p.stdout,p.stderr
    except subprocess.TimeoutExpired as e:code=None;out=e.stdout or b'';err=e.stderr or b''
    (attempt/'stdout.txt').write_bytes(out);(attempt/'stderr.txt').write_bytes(err)
    row=dict(name=name,exit_code=code,seconds=time.monotonic()-start,command=cmd,evidence=str(attempt),outcome='PASS' if code==0 and b'SCRIPT ERROR:' not in out+err else 'FAIL')
    receipt['cases'].append(row)
    receipt['binary_hashes_after']=hashes()
    receipt['pins_unchanged']=before==receipt['binary_hashes_after']
    receipt['source_hashes']={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['scripts/engines/cad_model.py','core/cae/cae_document.gd','ui/cae/cae_workspace.gd','tests/run_cad24.py']}
    (OUT/'final-receipt.json').write_text(json.dumps(receipt,indent=2))
    print(json.dumps(row),flush=True)
