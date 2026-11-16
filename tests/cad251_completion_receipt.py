"""Record completion work without modifying the original PARTIAL receipt."""
import hashlib,json,sys
from pathlib import Path
from cad25_inventory import collect
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/engines'))
from development_paths import test_output_root
out=test_output_root()/'CAD/cad251-completion'
run=out/'three-material/CAD/cad251'
baseline=Path('D:/PROJECT/TEST_OUTPUTS/CAD/cad25/inventory-1794693336808567600/inventory.json')
after=collect()
files=['tests/cad251_numerical.gd','tests/cad251_deck_audit.py','tests/cad251_completion_receipt.py','docs/architecture/CAD_MESHING_2_5_1.md']
attempts=[]
for p in sorted(run.glob('attempt-*/receipt.json')):
    row=json.loads(p.read_text());row['receipt']=str(p);attempts.append(row)
def read(name):
    p=run/name
    return json.loads(p.read_text()) if p.exists() else None
receipt=dict(schema=1,checkpoint='CAD 2.5.1 completion',verdict='PARTIAL',
 head=after['head'],branch=after['branch'],baseline_inventory=str(baseline),
 dirty_tree=after['dirty_tree'],pinned_binaries=after['pinned_binaries'],paths=after['paths'],
 changed_files={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in files},
 attempts=attempts,numerical=read('numerical.json'),deck_audit=read('deck-audit.json'),
 repository_bytes_before=None,repository_bytes_after=None,
 focused_source_bytes_after=after['source_inventory_bytes'],
 original_partial_receipt_sha256=hashlib.sha256((ROOT/'docs/architecture/evidence/cad251/final-receipt.json').read_bytes()).hexdigest(),
 current_completion_regressions=False,current_completion_lifecycle=False,
 missing=['Reusable definition/instance model','Native instance transform integration','Native pair inspection replacing AABB gate','Assembly face identity','Complete GUI and Undo/Redo acceptance','Complete numerical matrix','Lifecycle qualification','Final preservation campaign','Repository total footprint'])
p=ROOT/'docs/architecture/evidence/cad251-completion/final-receipt.json';p.parent.mkdir(parents=True,exist_ok=True)
p.write_text(json.dumps(receipt,indent=2));print(p,'PARTIAL')
