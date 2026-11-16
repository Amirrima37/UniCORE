"""Real OCC surface preview smoke for the shipped immutable STEP fixtures."""
import base64
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.engines.gmsh_study import preview_step

ROOT = Path(__file__).resolve().parents[1]
for name, expected_faces in [('bar', 6), ('cylinder', 3)]:
    source = (ROOT/'tests/fixtures/step'/f'{name}.step').read_bytes()
    digest = hashlib.sha256(source).hexdigest()
    part = {'id': name, 'cad_base64': base64.b64encode(source).decode(), 'cad_sha256': digest}
    preview = preview_step(ROOT, part)
    assert preview['source_sha256'] == digest
    assert len(preview['surface_regions'][name]) == expected_faces
    assert len(preview['face_areas']) == expected_faces
    assert all(preview['surface_regions'][name][face] for face in preview['face_areas'])
    assert preview['cad_volume'] > 0
    print(name, 'volume=', preview['cad_volume'], 'faces=', len(preview['face_areas']), 'display_vertices=', len(preview['nodes']))
print('STEP_PREVIEW_PASS')
