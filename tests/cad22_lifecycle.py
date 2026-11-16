import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Bounded real Gmsh cancellation, timeout, owner exit, limits and recovery."""
import sys,os,json,time,subprocess,ctypes,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad22/lifecycle');OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'scripts/engines'));from mesh_config import defaults
launcher=ROOT/'scripts/engines/run_owned_mesh.py'
if len(sys.argv)>1:
    job=Path(sys.argv[1]);p=subprocess.Popen([sys.executable,str(launcher),str(job),'.01','120',str(os.getpid())],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    deadline=time.monotonic()+15
    while not (job/'running.json').exists() and time.monotonic()<deadline:time.sleep(.001)
    raise SystemExit(0)
k=ctypes.windll.kernel32;k.OpenProcess.restype=ctypes.c_void_p
def alive(pid):
    h=k.OpenProcess(0x100000,False,pid)
    if not h:return False
    value=k.WaitForSingleObject(ctypes.c_void_p(h),0)==258;k.CloseHandle(ctypes.c_void_p(h));return value
source=json.loads((ROOT/'docs/architecture/evidence/cad21/step-cut.json').read_text());rows=[]
for action in ['cancel','timeout','owner-exit','counts','quality','pathological','invalid-config','oversize-request','recovery']:
    job=OUT/(action+'-'+str(time.time_ns()));job.mkdir();data=copy.deepcopy(source);config=defaults(.04);config['curvature_points']=16
    if action=='cancel':config.update(target_size=.008,max_size=.008,min_size=.003)
    if action=='counts':config.update(max_nodes=4,max_elements=1)
    if action=='quality':config['min_quality']=.999999
    if action=='pathological':config.update(target_size=1e-6,min_size=1e-6,max_size=1e-6)
    if action=='invalid-config':config['schema']=99
    data['parts'][0]['mesh_settings']=config;(job/'study.json').write_text(json.dumps(data))
    if action=='oversize-request':
        with (job/'study.json').open('wb') as f:f.seek(128*1024*1024);f.write(b' ')
    cmd=[sys.executable,str(launcher),str(job),str(config['target_size']),'0' if action=='timeout' else '120',str(os.getpid())]
    if action=='owner-exit':cmd=[sys.executable,__file__,str(job)]
    p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE);observed=False
    if action=='cancel':
        deadline=time.monotonic()+15
        while p.poll() is None and time.monotonic()<deadline:
            if (job/'running.json').exists():
                try:observed=alive(json.loads((job/'running.json').read_text())['pid'])
                except ValueError:continue
                if observed:(job/'cancel').touch();break
            time.sleep(.001)
    stdout,stderr=p.communicate(timeout=140);(job/'harness.stdout').write_bytes(stdout);(job/'harness.stderr').write_bytes(stderr)
    deadline=time.monotonic()+10
    while not (job/'receipt.json').exists() and time.monotonic()<deadline:time.sleep(.01)
    receipt=json.loads((job/'receipt.json').read_text());pid=json.loads((job/'running.json').read_text())['pid'] if (job/'running.json').exists() else None
    expected=dict(cancel='cancelled',timeout='timeout',recovery='completed').get(action,'owner_exited' if action=='owner-exit' else 'failed')
    passed=receipt['state']==expected and (pid is None or not alive(pid)) and (action!='cancel' or observed)
    if action not in ['invalid-config','oversize-request']:passed=passed and receipt['job_object']
    if action=='oversize-request':(job/'study.json').unlink()
    if action=='recovery':
        mesh=json.loads((job/'mesh.json').read_text());passed=passed and mesh['quality']['minimum_jacobian']>0 and mesh['generation_id']
    for log in ['stdout.txt','stderr.txt']:
        if (job/log).exists():passed=passed and (job/log).stat().st_size<=4*1024*1024
    row=dict(test=action,outcome='PASS' if passed else 'FAIL',exit_code=p.returncode,terminal=receipt,observed_active=observed,pid=pid,pid_alive=alive(pid) if pid else False,evidence=str(job));rows.append(row);(OUT/'results.json').write_text(json.dumps(rows,indent=2));print(json.dumps(row),flush=True)
assert all(r['outcome']=='PASS' for r in rows)
print('CAD22_LIFECYCLE_PASS')
