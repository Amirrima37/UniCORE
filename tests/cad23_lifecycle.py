import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Real quadratic Gmsh/CalculiX owned-process cancellation and failure recovery."""
import sys,os,json,time,subprocess,ctypes,copy,shutil,signal
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad23/lifecycle');OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'scripts/engines'));from mesh_config import defaults
if len(sys.argv)>1:
    cmd=json.loads(Path(sys.argv[1]).read_text());cmd[-1]=str(os.getpid());p=subprocess.Popen(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    job=Path(cmd[2]);deadline=time.monotonic()+15
    while not (job/'running.json').exists() and p.poll() is None and time.monotonic()<deadline:time.sleep(.001)
    raise SystemExit(0)
k=ctypes.windll.kernel32;k.OpenProcess.restype=ctypes.c_void_p
def alive(pid):
    h=k.OpenProcess(0x100000,False,pid)
    if not h:return False
    value=k.WaitForSingleObject(ctypes.c_void_p(h),0)==258;k.CloseHandle(ctypes.c_void_p(h));return value
source=json.loads((ROOT/'docs/architecture/evidence/cad21/step-cut.json').read_text());rows=[]
numerical=json.loads((ROOT/'docs/architecture/evidence/cad23/numerical.json').read_text());solve_source=Path([r for r in numerical if r['case']=='bending' and r['order']==2][-1]['solver_job'])
for kind in ['mesh','solver']:
    for action in ['cancel-before','cancel-active','timeout','owner-exit','worker-crash','invalid-input','missing-worker','recovery']:
        job=OUT/(kind+'-'+action+'-'+str(time.time_ns()));job.mkdir();timeout='0' if action=='timeout' else '120'
        if kind=='mesh':
            size=.012 if action in ['cancel-active','owner-exit','worker-crash'] else .04
            data=copy.deepcopy(source);config=defaults(size);config.update(schema=2,order=2,curvature_points=16);data['parts'][0]['mesh_settings']=config
            if action=='invalid-input':config.update(max_nodes=4,max_elements=1)
            if action=='missing-worker':data['parts'][0]['cad_base64']='not a STEP file'
            (job/'study.json').write_text(json.dumps(data));cmd=[sys.executable,str(ROOT/'scripts/engines/run_owned_mesh.py'),str(job),str(size),timeout,str(os.getpid())]
        else:
            shutil.copyfile(solve_source/'model.inp',job/'model.inp')
            if action=='invalid-input':(job/'model.inp').write_text('*HEADING\ninvalid bounded deck\n*ELEMENT,TYPE=C3D10\n1,1\n')
            binary=ROOT/'.tools/engines/calculix/CalculiX-2.23.0-win-x64/bin/ccx.exe'
            if action=='missing-worker':binary=job/'missing-ccx.exe'
            cmd=[sys.executable,str(ROOT/'scripts/engines/run_owned_solver.py'),str(job),str(binary),timeout,str(os.getpid())]
        if action=='cancel-before':(job/'cancel').touch()
        if action=='owner-exit':
            f=job/'owner-command.json';f.write_text(json.dumps(cmd));cmd=[sys.executable,__file__,str(f)]
        p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE);observed=False
        if action in ['cancel-active','worker-crash']:
            deadline=time.monotonic()+15
            while p.poll() is None and time.monotonic()<deadline:
                try:
                    pid=json.loads((job/'running.json').read_text())['pid'];observed=alive(pid)
                    if observed:
                        if action=='cancel-active':(job/'cancel').touch()
                        else:os.kill(pid,signal.SIGTERM) # Only this test's recorded, owned worker.
                        break
                except (FileNotFoundError,ValueError):pass
                time.sleep(.001)
        stdout,stderr=p.communicate(timeout=140);(job/'harness.stdout').write_bytes(stdout);(job/'harness.stderr').write_bytes(stderr)
        deadline=time.monotonic()+10
        while not (job/'receipt.json').exists() and time.monotonic()<deadline:time.sleep(.01)
        receipt=json.loads((job/'receipt.json').read_text());pid=json.loads((job/'running.json').read_text())['pid'] if (job/'running.json').exists() else None
        expected={'cancel-before':'cancelled','cancel-active':'cancelled','timeout':'timeout','owner-exit':'owner_exited','recovery':'completed'}.get(action,'failed')
        passed=receipt['state']==expected and (not pid or not alive(pid)) and (action!='cancel-active' or observed)
        row=dict(test=kind+'-'+action,outcome='PASS' if passed else 'FAIL',exit_code=p.returncode,terminal=receipt,pid=pid,pid_alive=alive(pid) if pid else False,observed_active=observed,evidence=str(job));rows.append(row)
        (OUT/'results.json').write_text(json.dumps(rows,indent=2));print(json.dumps(row),flush=True)
assert all(r['outcome']=='PASS' for r in rows)
print('CAD23_LIFECYCLE_PASS')
