"""Rerun B/C/D native contracts in a new external workspace, restoring pointers."""
import os,sys,json,time,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=Path((ROOT/'final-acceptance-attempt.txt').read_text().strip())
RUN=OUT/('native-verification-'+str(time.time_ns()));RUN.mkdir()
env=os.environ.copy();env.update(UNICORE_TEST_OUTPUT_ROOT=str(RUN),UNICORE_PYTHON=sys.executable)
rows=[];previous={}
for name in ['face-identity-attempt.txt','interference-attempt.txt']:
    previous[name]=(ROOT/name).read_bytes()
def execute(name,script,marker):
    p=subprocess.run([sys.executable,'tests/'+script],cwd=ROOT,env=env,capture_output=True,timeout=360)
    (RUN/(name+'.stdout.txt')).write_bytes(p.stdout);(RUN/(name+'.stderr.txt')).write_bytes(p.stderr)
    ok=p.returncode==0 and marker.encode() in p.stdout
    rows.append(dict(name=name,passed=ok,exit_code=p.returncode))
    (RUN/'native-verification.json').write_text(json.dumps(rows,indent=2));(OUT/'native-verification-current.json').write_text(json.dumps(dict(directory=str(RUN),results=str(RUN/'native-verification.json'))))
    print(name,ok,flush=True)
    if not ok:raise RuntimeError(name+' failed')
    return p.stdout.decode(errors='replace')
try:
    text=execute('B-native','cad251_native_placement.py','PLACEMENT_PASS')
    placement=text.split('PLACEMENT_PASS',1)[1].strip().splitlines()[0]
    env['UNICORE_PLACEMENT_OUT']=placement
    execute('B-failures','cad251_placement_failures.py','NEGATIVE_PASS')
    execute('C-native','cad251_interference_native.py','INTERFERENCE_NATIVE_PASS')
    execute('D-native','cad251_faces_native.py','FACE_NATIVE_PASS')
    execute('D-history','cad251_faces_history.py','FACE_HISTORY_PASS')
    execute('D-partition','cad251_faces_partition.py','FACE_PARTITION_SYMMETRY_PASS')
    execute('D-failures','cad251_faces_failures.py','FACE_NATIVE_FAILURE_PASS')
finally:
    for name,value in previous.items():(ROOT/name).write_bytes(value)
print('FINAL_NATIVE_VERIFICATION_PASS',flush=True)
