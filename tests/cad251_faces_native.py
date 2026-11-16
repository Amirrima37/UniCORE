import os,sys,time,json,copy,base64,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from development_paths import output_dir
OUT=output_dir('CAD/cad251-face-identity/attempt-'+str(time.time_ns()))
os.environ['UNICORE_CAD_JOB_TEMP']=str(OUT/'native');os.environ['UNICORE_INTERFERENCE_CACHE_ROOT']=str(OUT/'pair-cache')
p=json.loads((Path((ROOT/'interference-attempt.txt').read_text())/'source-part.json').read_text())
from native_occt import run
from instance_placement import place,imported_faces
from face_identity import source_names
from gmsh_study import mesh_study
from mesh_config import defaults
raw=base64.b64decode(p['cad_base64']);r,_=run(raw);before=r['validation'];rows=[]
for angles in [[0,0,0],[math.pi/2,0,0],[0,math.pi/2,0],[0,0,math.pi/2],[.2,.3,.4]]:
    part=copy.deepcopy(p);part['rotation']=angles;part['position']=[2,3,4]
    placed,after=place(raw,part,before)
    assert set(after['instance_face_names'].values())==set(p['cad_faces'])
    rows.append(dict(rotation=angles,world=after,source_sha256=p['cad_sha256']))
ambiguous=copy.deepcopy(p);key=p['cad_faces'][0];ambiguous['cad_faces'].append('alias');ambiguous['cad_face_centers']['alias']=p['cad_face_centers'][key];ambiguous['cad_face_areas']['alias']=p['cad_face_areas'][key]
try:source_names(ambiguous,before)
except ValueError as error:rows.append(dict(ambiguity_blocked=str(error)))
else:raise AssertionError('Ambiguous source face accepted')
for order in [1,2]:
    part=copy.deepcopy(p);part['position']=[2,0,0];part['rotation']=[.2,.3,.4];part['mesh_settings']=defaults(.05);part['mesh_settings'].update(schema=2,order=order)
    mesh=mesh_study(ROOT,dict(parts=[part]),.05)
    assert mesh['face_resolution']['instance_uuid']==part['instance_uuid'] and set(mesh['face_resolution']['source_faces'])==set(p['cad_faces'])
    (OUT/('mesh-'+str(order)+'.json')).write_text(json.dumps(mesh))
    rows.append(dict(order=order,proof=mesh['face_resolution'],nodes=len(mesh['nodes']),elements=len(mesh['elements'])))
    print('FACE_MESH_PASS',order,flush=True)
(OUT/'source-part.json').write_text(json.dumps(p));(OUT/'native.json').write_text(json.dumps(rows,indent=2));(ROOT/'face-identity-attempt.txt').write_text(str(OUT))
print('FACE_NATIVE_PASS',OUT,flush=True)
