import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
import sys,os,json,time,subprocess,ctypes as C
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad24-completion')
marker=OUT/'fault-owner.json'
if marker.exists():marker.unlink()
env=os.environ.copy();env.update(APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'),UNICORE_PYTHON=sys.executable)
mode=sys.argv[1] if len(sys.argv)>1 else 'terminate-cut';env['UNICORE_CAD24_FAULT_MODE']=mode
prefix='fault-'+mode+'-'+str(time.time_ns());stdout_path=OUT/(prefix+'.stdout.txt');stderr_path=OUT/(prefix+'.stderr.txt')
stdout_file=stdout_path.open('wb');stderr_file=stderr_path.open('wb')
godot=subprocess.Popen([r'D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe','--headless','--path',str(ROOT),'-s','res://tests/cad24_failure.gd'],env=env,stdout=stdout_file,stderr=stderr_file)
k=C.windll.kernel32;k.OpenProcess.restype=C.c_void_p;k.OpenProcess.argtypes=[C.c_ulong,C.c_int,C.c_ulong];k.TerminateProcess.argtypes=[C.c_void_p,C.c_uint];k.CloseHandle.argtypes=[C.c_void_p]
k.WaitForSingleObject.argtypes=[C.c_void_p,C.c_ulong]
k.GetExitCodeProcess.argtypes=[C.c_void_p,C.c_void_p]
native_handle=None
deadline=time.monotonic()+90;terminated=None;observed=[];job=None;started=time.time()
cad_root=Path(env['APPDATA'])/'Godot/app_userdata/UniCORE/cad_geometry'
while time.monotonic()<deadline and godot.poll() is None:
    try:
        if job is None:
            for candidate in cad_root.iterdir():
                if candidate.stat().st_mtime<started:continue
                if json.loads((candidate/'running.json').read_text()).get('parent_pid')==godot.pid:job=candidate;break
            if job is None:time.sleep(.005);continue
        for file in (job/'kernel-temp').glob('occt-*/running.json'):
            running=json.loads(file.read_text())
            if running not in observed:observed.append(running)
            if mode=='timeout':continue
            if running['action']!=('step' if mode=='cancel-step' else 'cut'):continue
            handle=k.OpenProcess(0x101001,False,running['pid'])
            if handle:
                try:
                    if mode in ['cancel-step','cancel-cut']:
                        (job/'cancel').touch();terminated=running;native_handle=handle;break
                    if mode=='owner-exit':godot.terminate();terminated=running;native_handle=handle;break
                    if k.TerminateProcess(handle,77):terminated=running;native_handle=handle;break
                finally:
                    if handle!=native_handle:k.CloseHandle(handle)
        if terminated:break
    except (FileNotFoundError,ValueError):pass
    time.sleep(.001)
godot.wait(timeout=90);stdout_file.close();stderr_file.close();out=stdout_path.read_bytes()
receipt=dict(godot_exit=godot.returncode,terminated_native=terminated,observed=observed,recovered=b'CAD24_FAILURE_RECOVERY_PASS' in out,fault={'terminate-cut':'TerminateProcess(77) against observed owned native Cut worker; injected termination, not an OCCT segfault','cancel-cut':'Cooperative job cancellation during observed native Cut','cancel-step':'Cooperative job cancellation during observed native STEP import','owner-exit':'Terminate Godot owner while native worker is active','timeout':'Native deadline forced to zero seconds'}[mode])
receipt['mode']=mode
if native_handle:
    exit_code=C.c_ulong()
    assert k.GetExitCodeProcess(native_handle,C.byref(exit_code))
    receipt['native_exit_code_dword']=exit_code.value;k.CloseHandle(native_handle)
if job is not None:receipt['native_process_receipts']=[json.loads(p.read_text()) for p in (job/'kernel-temp').rglob('process-receipt.json')]
receipt['stdout']=str(stdout_path);receipt['stderr']=str(stderr_path)
if job is not None and (job/'receipt.json').exists():receipt['launcher']=json.loads((job/'receipt.json').read_text())
if mode=='owner-exit':
    until=time.monotonic()+10
    while time.monotonic()<until and not (job/'receipt.json').exists():time.sleep(.02)
    receipt['launcher']=json.loads((job/'receipt.json').read_text())
    assert receipt['launcher']['state']=='owner_exited',receipt
elif mode=='timeout':assert godot.returncode==0 and receipt['recovered'] and b'Native OCCT timeout' in out,receipt
else:
    assert terminated and godot.returncode==0 and receipt['recovered'],receipt
    if mode in ['cancel-step','cancel-cut']:assert receipt['launcher']['state']=='cancelled',receipt
alive=[]
for child in observed:
    handle=k.OpenProcess(0x100000,False,child['pid'])
    if handle:
        try:
            if k.WaitForSingleObject(handle,0)==258:alive.append(child['pid'])
        finally:k.CloseHandle(handle)
receipt['observed_native_pids_still_alive']=alive
assert not alive,receipt
(OUT/('fault-'+mode+'.json')).write_text(json.dumps(receipt,indent=2))
print('CAD24_FAILURE_PASS')
