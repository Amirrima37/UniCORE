"""Copy only owned jobs matching saved numerical result SHA-256 evidence."""
import os,json,hashlib,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=root/'docs/architecture/evidence/calculix'
owned=Path(os.environ['APPDATA'])/'Godot/app_userdata/UniCORE/calculix_jobs'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
rows=[]
for kind in ['Box','Cylinder']:
    study=json.loads((base/'workbench'/f'{kind}.json').read_text())
    proof=study['results']['provenance']
    matches=[job for job in owned.iterdir() if (job/'model.inp').is_file() and (job/'model.dat').is_file() and sha(job/'model.inp')==proof['input_sha256'] and sha(job/'model.dat')==proof['dat_sha256']]
    assert matches,kind
    source=max(matches,key=lambda p:p.stat().st_mtime)
    destination=base/'workbench'/f'{kind}-job';destination.mkdir(exist_ok=True)
    for file in source.iterdir():
        if file.is_file():shutil.copy2(file,destination/file.name)
    rows.append(dict(kind=kind,source=str(source),input_sha256=proof['input_sha256'],dat_sha256=proof['dat_sha256']))
(base/'workbench'/'archived-jobs.json').write_text(json.dumps(rows,indent=2))
print('ACTUAL_WORKBENCH_JOBS_ARCHIVED')
