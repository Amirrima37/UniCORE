"""Read-only source/binary inventory; lightweight receipt, external raw inventory."""
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''): h.update(block)
    return h.hexdigest()


def collect():
    prior = json.loads((ROOT/'docs/architecture/evidence/cad24-completion/final-receipt.json').read_text())
    sources = subprocess.check_output([sys.executable, 'scripts/source_files.py'], cwd=ROOT, text=True).splitlines()
    hashes = {name: digest(ROOT/name) for name in sources if (ROOT/name).is_file()}
    pins = {}
    for name, row in prior['pinned_binaries'].items():
        path = Path(name)
        actual = digest(path) if path.is_file() else None
        pins[name] = dict(expected=row['before'], actual=actual, unchanged=actual == row['before'])
    return dict(branch=subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),
                head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                dirty_tree=subprocess.check_output(['git','status','--short','--untracked-files=normal'],cwd=ROOT,text=True).splitlines(),
                source_hashes=hashes, pinned_binaries=pins,
                paths=dict(sdk=str(sdk_root()),godot=str(godot_environment_root()),outputs=str(test_output_root())),
                path_exists={str(p):p.exists() for p in (sdk_root(),godot_environment_root(),test_output_root())},
                source_inventory_bytes=sum((ROOT/name).stat().st_size for name in sources if (ROOT/name).is_file()),
                size_scope='Focused source inventory only; excluded caches/vendor/history not traversed')


if __name__ == '__main__':
    output=test_output_root()/'CAD/cad25'/('inventory-'+str(time.time_ns()))
    output.mkdir(parents=True)
    receipt=collect()
    (output/'inventory.json').write_text(json.dumps(receipt,indent=2))
    print(json.dumps(dict(path=str(output/'inventory.json'),pins_unchanged=all(r['unchanged'] for r in receipt['pinned_binaries'].values()),sources=len(receipt['source_hashes']))))
