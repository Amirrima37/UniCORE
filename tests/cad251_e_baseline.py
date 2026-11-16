import os,json,hashlib,subprocess,time,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from development_paths import output_dir,sdk_root,godot_environment_root
OUT=output_dir('CAD/cad251-final-acceptance/attempt-'+str(time.time_ns()))
def sha(p):
    with Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def footprint():
    size=count=0;errors=[]
    for base,dirs,files in os.walk(ROOT,onerror=lambda e:errors.append(str(e))):
        dirs[:]=[d for d in dirs if not (Path(base)/d).is_junction() and not (Path(base)/d).is_symlink()]
        for name in files:
            try:size+=(Path(base)/name).stat().st_size;count+=1
            except OSError as e:errors.append(str(e))
    return dict(bytes=size,files=count,errors=errors,scope='stat only; inaccessible/reparse targets excluded')
prior=json.loads((ROOT/'docs/architecture/evidence/cad251-face-identity/final-receipt.json').read_text())
pins={p:sha(p) for p in prior['preservation_hashes']};assert pins==prior['preservation_hashes']
manifest=json.loads((sdk_root()/'build-manifest.json').read_text())
for name,value in manifest['dlls'].items():assert sha(sdk_root()/'ucrt64/bin'/name)==value
status=subprocess.check_output(['git','status','--short','--untracked-files=all'],cwd=ROOT,text=True);(OUT/'git-status-before.txt').write_text(status)
(OUT/'baseline.json').write_text(json.dumps(dict(pins=pins,sdk_manifest=manifest,footprint=footprint(),godot_environment=str(godot_environment_root()),sdk=str(sdk_root()),head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),D_verdict=prior['verdict'],D_regressions=prior['regressions']['receipt']),indent=2))
(ROOT/'final-acceptance-attempt.txt').write_text(str(OUT));print(OUT)
