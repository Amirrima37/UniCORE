"""Final measured checks. All outputs are unique and remain external."""
import os,sys,json,time,subprocess,shutil,threading
from concurrent.futures import ThreadPoolExecutor,as_completed
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=Path((ROOT/'final-acceptance-attempt.txt').read_text().strip())
RUN=OUT/('closure-'+str(time.time_ns()));RUN.mkdir()
(OUT/'closure-current.txt').write_text(str(RUN))
GODOT='D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
env=os.environ.copy();env.update(UNICORE_E_OUT=str(OUT),UNICORE_D_SOURCE=(ROOT/'face-identity-attempt.txt').read_text().strip(),UNICORE_PYTHON=sys.executable,APPDATA=str(OUT/'profile/roaming'),LOCALAPPDATA=str(OUT/'profile/local'),UNICORE_INTERFERENCE_CACHE_ROOT=str(RUN/'pair-cache'))
rows=[];lock=threading.Lock()
def run(name,script,marker,graphical=False,extra=None,timeout=900):
    folder=RUN/name;folder.mkdir(exist_ok=True);e=env.copy();e.update(extra or {})
    cmd=[GODOT,*(['--rendering-method','gl_compatibility'] if graphical else ['--headless']),'--path',str(ROOT),'--log-file',str(folder/'godot.log'),'--script','tests/'+script]
    if name=='participation':e['UNICORE_E_OUT']=str(folder)
    if name=='participation':e['UNICORE_D_SOURCE']=env['UNICORE_D_SOURCE']
    if name=='gui':e['UNICORE_E_GUI_OUT']=str(folder)
    if name=='endurance':e['UNICORE_E_ENDURANCE_OUT']=str(folder)
    started=time.monotonic()
    try:
        p=subprocess.run(cmd,cwd=ROOT,env=e,capture_output=True,timeout=timeout)
        stdout,stderr,code=p.stdout,p.stderr,p.returncode
    except subprocess.TimeoutExpired as error:stdout,stderr,code=error.stdout or b'',error.stderr or b'',None
    (folder/'stdout.txt').write_bytes(stdout);(folder/'stderr.txt').write_bytes(stderr)
    passed=code==0 and marker.encode() in stdout and b'SCRIPT ERROR:' not in stderr
    if graphical:passed=passed and b'ERROR:' not in stderr and b'were leaked' not in stderr
    row=dict(test=name,passed=passed,exit_code=code,seconds=time.monotonic()-started,directory=str(folder),command=cmd)
    with lock:
        rows.append(row);tmp=RUN/'checks.tmp';tmp.write_text(json.dumps(rows,indent=2));tmp.replace(RUN/'checks.json');print(name,passed,flush=True)
    return row
with ThreadPoolExecutor(max_workers=2) as pool:
    futures=[pool.submit(run,'gui','cad251_e_gui.gd','FINAL_WORKBENCH_GUI_PASS',True),pool.submit(run,'endurance','cad251_e_workbench_endurance.gd','WORKBENCH_ENDURANCE_20_PASS')]
    for future in as_completed(futures):future.result()
run('participation','cad251_e_participation.gd','PARTICIPATION_GATE_PASS')
# Historical runners retain all original numerical assertions. Their adapters
# assign faces through the current document commands instead of mutating slots.
historical=RUN/'historical';fixtures=historical/'CAD/cad24-completion';fixtures.mkdir(parents=True)
for name in ['overlap','through-hole','step-scaled']:
    shutil.copy2(Path('D:/PROJECT/TEST_OUTPUTS/CAD/cad24-completion')/(name+'.json'),fixtures/(name+'.json'))
run('CAD23-32','cad23_numerical.gd','CAD23_NUMERICAL_PASS',extra={'UNICORE_TEST_OUTPUT_ROOT':str(historical)},timeout=1800)
run('CAD24-six','cad24_numerical.gd','CAD24_NUMERICAL_PASS',extra={'UNICORE_TEST_OUTPUT_ROOT':str(historical)},timeout=900)
print('FINAL_CLOSURE_CHECKS',all(r['passed'] for r in rows),flush=True)
