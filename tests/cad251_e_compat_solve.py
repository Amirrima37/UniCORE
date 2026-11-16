import os,sys,json,time,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=Path((ROOT/'final-acceptance-attempt.txt').read_text().strip())
RUN=OUT/('C-solver-verification-'+str(time.time_ns()));RUN.mkdir()
native=json.loads((OUT/'native-verification-current.json').read_text())
text=(Path(native['directory'])/'C-native.stdout.txt').read_text()
source=Path(text.split('INTERFERENCE_NATIVE_PASS',1)[1].strip().splitlines()[0])
(RUN/'source-part.json').write_bytes((source/'source-part.json').read_bytes())
env=os.environ.copy();env.update(UNICORE_INTERFERENCE_OUT=str(RUN),UNICORE_INTERFERENCE_CACHE_ROOT=str(RUN/'pair-cache'),UNICORE_PYTHON=sys.executable,APPDATA=str(OUT/'profile/roaming'),LOCALAPPDATA=str(OUT/'profile/local'))
godot='D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe';rows=[]
for case in ['rotated-disjoint','touching','step']:
    env['UNICORE_INTERFERENCE_CASE']=case
    p=subprocess.run([godot,'--headless','--path',str(ROOT),'--log-file',str(RUN/(case+'.log')),'--script','tests/cad251_interference_solve.gd'],cwd=ROOT,env=env,capture_output=True,timeout=480)
    (RUN/(case+'.stdout.txt')).write_bytes(p.stdout);(RUN/(case+'.stderr.txt')).write_bytes(p.stderr)
    passed=p.returncode==0 and b'INTERFERENCE_SOLVES_PASS' in p.stdout and b'SCRIPT ERROR:' not in p.stderr
    rows.append(dict(case=case,passed=passed,exit_code=p.returncode));(RUN/'checks.json').write_text(json.dumps(rows,indent=2))
    (OUT/'C-solver-current.txt').write_text(str(RUN));print(case,passed,flush=True)
verification=json.loads((OUT/'verification-current.json').read_text());env['UNICORE_FACE_OUT']=verification['directory']
p=subprocess.run([sys.executable,'tests/cad251_faces_deck_audit.py'],cwd=ROOT,env=env,capture_output=True,timeout=60)
(RUN/'D-deck.stdout.txt').write_bytes(p.stdout);(RUN/'D-deck.stderr.txt').write_bytes(p.stderr)
rows.append(dict(case='D-deck-audit',passed=p.returncode==0 and b'FACE_DECK_AUDIT_PASS' in p.stdout))
(RUN/'checks.json').write_text(json.dumps(rows,indent=2))
print('C_SOLVES_D_AUDIT_COMPLETE',all(r['passed'] for r in rows),flush=True)
