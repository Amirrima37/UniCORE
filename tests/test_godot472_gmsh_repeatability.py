import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
import json, subprocess, sys, hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=godot_environment_root()/'mesh-repeatability';base.mkdir(exist_ok=True)
rows=[]
for kind in ['Box','Cylinder']:
    source=base.parent/'workbench'/f'{kind}.json'
    hashes=[]
    for repeat in range(2):
        output=base/f'{kind}-{repeat}.json'
        p=subprocess.run([sys.executable,str(root/'scripts/engines/gmsh_study.py'),str(source),str(output),'0.1'],capture_output=True,timeout=90)
        (base/f'{kind}-{repeat}.stdout.txt').write_bytes(p.stdout)
        assert p.returncode==0,p.stderr
        mesh=json.loads(output.read_text())
        raw=json.dumps([mesh[k] for k in ['nodes','elements','node_tags','element_tags','surface_regions']],sort_keys=True).encode()
        hashes.append(hashlib.sha256(raw).hexdigest())
        rows.append(dict(kind=kind,repeat=repeat,elements=len(mesh['elements']),nodes=len(mesh['nodes']),sha256=hashes[-1],provenance=mesh['provenance']))
    assert hashes[0]==hashes[1],f'{kind}: repeated single-thread meshes differ'
(base/'results.json').write_text(json.dumps(rows,indent=2))
print('GMSH_REPEATABILITY_PASS')

