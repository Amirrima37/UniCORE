import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
import sys,os,json,time,subprocess,ctypes as C,atexit
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from process_memory import Counters
from artifact_retention import _plain
from owned_mesh_job import Job,resume_owned_process
OUT=output_dir('CAD/cad24-completion');run=OUT/('gui-endurance-'+str(time.time_ns()));run.mkdir()
USER=godot_environment_root()/'roaming/Godot/app_userdata/UniCORE'
def storage():
    paths=list(USER.glob('gmsh_*'))
    for category in ['cad_geometry','calculix_jobs']:
        if (USER/category).exists():paths.extend((USER/category).iterdir())
    total=0;files=0;managed=0
    for path in paths:
        try:
            if not path.is_dir() or not _plain(path):continue
        except FileNotFoundError:continue
        managed+=int((path/'.unicore-managed-job.json').exists())
        for directory,dirs,names in os.walk(path,followlinks=False):
            allowed=[]
            for name in dirs:
                try:
                    if _plain(Path(directory)/name):allowed.append(name)
                except FileNotFoundError:pass
            dirs[:]=allowed
            for name in names:
                try:
                    file=Path(directory)/name
                    if _plain(file):total+=file.stat().st_size;files+=1
                except FileNotFoundError:pass
    return dict(sample_epoch=time.time(),logical_bytes=total,files=files,job_directories=len(paths),managed_directories=managed)
env=os.environ.copy();env.update(APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'),UNICORE_PYTHON=sys.executable)
expected=int(env.get('UNICORE_CAD24_GUI_ENDURANCE_ITERATIONS','20'));disk_before=storage();disk_samples=[disk_before];last_disk=time.monotonic()
with (run/'stdout.txt').open('wb') as out,(run/'stderr.txt').open('wb') as err:
    host=Job(6144,os.getpid());atexit.register(host.close)
    p=subprocess.Popen([r'D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe','--path',str(ROOT),'-s','res://tests/cad24_gui_endurance.gd'],env=env,stdout=out,stderr=err,creationflags=0x4)
    host.assign(p);resume_owned_process(p.pid)
    started=time.monotonic();started_epoch=time.time();rows=[];seen=set();peak=0
    while p.poll() is None:
        counters=Counters();counters.cb=C.sizeof(counters)
        C.windll.psapi.GetProcessMemoryInfo(C.c_void_p(int(p._handle)),C.byref(counters),C.sizeof(counters));peak=max(peak,counters.working_set)
        for file in (OUT/'gui-endurance').glob('iteration-*.json'):
            if file.stat().st_mtime<started_epoch:continue
            if file in seen:continue
            try:row=json.loads(file.read_text())
            except ValueError:continue
            row.update(observed_working_set_bytes=counters.working_set,observed_commit_bytes=counters.pagefile);rows.append(row);seen.add(file)
        if time.monotonic()-last_disk>=5:disk_samples.append(storage());last_disk=time.monotonic()
        if time.monotonic()-started>max(900,expected*30):p.terminate();break
        time.sleep(.1)
    p.wait(timeout=15)
    host_peak=host.peak();host.close()
receipt=dict(exit_code=p.returncode,iterations=len(rows),expected_iterations=expected,elapsed_seconds=time.monotonic()-started,peak_working_set_bytes=peak,rows=sorted(rows,key=lambda r:r['iteration']),logs=str(run),storage_before=disk_before,storage_after=storage(),storage_samples=disk_samples,sampled_peak_temp_logical_bytes=max(s['logical_bytes'] for s in disk_samples),scope='Graphical parameter edits, selections, reassignments and save/reopen cycles; alternating TET4/TET10 solves every fifth cycle and on the final cycle. Not an unlimited leak-free claim.')
receipt['host_job_peak_process_commit_bytes']=host_peak
(OUT/'gui-endurance.json').write_text(json.dumps(receipt,indent=2))
assert p.returncode==0 and len(rows)==expected and b'CAD24_GUI_ENDURANCE_PASS' in (run/'stdout.txt').read_bytes(),receipt
assert all(r['operation_heartbeat_frames']>0 for r in rows)
print('CAD24_GUI_ENDURANCE_PASS')
