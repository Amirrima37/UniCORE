import sys,os,json,base64,copy,hashlib,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'));sys.path.insert(0,str(ROOT/'.tools/engines/gmsh-4.15.2-Windows64-sdk/lib'))
OUT=Path((ROOT/'face-identity-attempt.txt').read_text().strip());os.environ['UNICORE_CAD_JOB_TEMP']=str(OUT/'partition-native')
from native_occt import run
from instance_placement import place,imported_faces,matrix
from face_identity import source_names
import gmsh
p=json.loads((OUT/'source-part.json').read_text());raw=base64.b64decode(p['cad_base64']);before=run(raw)[0]['validation'];placed,native=place(raw,p,before)
path=OUT/'partition-source.brep';path.write_bytes(placed)
gmsh.initialize([],readConfigFiles=False)
try:
    volume=gmsh.model.occ.importShapes(str(path),highestDimOnly=True)
    patch=gmsh.model.occ.addRectangle(-.05,-.2,.05,.1,.2)
    gmsh.model.occ.fragment(volume,[(2,patch)])
    gmsh.model.occ.synchronize()
    assert len(gmsh.model.getEntities(3))==1
    mapping=imported_faces(native)
    assert len(mapping)==7 and len(set(mapping.values()))==6,mapping
    (OUT/'partition.json').write_text(json.dumps(dict(mapping=mapping,native_faces=6,gmsh_surfaces=7,verified=True)))
finally:gmsh.finalize()
# A valid grooved cylinder has two coplanar top faces with the same area and
# centroid, but different inertia and bounds. Weak legacy evidence is ambiguous.
outer=run(action='cylinder',dimensions=[.4,.2,.4])[1]
ring=run(action='cylinder',dimensions=[.3,.06,.3])[1]
inner=run(action='cylinder',dimensions=[2*math.sqrt(.0175),.08,2*math.sqrt(.0175)])[1]
ring=run(ring,'cut',tool=inner)[1]
ring=run(ring,'transform',matrix=matrix(dict(position=[0,.1,0])))[1]
body=run(outer,'cut',tool=ring)[1];validation=run(body)[0]['validation']
q=copy.deepcopy(p);q.update(cad_base64=base64.b64encode(body).decode(),cad_sha256=hashlib.sha256(body).hexdigest(),dimensions=[.4,.2,.4],cad_faces=[],cad_face_areas={},cad_face_centers={},support='',load_face='')
for f in validation['faces']:
    name='legacy-'+str(f['slot']);q['cad_faces'].append(name);q['cad_face_areas'][name]=f['area'];q['cad_face_centers'][name]=f['center']
try:source_names(q,validation)
except ValueError as error:diagnostic=str(error)
else:raise AssertionError('Equal-area, equal-centroid faces incorrectly resolved from weak descriptors')
q['support']=min(q['cad_faces'],key=lambda k:q['cad_face_centers'][k][1]);q['load_face']=max(q['cad_faces'],key=lambda k:q['cad_face_centers'][k][1])
(OUT/'symmetric-part.json').write_text(json.dumps(q))
strong=copy.deepcopy(q);strong['cad_definition_faces']={'legacy-'+str(f['slot']):f for f in validation['faces']}
assert len(source_names(strong,validation))==len(validation['faces'])
(OUT/'symmetric.json').write_text(json.dumps(dict(validity=validation,weak_blocked=diagnostic,strong_verified=True),indent=2))
print('FACE_PARTITION_SYMMETRY_PASS')
