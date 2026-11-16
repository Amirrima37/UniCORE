import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Collect current-run evidence without claiming missing native acceptance."""
import json, hashlib, shutil, struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/architecture/evidence/cad24'
p=OUT/'final-receipt.json';receipt=json.loads(p.read_text())
receipt['boundary_test']=json.loads((OUT/'boundary-receipt.json').read_text())
receipt['unmet_criteria']=['native validation','native per-face history','persistent history naming','new native transformations','full geometry qualification matrix','aggregate artifact retention','long-duration memory campaign','full CAD24 GUI workflow']
receipt['production_files_changed']=['scripts/engines/cad_model.py','core/cae/cae_document.gd','core/cae/calculix_workbench.gd','ui/cae/cae_workspace.gd']
receipt['source_hashes']={s:hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in receipt['production_files_changed']+['tests/run_cad24.py','tests/cad24_boundary.gd','tests/summarize_cad24.py']}
receipt['preservation_baseline']='Previously recorded CAD23 28/28; see current campaign cases for rerun'
receipt['pre_edit_source_hashes_available']=False
receipt['screenshots']=[]
# Only collect screenshots if the present campaign actually passed GUI execution.
if any(r['name']=='cad23-gui' and r['outcome']=='PASS' for r in receipt['cases']):
    gui=next(r for r in receipt['cases'] if r['name']=='cad23-gui')
    started=int(gui['evidence'].rsplit('-',1)[1])/1e9
    for source in (ROOT/'docs/architecture/evidence/cad23/screenshots').glob('*.png'):
        if source.stat().st_mtime < started:continue
        target=OUT/'screenshots'/source.name;target.parent.mkdir(exist_ok=True);shutil.copy2(source,target)
        raw=target.read_bytes();w,h=struct.unpack('>II',raw[16:24])
        receipt['screenshots'].append(dict(path=str(target.relative_to(ROOT)),width=w,height=h,sha256=hashlib.sha256(raw).hexdigest(),scope='CAD23 preservation; not full CAD24 acceptance'))
for checkpoint,names in [('21',['geometry-receipt.json','solver-receipt.json']),('23',['numerical.json','lifecycle.json'])]:
    for name in names:
        source=ROOT/'docs/architecture/evidence'/('cad'+checkpoint)/name
        if source.exists():shutil.copy2(source,OUT/('cad'+checkpoint+'-'+name))
receipt['verdict']='PARTIAL'
p.write_text(json.dumps(receipt,indent=2))
print('CAD24_PARTIAL',len(receipt['cases']),'campaign cases')
