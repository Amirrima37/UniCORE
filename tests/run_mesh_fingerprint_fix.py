import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
import os,subprocess,json
from pathlib import Path
root=Path.cwd();out=root/'.tools/mesh-fingerprint-fix';out.mkdir(exist_ok=True)
env=os.environ.copy();env.update(APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'),UNICORE_PYTHON=r'C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe')
exe=r'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
rows=[]
for name,script,marker in [('canonical','test_mesh_fingerprint.gd','failures=0'),('bar','test_godot472_step_workbench.gd','STEP_CALCULIX_WORKBENCH_PASS bar'),('cylinder','test_godot472_step_workbench.gd','STEP_CALCULIX_WORKBENCH_PASS cylinder')]:
 env['UNICORE_STEP_FIXTURE']=name
 p=subprocess.run([exe,'--headless','--path',str(root),'-s','res://tests/'+script],env=env,capture_output=True,timeout=180)
 log=(p.stdout+p.stderr).decode(errors='replace');(out/(name+'.log')).write_text(log)
 row=dict(test=name,exit_code=p.returncode,passed=p.returncode==0 and marker in log and 'SCRIPT ERROR' not in log);rows.append(row);print(json.dumps(row),flush=True)
(out/'results.json').write_text(json.dumps(rows,indent=2))
raise SystemExit(0 if all(r['passed'] for r in rows) else 1)
