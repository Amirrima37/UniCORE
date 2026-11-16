import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Actual Godot shutdown during owned quadratic meshing and C3D10 solve."""
import sys,os,json,time,subprocess,ctypes
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad23');rows=[]
env=os.environ.copy();env.update(APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'),UNICORE_PYTHON=sys.executable)
godot=r'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
k=ctypes.windll.kernel32;k.OpenProcess.restype=ctypes.c_void_p
def alive(pid):
    h=k.OpenProcess(0x100000,False,pid)
    if not h:return False
    value=k.WaitForSingleObject(ctypes.c_void_p(h),0)==258;k.CloseHandle(ctypes.c_void_p(h));return value
for mode in ['mesh','solver']:
    env['CAD23_SHUTDOWN_MODE']=mode;cmd=[godot,'--headless','--path',str(ROOT),'-s','res://tests/cad23_shutdown.gd'];p=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,timeout=60)
    (OUT/('shutdown-'+mode+'.stdout.txt')).write_bytes(p.stdout);(OUT/('shutdown-'+mode+'.stderr.txt')).write_bytes(p.stderr)
    details=json.loads((OUT/('shutdown-'+mode+'.json')).read_text());job=Path(details['directory']);running=json.loads((job/'running.json').read_text());receipt=json.loads((job/'receipt.json').read_text())
    passed=p.returncode==0 and details['observed'] and not alive(running['pid']) and receipt['state'] in ['cancelled','owner_exited'] and b'SCRIPT ERROR:' not in p.stderr
    rows.append(dict(test='Godot-shutdown-'+mode,outcome='PASS' if passed else 'FAIL',exit_code=p.returncode,observed_active=details['observed'],pid=running['pid'],pid_alive=alive(running['pid']),receipt=receipt,evidence=str(job)))
    (OUT/'shutdown-details.json').write_text(json.dumps(rows,indent=2))
assert all(r['outcome']=='PASS' for r in rows),rows
print('CAD23_SHUTDOWN_PASS')
