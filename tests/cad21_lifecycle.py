import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Actual geometry child cancellation/timeout/recovery/owner-death containment."""
import sys,os,json,subprocess,time,ctypes
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad21/lifecycle');OUT.mkdir(parents=True,exist_ok=True)
launcher=ROOT/'scripts/engines/run_owned_geometry.py'
if len(sys.argv)>1 and sys.argv[1]=='--owner':
    job=Path(sys.argv[2]);p=subprocess.Popen([sys.executable,str(launcher),str(job),'45',str(os.getpid())],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    (job/'launcher-pid.json').write_text(json.dumps(p.pid))
    deadline=time.monotonic()+10
    while not (job/'running.json').exists() and time.monotonic()<deadline:time.sleep(.001)
    raise SystemExit(0)
k=ctypes.windll.kernel32;k.OpenProcess.restype=ctypes.c_void_p
def alive(pid):
    handle=k.OpenProcess(0x100000,False,pid)
    if not handle:return False
    status=k.WaitForSingleObject(ctypes.c_void_p(handle),0);k.CloseHandle(ctypes.c_void_p(handle));return status==258
model=dict(schema=1,units='m',root='a',nodes=[dict(id='a',type='Box',dimensions=[.1,.2,.1])]);rows=[]
for action in ['cancel','timeout','invalid','recovery','owner-exit','oversize']:
    job=OUT/(action+'-'+str(time.time_ns()));job.mkdir()
    request=dict(model=model,quality=60)
    if action=='invalid':request['model']={**model,'root':'missing'}
    (job/'request.json').write_text(json.dumps(request))
    if action=='oversize':
        with (job/'request.json').open('wb') as f:f.seek(96*1024*1024);f.write(b' ')
    cmd=[sys.executable,str(launcher),str(job),'0' if action=='timeout' else '45',str(os.getpid())]
    if action=='owner-exit':cmd=[sys.executable,__file__,'--owner',str(job)]
    p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE);observed=False
    if action=='cancel':
        deadline=time.monotonic()+10
        while p.poll() is None and time.monotonic()<deadline:
            if (job/'running.json').exists():
                try:observed=alive(json.loads((job/'running.json').read_text())['pid'])
                except ValueError:continue
                if observed:(job/'cancel').touch();break
            time.sleep(.001)
    stdout,stderr=p.communicate(timeout=50);(job/'harness.stdout').write_bytes(stdout);(job/'harness.stderr').write_bytes(stderr)
    deadline=time.monotonic()+8
    while not (job/'receipt.json').exists() and time.monotonic()<deadline:time.sleep(.02)
    receipt=json.loads((job/'receipt.json').read_text());pid=json.loads((job/'running.json').read_text())['pid']
    result=json.loads((job/'result.json').read_text()) if (job/'result.json').exists() else {}
    expected={'cancel':'cancelled','timeout':'timeout','invalid':'completed','recovery':'completed','owner-exit':'owner_exited','oversize':'completed'}[action]
    passed=receipt['state']==expected and receipt['job_object'] and not alive(pid)
    if action=='cancel':passed=passed and observed
    if action in ['invalid','oversize']:passed=passed and result.get('ok') is False
    if action=='recovery':passed=passed and result.get('ok') is True
    if action=='oversize':(job/'request.json').unlink()
    row=dict(case=action,outcome='PASS' if passed else 'FAIL',harness_child_exit=p.returncode,receipt=receipt,observed_active=observed,owned_pid=pid,owned_pid_alive=alive(pid),job=str(job));rows.append(row);print(json.dumps(row),flush=True)
    (OUT/'results.json').write_text(json.dumps(rows,indent=2))
assert all(r['outcome']=='PASS' for r in rows),rows
print('CAD21_LIFECYCLE_PASS')
