"""Validate destination copies before source removal; output stays external."""
from storage_cleanup11 import *
sys.path.insert(0,str(ROOT/'scripts/engines'))
from development_paths import sdk_root,godot_environment_root,output_dir
import shutil
OUT=ROOT/'docs/maintenance/evidence/external-migration'
work=output_dir('CAD/external-migration-'+str(time.time_ns()))
env=os.environ.copy();env.update(UNICORE_PYTHON=sys.executable,APPDATA=str(godot_environment_root()/'roaming'),LOCALAPPDATA=str(godot_environment_root()/'local'))
godot='D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
pins=json.loads((ROOT/'docs/architecture/evidence/cad24-completion/final-receipt.json').read_text())['pinned_binaries']
hashes={p:dict(expected=h['after'],actual=sha(Path(p))) for p,h in pins.items()}
backup=sdk_root()/'migration-original-build';backup.mkdir(exist_ok=True)
for name in ['unicore_occt_worker.exe','make_occt_fixtures.exe','build-manifest.json']:
 if not (backup/name).exists():shutil.copy2(sdk_root()/name,backup/name)
rows=[]
steps=[('build',['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','native/build_occt.ps1'],240),('editor',[godot,'--headless','--editor','--path',str(ROOT),'--quit'],180),('native',[sys.executable,'tests/cad24_native.py'],900),('history',[sys.executable,'tests/cad24_history.py'],180),('structural',[godot,'--headless','--path',str(ROOT),'-s','res://tests/cad24_numerical.gd'],900),('regressions',[sys.executable,'native/run_regressions.py','--godot',godot,'--output',str(work/'regressions')],900)]
for name,cmd,timeout in steps:
 start=time.monotonic()
 try:
  p=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,timeout=timeout)
  (work/(name+'.stdout.txt')).write_bytes(p.stdout);(work/(name+'.stderr.txt')).write_bytes(p.stderr)
  row=dict(name=name,exit_code=p.returncode,passed=p.returncode==0 and b'SCRIPT ERROR:' not in p.stdout+p.stderr,seconds=time.monotonic()-start)
 except subprocess.TimeoutExpired as e:
  row=dict(name=name,exit_code=None,passed=False,error='timeout');(work/(name+'.stdout.txt')).write_bytes(e.stdout or b'');(work/(name+'.stderr.txt')).write_bytes(e.stderr or b'')
 rows.append(row);print(json.dumps(row),flush=True)
 result=dict(passed=all(r['passed'] for r in rows) and len(rows)==len(steps) and all(h['expected']==h['actual'] for h in hashes.values()),steps=rows,pins=hashes,external_output=str(work),sdk=str(sdk_root()),godot_environment=str(godot_environment_root()))
 (OUT/'validation.json').write_text(json.dumps(result,indent=2))
 if not row['passed']:break
if not result['passed']:raise SystemExit(1)
