import sys,os,json,base64,hashlib,uuid,copy,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/engines'))
from development_paths import output_dir
OUT=output_dir('CAD/cad251-native-placement/attempt-'+str(__import__('time').time_ns()))
os.environ['UNICORE_CAD_JOB_TEMP']=str(OUT/'native')
os.environ['UNICORE_MESH_JOB_TEMP']=str(OUT/'mesh-temp');Path(os.environ['UNICORE_MESH_JOB_TEMP']).mkdir()
from native_occt import run
from instance_placement import place
from gmsh_study import mesh_study
from mesh_config import defaults
receipt,raw=run(action='box',dimensions=[.1,.4,.1])
v=receipt['validation']
part=dict(id=str(uuid.uuid4()),instance_uuid=str(uuid.uuid4()),definition_uuid=str(uuid.uuid4()),kind='CAD',name='Shared bar',dimensions=[.1,.4,.1],position=[0,0,0],rotation=[0,0,0],scale=[1,1,1],cad_base64=base64.b64encode(raw).decode(),cad_sha256=hashlib.sha256(raw).hexdigest(),cad_format='brep',cad_source_units='m',cad_source_to_m=1.,cad_faces=['face'+str(f['slot']) for f in v['faces']],cad_face_areas={'face'+str(f['slot']):f['area'] for f in v['faces']},cad_face_centers={'face'+str(f['slot']):f['center'] for f in v['faces']},support='',load_face='',force=[0,1000,0],material={'name':'Steel','E':100e9,'nu':0.,'density':7800.})
part['support']=min(part['cad_faces'],key=lambda k:part['cad_face_centers'][k][1]);part['load_face']=max(part['cad_faces'],key=lambda k:part['cad_face_centers'][k][1])
rows=[]
for rotation in [[0,0,0],[math.pi/2,0,0],[0,math.pi/2,0],[0,0,math.pi/2],[.2,.3,.4]]:
    p=copy.deepcopy(part);p['position']=[2,3,4];p['rotation']=rotation
    placed,native=place(raw,p,v)
    rows.append(dict(rotation=rotation,validation=native))
    print('NATIVE_PASS',rotation,flush=True)
for order in [1,2]:
    p=copy.deepcopy(part);p['position']=[2,0,0];p['rotation']=[0,0,math.pi/2]
    p['mesh_settings']=defaults(.05);p['mesh_settings'].update(schema=2,order=order)
    mesh=mesh_study(ROOT,dict(parts=[p],revision=1),.05)
    assert min(n[0] for n in mesh['nodes'])>1.79 and max(n[0] for n in mesh['nodes'])<2.21
    assert mesh['instance_placement']['validation']['status']=='VALID'
    (OUT/('mesh-'+str(order)+'.json')).write_text(json.dumps(mesh))
    rows.append(dict(order=order,nodes=len(mesh['nodes']),elements=len(mesh['elements'])))
    print('MESH_PASS',order,flush=True)
(OUT/'source-part.json').write_text(json.dumps(part))
(OUT/'placement.json').write_text(json.dumps(rows,indent=2))
print('PLACEMENT_PASS',OUT,flush=True)
