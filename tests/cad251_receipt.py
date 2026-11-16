"""Seal observed evidence; never infer checkpoint PASS from focused tests."""
import hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/engines'))
from development_paths import test_output_root
from cad25_inventory import collect
out=test_output_root()/'CAD/cad251'
baseline=Path('D:/PROJECT/TEST_OUTPUTS/CAD/cad25/inventory-1794689511361805300/inventory.json')
before=json.loads(baseline.read_text());after=collect()
files=['scripts/engines/assembly_mesh.py','scripts/engines/gmsh_study.py','scripts/engines/quadratic_prepare.py',
       'core/cae/calculix_workbench.gd','core/cae/calculix_backend.gd','core/cae/mesh_config.gd',
       'tests/cad251_numerical.gd','tests/cad251_gui.gd','tests/run_cad251.py','tests/cad251_deck_audit.py',
       'tests/cad251_receipt.py','docs/architecture/CAD_MESHING_2_5.md','docs/architecture/CAD_MESHING_2_5_1.md']
attempts=[]
for p in sorted(out.glob('attempt-*/receipt.json')):
    row=json.loads(p.read_text());row['receipt']=str(p);attempts.append(row)
screenshots=[]
for p in sorted(out.glob('*.png')):
    import struct
    width,height=struct.unpack('>II',p.read_bytes()[16:24])
    screenshots.append(dict(path=str(p),width=width,height=height,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
receipt=dict(schema=1,checkpoint='CAD 2.5.1',verdict='PARTIAL',head=after['head'],branch=after['branch'],
 baseline_inventory=str(baseline),dirty_tree=after['dirty_tree'],
 changed_files={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in files},
 pinned_binaries=after['pinned_binaries'],paths=after['paths'],attempts=attempts,
 numerical=json.loads((out/'numerical.json').read_text()),
 deck_audit=json.loads((out/'deck-audit.json').read_text()),screenshots=screenshots,
 default_regressions=json.loads((out/'default-regressions-1/receipt.json').read_text()),
 native_geometry='Evidence present; interrupted wrapper exit not retained',
 persistent_history=json.loads((out/'preservation/CAD/cad24-completion/persistent-history.json').read_text()),
 historical_numerical_rerun=False,lifecycle_qualified=False,final_editor_scan_qualified=False,
 repository_bytes_before=None,repository_bytes_after=None,
 focused_source_bytes_before=before['source_inventory_bytes'],focused_source_bytes_after=after['source_inventory_bytes'],
 missing='Reusable definitions/instances, native transforms, assembly face identity, full numerical/GUI/persistence/lifecycle matrix; see report')
p=ROOT/'docs/architecture/evidence/cad251/final-receipt.json';p.parent.mkdir(parents=True,exist_ok=True)
p.write_text(json.dumps(receipt,indent=2))
print(p,'PARTIAL', 'pins unchanged:',all(r['unchanged'] for r in after['pinned_binaries'].values()))
