import os,sys,json,subprocess,time,threading,ctypes as C,ctypes.wintypes as W
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=Path((ROOT/'final-acceptance-attempt.txt').read_text().strip())
RUN=OUT/('lifecycle-attempt-'+str(time.time_ns()));RUN.mkdir()
env=os.environ.copy();env.update(UNICORE_E_OUT=str(OUT),UNICORE_E_LIFECYCLE_OUT=str(RUN),UNICORE_PYTHON=sys.executable,APPDATA=str(OUT/'profile/roaming'),LOCALAPPDATA=str(OUT/'profile/local'))
godot='D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe';rows=[]
k=C.WinDLL('kernel32',use_last_error=True)
k.OpenProcess.argtypes=[W.DWORD,W.BOOL,W.DWORD];k.OpenProcess.restype=C.c_void_p
k.WaitForSingleObject.argtypes=[C.c_void_p,W.DWORD];k.CloseHandle.argtypes=[C.c_void_p]
k.TerminateProcess.argtypes=[C.c_void_p,W.UINT]
def monitor(folder,stop):
    request=folder/'monitor-request.json'
    while not stop.is_set():
        try:
            q=json.loads(request.read_text());job=Path(q['directory']);mode=q['mode']
            paths=list((job/'kernel-temp').rglob('running.json')) if mode in ['cancel-native','crash-native','cancel-interference'] else [job/'running.json']
            for path in paths:
                info=json.loads(path.read_text())
                action='cut' if mode in ['cancel-native','crash-native'] else 'classify_pair'
                if mode in ['cancel-native','crash-native','cancel-interference'] and info.get('action')!=action:continue
                h=k.OpenProcess(0x100001,False,info['pid'])
                if not h:continue
                try:
                    if k.WaitForSingleObject(h,0)!=258:continue
                    info.update(alive_at_action=True,monitor_time_ns=time.time_ns())
                    if mode in ['crash-native','fail-gmsh','fail-calculix']:info['terminated']=bool(k.TerminateProcess(h,97))
                    elif mode.startswith('cancel'):(job/'cancel').touch()
                    target=folder/'monitor-result.json';tmp=target.with_suffix('.tmp');tmp.write_text(json.dumps(info));tmp.replace(target)
                    return
                finally:k.CloseHandle(h)
        except (FileNotFoundError,json.JSONDecodeError,OSError):pass
        time.sleep(.001)
for mode in os.environ.get('UNICORE_E_LIFECYCLE_MODES','cancel-native,cancel-interference,cancel-mesh,cancel-solve,close-mesh,close-solve,timeout-native,crash-native,fail-gmsh,fail-calculix').split(','):
    env['UNICORE_E_LIFECYCLE']=mode
    folder=RUN/mode;folder.mkdir();env['UNICORE_E_LIFECYCLE_OUT']=str(folder)
    stop=threading.Event();thread=threading.Thread(target=monitor,args=(folder,stop),daemon=True);thread.start()
    try:
        p=subprocess.run([godot,'--headless','--path',str(ROOT),'--log-file',str(folder/'workbench.log'),'--script','tests/cad251_e_lifecycle.gd'],cwd=ROOT,env=env,capture_output=True,timeout=240)
        (RUN/('lifecycle-'+mode+'.stdout.txt')).write_bytes(p.stdout);(RUN/('lifecycle-'+mode+'.stderr.txt')).write_bytes(p.stderr)
        evidence=folder/('lifecycle-'+mode+'.json');detail=json.loads(evidence.read_text()) if evidence.exists() else {}
        passed=p.returncode==0 and b'SCRIPT ERROR:' not in p.stderr and detail.get('failed_safely') and not detail.get('alive_after',True)
        rows.append(dict(mode=mode,passed=passed,exit_code=p.returncode,details=detail))
    except subprocess.TimeoutExpired as error:rows.append(dict(mode=mode,passed=False,error='Harness timeout'))
    finally:stop.set();thread.join(3)
    (RUN/'lifecycle.json').write_text(json.dumps(rows,indent=2));(OUT/'lifecycle-current.json').write_text(json.dumps(dict(directory=str(RUN),results=str(RUN/'lifecycle.json'))));print(mode,rows[-1]['passed'],flush=True)
print('LIFECYCLE_MATRIX_COMPLETE',all(r['passed'] for r in rows),flush=True)
