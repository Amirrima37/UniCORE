"""Focused current-source storage and A/D verification; preserve prior attempts."""
import os,sys,json,time,subprocess,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=Path((ROOT/'final-acceptance-attempt.txt').read_text().strip())
SOURCE=Path((ROOT/'face-identity-attempt.txt').read_text().strip())
RUN=OUT/('verification-'+str(time.time_ns()));RUN.mkdir()
for name in ['source-part.json','symmetric-part.json','history-original.json','history-edited.json']:
    shutil.copy2(SOURCE/name,RUN/name)
env=os.environ.copy();env.update(UNICORE_E_OUT=str(RUN),UNICORE_D_SOURCE=str(SOURCE),UNICORE_FACE_OUT=str(RUN),UNICORE_PYTHON=sys.executable,APPDATA=str(OUT/'profile/roaming'),LOCALAPPDATA=str(OUT/'profile/local'),UNICORE_INTERFERENCE_CACHE_ROOT=str(RUN/'pair-cache'),UNICORE_ASSEMBLY_TEST_FILE=str(RUN/'A-project.json'))
godot='D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
rows=[]
tests=[('storage','cad251_e_storage.gd','CANONICAL_STORAGE_GATE_PASS'),('A','cad251_assembly.gd','ASSEMBLY_PASS')]+[('D-'+case,'cad251_faces_solve.gd','FACE_SOLVES_PASS') for case in ['duplicate','translated','rotated','step','touching','reassigned']]+[('D-unit','cad251_faces_unit.gd','FACE_UNIT_PASS'),('D-negative','cad251_faces_negative.gd','FACE_NEGATIVE_PASS')]
for name,script,marker in tests:
    if script=='cad251_faces_solve.gd':env['UNICORE_FACE_CASE']=name[2:]
    else:env.pop('UNICORE_FACE_CASE',None)
    p=subprocess.run([godot,'--headless','--path',str(ROOT),'--log-file',str(RUN/(name+'.godot.log')),'--script','tests/'+script],env=env,cwd=ROOT,capture_output=True,timeout=480)
    (RUN/(name+'.stdout.txt')).write_bytes(p.stdout);(RUN/(name+'.stderr.txt')).write_bytes(p.stderr)
    passed=p.returncode==0 and marker.encode() in p.stdout and b'SCRIPT ERROR' not in p.stderr
    rows.append(dict(name=name,passed=passed,exit_code=p.returncode))
    (RUN/'verification.json').write_text(json.dumps(rows,indent=2));(OUT/'verification-current.json').write_text(json.dumps(dict(directory=str(RUN),results=str(RUN/'verification.json'))))
    print(name,passed,flush=True)
print('VERIFICATION_COMPLETE',all(r['passed'] for r in rows),flush=True)
