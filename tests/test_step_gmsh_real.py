"""Real pinned Gmsh/OCC STEP roundtrip and TET4 boundary verification."""
import hashlib
import base64
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.tools/engines/gmsh-4.15.2-Windows64-sdk/lib'))
sys.path.insert(0, str(ROOT / 'scripts/engines'))
import gmsh
from gmsh_study import mesh_study

OUT = ROOT / 'tests/fixtures/step'
OUT.mkdir(parents=True, exist_ok=True)
receipt = {}
for kind in ('bar', 'cylinder'):
    source = OUT / (kind + '.step')
    gmsh.initialize([], readConfigFiles=False)
    try:
        gmsh.option.setString('Geometry.OCCTargetUnit', 'M')
        if kind == 'bar':
            solid = gmsh.model.occ.addBox(0, 0, 0, .1, 1, .1)
            expected = .01
            expected_faces = 6
            size = .1
        else:
            solid = gmsh.model.occ.addCylinder(0, 0, 0, 0, .2, 0, .1)
            expected = math.pi * .1 ** 2 * .2
            expected_faces = 3
            size = .06
        gmsh.model.occ.synchronize()
        gmsh.write(str(source))
    finally:
        gmsh.finalize()
    sha = hashlib.sha256(source.read_bytes()).hexdigest()
    gmsh.initialize([], readConfigFiles=False)
    try:
        gmsh.option.setString('Geometry.OCCTargetUnit', 'M')
        entities = gmsh.model.occ.importShapes(str(source), highestDimOnly=True)
        assert len(entities) == 1 and entities[0][0] == 3, entities
        tag = entities[0][1]
        volume = gmsh.model.occ.getMass(3, tag)
        bounds = gmsh.model.occ.getBoundingBox(3, tag)
        gmsh.model.occ.synchronize()
        faces = gmsh.model.getBoundary([(3, tag)], oriented=False)
        assert len(faces) == expected_faces, faces
        assert abs(volume - expected) / expected < 1e-5, (volume, expected)
    finally:
        gmsh.finalize()
    part = dict(id=kind, kind='CAD', name=kind, dimensions=[.1, 1, .1], position=[0, 0, 0], rotation=[0, 0, 0], scale=[1, 1, 1], cad_base64=base64.b64encode(source.read_bytes()).decode(), cad_sha256=sha)
    mesh = mesh_study(ROOT, dict(parts=[part], mesh_divisions=4), size)
    assert mesh['elements'] and mesh['quality']['minimum_jacobian'] > 0
    assert len(mesh['surface_regions'][kind]) == expected_faces
    assert abs(mesh['provenance']['cad_volume'] - expected) / expected < 1e-5
    receipt[kind] = dict(sha256=sha, cad_volume=volume, expected_volume=expected, bounds=bounds, faces=len(faces), nodes=len(mesh['nodes']), tet4=len(mesh['elements']), mesh_volume=mesh['provenance']['mesh_volume'], minimum_jacobian=mesh['quality']['minimum_jacobian'], physical_surfaces=list(mesh['surface_regions'][kind]))
    (OUT / (kind + '.mesh.json')).write_text(json.dumps(mesh), encoding='utf-8')
(OUT / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
print(json.dumps(receipt, indent=2))
