import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Owned real processes: active cancellation, timeouts, missing executable, recovery."""
import sys,os,json,subprocess,time,ctypes,base64,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/step-final/lifecycle');OUT.mkdir(exist_ok=True)
rows=[]
def alive(pid):
    k=ctypes.windll.kernel32;k.OpenProcess.restype=ctypes.c_void_p
    h=k.OpenProcess(0x100000,False,pid)
    if not h:return False
    status=k.WaitForSingleObject(ctypes.c_void_p(h),0);k.CloseHandle(ctypes.c_void_p(h));return status==258
ccx=ROOT/'.tools/engines/calculix/CalculiX-2.23.0-win-x64/bin/ccx.exe'
numerical=json.loads((OUT.parent/'numerical.json').read_text())
source=Path(max((r for r in numerical if r['fixture']=='bar'),key=lambda r:r['tet4'])['job'])/'model.inp'
raw=(ROOT/'tests/fixtures/step/bar.step').read_bytes()
part=dict(id='bar',kind='CAD',dimensions=[.1,1,.1],position=[0,0,0],rotation=[0,0,0],scale=[1,1,1],cad_sha256=hashlib.sha256(raw).hexdigest(),cad_base64=base64.b64encode(raw).decode())
for engine in ['gmsh','calculix']:
 for action in ['cancel','timeout','recovery','missing' if engine=='calculix' else 'corrupt']:
    job=OUT/(engine+'-'+action+'-'+str(time.time_ns()));job.mkdir()
    if engine=='calculix':
        (job/'model.inp').write_bytes(source.read_bytes())
        cmd=[sys.executable,str(ROOT/'scripts/engines/run_owned_solver.py'),str(job),str(ccx if action!='missing' else job/'missing.exe'),'0' if action=='timeout' else '120']
    else:
        p=part.copy()
        if action=='corrupt':p['cad_base64']='AA=='
        (job/'study.json').write_text(json.dumps(dict(parts=[p])))
        cmd=[sys.executable,str(ROOT/'scripts/engines/run_owned_mesh.py'),str(job),'.005' if action=='cancel' else '.05','0' if action=='timeout' else '120']
    child=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    observed_active=False;pid=None
    if action=='cancel':
        deadline=time.monotonic()+15
        while child.poll() is None and time.monotonic()<deadline:
            if engine=='calculix' and (job/'running.json').exists():
                try:pid=json.loads((job/'running.json').read_text())['pid'];observed_active=alive(pid)
                except (ValueError,KeyError):pass
            elif engine=='gmsh':
                # Mesh launcher exposes its owned PID for active-cancel evidence.
                if (job/'running.json').exists():
                    try:pid=json.loads((job/'running.json').read_text())['pid'];observed_active=alive(pid)
                    except (ValueError,KeyError):pass
            if observed_active:(job/'cancel').touch();break
            time.sleep(.001)
    stdout,stderr=child.communicate(timeout=135)
    (job/'harness.stdout').write_bytes(stdout);(job/'harness.stderr').write_bytes(stderr)
    receipt=json.loads((job/'receipt.json').read_text())
    if pid is None and (job/'running.json').exists():pid=json.loads((job/'running.json').read_text())['pid']
    expected={'cancel':'cancelled','timeout':'timeout','recovery':'completed','missing':'failed','corrupt':'failed'}[action]
    passed=receipt['state']==expected and child.returncode==(0 if action=='recovery' else 1) and (action!='cancel' or observed_active) and (pid is None or not alive(pid))
    row=dict(engine=engine,action=action,outcome='PASS' if passed else 'FAIL',launcher_exit=child.returncode,receipt=receipt,observed_active=observed_active,owned_pid=pid,owned_pid_alive=alive(pid) if pid else None,job=str(job));rows.append(row);print(json.dumps(row),flush=True)
    (OUT/'results.json').write_text(json.dumps(rows,indent=2))
raise SystemExit(0 if all(r['outcome']=='PASS' for r in rows) else 1)
