import os,sys,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=Path((ROOT/'face-identity-attempt.txt').read_text().strip())
env=os.environ.copy();env.update(UNICORE_TEST_OUTPUT_ROOT=str(OUT/'compatibility'),UNICORE_PLACEMENT_OUT=str(OUT),UNICORE_PYTHON=sys.executable,APPDATA='D:/PROJECT/GODOT/TEST_ENVIRONMENTS/godot472-migration/roaming',LOCALAPPDATA='D:/PROJECT/GODOT/TEST_ENVIRONMENTS/godot472-migration/local')
rows=[]
def execute(name,command,marker,environment=env):
    p=subprocess.run(command,cwd=ROOT,env=environment,capture_output=True,timeout=360)
    (OUT/(name+'.stdout.txt')).write_bytes(p.stdout);(OUT/(name+'.stderr.txt')).write_bytes(p.stderr)
    ok=p.returncode==0 and marker.encode() in p.stdout
    rows.append(dict(test=name,passed=ok,exit_code=p.returncode));(OUT/'compatibility.json').write_text(json.dumps(rows,indent=2))
    assert ok,(name,p.stdout[-2000:],p.stderr[-2000:])
    print(name,'PASS',flush=True)
execute('B-placement',[sys.executable,'tests/cad251_native_placement.py'],'PLACEMENT_PASS')
execute('B-failures',[sys.executable,'tests/cad251_placement_failures.py'],'NEGATIVE_PASS')
pointer=ROOT/'interference-attempt.txt';previous=pointer.read_bytes()
try:
    execute('C-native',[sys.executable,'tests/cad251_interference_native.py'],'INTERFERENCE_NATIVE_PASS')
    c_out=Path(pointer.read_text())
finally:pointer.write_bytes(previous)
godot='D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
processes=[]
for case in ['rotated-disjoint','touching','step']:
    e=env.copy();e.update(UNICORE_INTERFERENCE_OUT=str(c_out),UNICORE_INTERFERENCE_CASE=case,UNICORE_INTERFERENCE_CACHE_ROOT=str(c_out/'pair-cache'))
    processes.append((case,subprocess.Popen([godot,'--headless','--path',str(ROOT),'--script','tests/cad251_interference_solve.gd'],cwd=ROOT,env=e,stdout=subprocess.PIPE,stderr=subprocess.PIPE)))
for case,p in processes:
    try:stdout,stderr=p.communicate(timeout=360)
    except subprocess.TimeoutExpired:p.kill();stdout,stderr=p.communicate()
    (OUT/('C-'+case+'.stdout.txt')).write_bytes(stdout);(OUT/('C-'+case+'.stderr.txt')).write_bytes(stderr)
    ok=p.returncode==0 and b'INTERFERENCE_SOLVES_PASS' in stdout
    rows.append(dict(test='C-'+case,passed=ok,exit_code=p.returncode,evidence=str(c_out)));(OUT/'compatibility.json').write_text(json.dumps(rows,indent=2))
    assert ok,(case,stdout[-3000:],stderr[-3000:])
    print('C-'+case,'PASS',flush=True)
print('FACE_COMPATIBILITY_PASS')
