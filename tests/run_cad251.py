"""Unique external attempt; preserve failed diagnostics and actual exit codes."""
import json, os, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/engines'))
from development_paths import test_output_root, godot_environment_root
out=test_output_root()/'CAD/cad251'/('attempt-'+str(time.time_ns()))
out.mkdir(parents=True)
env=os.environ.copy()
env.update(APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'),UNICORE_PYTHON=sys.executable)
cmd=['D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe','--headless','--path',str(ROOT),'--script','tests/cad251_numerical.gd']
marker=b'CAD251_NUMERICAL_PASS'
if sys.argv[1:]==['gui']:
    cmd.remove('--headless');cmd[-1]='tests/cad251_gui.gd';marker=b'CAD251_GUI_CAPTURED'
start=time.monotonic()
try:
    p=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,timeout=240)
    code,stdout,stderr=p.returncode,p.stdout,p.stderr
except subprocess.TimeoutExpired as e:
    code=None;stdout=e.stdout or b'';stderr=e.stderr or b''
(out/'stdout.txt').write_bytes(stdout);(out/'stderr.txt').write_bytes(stderr)
receipt=dict(command=cmd,exit_code=code,seconds=time.monotonic()-start,passed=code==0 and marker in stdout)
(out/'receipt.json').write_text(json.dumps(receipt,indent=2))
print(out,receipt)
print(stdout.decode(errors='replace')[-6000:])
print(stderr.decode(errors='replace')[-6000:])
sys.exit(0 if receipt['passed'] else 1)
