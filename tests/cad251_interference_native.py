"""Genuine native solid-pair matrix; no tessellation authorizes classification."""
import os,sys,json,math,time,base64,hashlib,uuid
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from development_paths import output_dir
OUT=output_dir('CAD/cad251-interference/attempt-'+str(time.time_ns()))
os.environ['UNICORE_CAD_JOB_TEMP']=str(OUT/'native');os.environ['UNICORE_INTERFERENCE_CACHE_ROOT']=str(OUT/'pair-cache')
import assembly_interference as interference
from native_occt import run
from instance_placement import matrix
def shape(action,d):return run(action=action,dimensions=d)[1]
def moved(raw,xyz=[0,0,0],r=[0,0,0]):return run(raw,'transform',matrix=matrix(dict(position=xyz,rotation=r)))[1]
box=shape('box',[.1,.4,.1]);cyl=shape('cylinder',[.2,.4,.2]);rows=[]
def check(name,a,b,expected):
    result=interference.classify(a,b,use_cache=False)
    rows.append(dict(case=name,expected=expected,result=result))
    (OUT/'native-matrix.json').write_text(json.dumps(rows,indent=2))
    assert result['classification'] in expected,(name,result)
    print(name,result['classification'],flush=True)
check('separated-boxes',box,moved(box,[.3,0,0]),['SEPARATED'])
check('face-touch',box,moved(box,[.1,0,0]),['TOUCHING'])
check('edge-touch',box,moved(box,[.1,.4,0]),['TOUCHING'])
check('overlap',box,moved(box,[.05,0,0]),['OVERLAPPING'])
angle=math.pi/4;rot=moved(box,r=[0,0,angle]);offset=.12/math.sqrt(2)
check('rotated-disjoint-overlapping-aabb',rot,moved(box,[offset,offset,0],[0,0,angle]),['SEPARATED'])
check('separated-cylinders-overlapping-aabb',cyl,moved(cyl,[.15,0,.15]),['SEPARATED'])
check('tangent-cylinders',cyl,moved(cyl,[.2,0,0]),['TOUCHING'])
check('cylinder-through-box',cyl,box,['OVERLAPPING'])
outer=shape('cylinder',[.4,.4,.4]);inner=shape('cylinder',[.3,.6,.3]);tube=run(outer,'cut',tool=inner)[1]
check('hollow-tube-object',tube,shape('box',[.1,.1,.1]),['SEPARATED'])
step=run((ROOT/'tests/fixtures/step/bar.step').read_bytes(),'step')[1]
check('transformed-step',moved(step,[0,0,0],[.1,.2,.3]),moved(step,[3,0,0],[.3,.2,.1]),['SEPARATED'])
check('same-definition-instances',rot,moved(box,[offset,offset,0],[0,0,angle]),['SEPARATED'])
check('small-positive-overlap',box,moved(box,[.1-1e-6,0,0]),['OVERLAPPING','INCONCLUSIVE'])
check('near-coincident',box,moved(box,[.1+1e-8,0,0]),['TOUCHING','INCONCLUSIVE'])
check('invalid-brep',b'broken BREP',box,['INVALID','INCONCLUSIVE'])
with patch.object(interference,'run',side_effect=ValueError('Injected native Boolean failure')):
    check('boolean-failure',box,box,['INCONCLUSIVE'])
os.environ['UNICORE_OCCT_TIMEOUT_S']='0'
check('real-timeout',box,box,['INCONCLUSIVE'])
os.environ.pop('UNICORE_OCCT_TIMEOUT_S')
cancel=OUT/'cancel';cancel.write_text('cancel');os.environ['UNICORE_NATIVE_CANCEL_FILE']=str(cancel)
check('real-cancellation',box,box,['INCONCLUSIVE'])
os.environ.pop('UNICORE_NATIVE_CANCEL_FILE')
first=interference.classify(box,moved(box,[.3,0,0]),revisions=[1,1]);second=interference.classify(box,moved(box,[.3,0,0]),revisions=[1,1]);changed=interference.classify(box,moved(box,[.3,0,0]),revisions=[1,2])
assert not first['cache_hit'] and second['cache_hit'] and not changed['cache_hit']
(OUT/'cache.json').write_text(json.dumps([first,second,changed],indent=2))
validation=run(box)[0]['validation']
p=dict(id=str(uuid.uuid4()),instance_uuid=str(uuid.uuid4()),definition_uuid=str(uuid.uuid4()),kind='CAD',name='Interference bar',dimensions=[.1,.4,.1],position=[0,0,0],rotation=[0,0,0],scale=[1,1,1],cad_base64=base64.b64encode(box).decode(),cad_sha256=hashlib.sha256(box).hexdigest(),cad_format='brep',cad_source_units='m',cad_source_to_m=1.,cad_faces=['face'+str(f['slot']) for f in validation['faces']],cad_face_areas={'face'+str(f['slot']):f['area'] for f in validation['faces']},cad_face_centers={'face'+str(f['slot']):f['center'] for f in validation['faces']},support='',load_face='',force=[0,1000,0],material={'name':'Steel','E':100e9,'nu':0.,'density':7800.})
p['support']=min(p['cad_faces'],key=lambda k:p['cad_face_centers'][k][1]);p['load_face']=max(p['cad_faces'],key=lambda k:p['cad_face_centers'][k][1])
(OUT/'source-part.json').write_text(json.dumps(p))
(ROOT/'interference-attempt.txt').write_text(str(OUT))
print('INTERFERENCE_NATIVE_PASS',OUT,flush=True)
