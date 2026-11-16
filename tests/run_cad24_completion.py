import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
import json,sys,os,time,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad24-completion')
GODOT=r'D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
env=os.environ.copy();env.update(APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'),UNICORE_PYTHON=sys.executable)
steps=[('native',[sys.executable,'tests/cad24_native.py']),('retention',[sys.executable,'tests/cad24_retention.py']),('scan',[GODOT,'--headless','--editor','--path',str(ROOT),'--quit'])]
steps.insert(1,('history',[sys.executable,'tests/cad24_history.py']))
steps.insert(1,('protocol',[sys.executable,'tests/cad24_protocol.py']))
steps.insert(1,('matrix-extra',[sys.executable,'tests/cad24_matrix_extra.py']))
steps.insert(2,('endurance',[sys.executable,'tests/cad24_endurance.py']))
steps.insert(3,('failure',[sys.executable,'tests/cad24_failure.py']))
steps.insert(3,('gui-endurance',[sys.executable,'tests/cad24_gui_endurance.py']))
for mode in ['cancel-cut','cancel-step','timeout','owner-exit']:steps.insert(4,(mode,[sys.executable,'tests/cad24_failure.py',mode]))
for name in ['boundary','numerical','gui']:steps.append((name,[GODOT,*([] if name=='gui' else ['--headless']),'--path',str(ROOT),'-s','res://tests/cad24_'+name+'.gd']))
steps.append(('deck-audit',[sys.executable,'tests/cad24_deck_audit.py']))
for checkpoint,modes in [('21',['geometry','integration','lifecycle','preservation']),('22',['validation','numerical','persistence','independent','lifecycle']),('23',['unit','numerical','persistence','independent','lifecycle','shutdown','gui'])]:
    for mode in modes:steps.append(('cad'+checkpoint+'-'+mode,[sys.executable,'tests/run_cad'+checkpoint+'.py',mode]))
steps.append(('regressions',[sys.executable,'native/run_regressions.py','--godot',GODOT,'--output',str(OUT/'default-regressions')]))
selected=set(sys.argv[1:]);rows=[]
for name,cmd in steps:
    if selected and name not in selected:continue
    attempt=OUT/(name+'-'+str(time.time_ns()));attempt.mkdir(parents=True)
    start=time.monotonic()
    timeout=60 if name in ['scan','boundary','retention'] else 2100
    try:p=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,timeout=timeout);code,out,err=p.returncode,p.stdout,p.stderr
    except subprocess.TimeoutExpired as e:code=None;out=e.stdout or b'';err=e.stderr or b''
    (attempt/'stdout.txt').write_bytes(out);(attempt/'stderr.txt').write_bytes(err)
    row=dict(name=name,exit_code=code,outcome='PASS' if code==0 and b'SCRIPT ERROR:' not in out+err else 'FAIL',command=cmd,seconds=time.monotonic()-start,evidence=str(attempt))
    (attempt/'receipt.json').write_text(json.dumps(row,indent=2));rows.append(row)
    (OUT/(name+'-latest.json')).write_text(json.dumps(row,indent=2));print(json.dumps(row),flush=True)
