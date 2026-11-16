import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Real native validation/history/transform qualification, bounded analytic cases."""
import sys,json,base64,hashlib,math,time,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from native_occt import run
from cad_model import evaluate
from gmsh_study import mesh_study
from mesh_config import defaults
OUT=output_dir('CAD/cad24-completion');rows=[]
def save(): (OUT/'native-qualification.json').write_text(json.dumps(rows,indent=2))
def box(key,**kw):return dict(id=key,type='Box',dimensions=[.1,.2,.1],**kw)
def graph(nodes):return dict(schema=1,units='m',root=nodes[-1]['id'],nodes=nodes)
def boolean(a,b,kind):return graph([a,b,dict(id='result',type=kind,base=a['id'],tool=b['id'])])
_,raw=run(action='box',dimensions=[.1,.2,.1]);base,_=run(raw);v=base['validation'];assert v['status']=='VALID'
for name,matrix,volume,area in [
 ('translation',[1,0,0,1,0,1,0,2,0,0,1,3],v['volume'],v['area']),
 ('rotation',[0,-1,0,0,1,0,0,0,0,0,1,0],v['volume'],v['area']),
 ('uniform-scale',[2,0,0,0,0,2,0,0,0,0,2,0],v['volume']*8,v['area']*4),
 ('mirror',[-1,0,0,0,0,1,0,0,0,0,1,0],v['volume'],v['area']),
 ('nonuniform',[2,0,0,0,0,3,0,0,0,0,4,0],v['volume']*24,2*(.2*.6+.2*.4+.6*.4))]:
    r,transformed=run(raw,'transform',matrix=matrix);p=r['validation'];assert p['status']=='VALID'
    assert abs(p['volume']/volume-1)<1e-9 and abs(p['area']/area-1)<1e-9
    center=[sum(matrix[4*i+j]*v['centroid'][j] for j in range(3))+matrix[4*i+3] for i in range(3)]
    assert max(abs(a-b) for a,b in zip(center,p['centroid']))<1e-10
    if name=='mirror':
        for face in p['faces']:
            assert sum((face['center'][i]-p['centroid'][i])*face['plane_outward_normal'][i] for i in range(3))>0,'Reflected box face normal points inward'
    rows.append(dict(case=name,outcome='PASS',receipt=r));save()
for action,expected in [('fuse',.003),('cut',.001),('common',.001)]:
    _,tool=run(raw,'transform',matrix=[1,0,0,.05,0,1,0,0,0,0,1,0]);r,output=run(raw,action,tool=tool)
    assert abs(r['validation']['volume']/expected-1)<1e-9 and r['face_history']
    assert all(k in h for h in r['face_history'] for k in ['modified','generated','deleted','unchanged'])
    rows.append(dict(case=action,outcome='PASS',receipt=r));save()
try:run(b'not a BREP')
except ValueError as e:rows.append(dict(case='malformed-brep',outcome='PASS',diagnostic=str(e)));save()
else:raise AssertionError('Malformed BREP accepted')
source=(ROOT/'tests/fixtures/step/bar.step').read_bytes()
step=dict(id='step',type='STEP',source_base64=base64.b64encode(source).decode(),source_sha256=hashlib.sha256(source).hexdigest())
curved_source=(ROOT/'tests/fixtures/step/cylinder.step').read_bytes()
curved_step=dict(id='curved-step',type='STEP',source_base64=base64.b64encode(curved_source).decode(),source_sha256=hashlib.sha256(curved_source).hexdigest())
cases=[('overlap',boolean(box('a'),box('b',position=[.05,0,0]),'Union')),
 ('coincident',boolean(box('a'),box('b',position=[.1,0,0]),'Union')),
 ('through-hole',boolean(box('a'),dict(id='b',type='Cylinder',dimensions=[.04,.3,.04]),'Cut')),
 ('blind-hole',boolean(box('a'),dict(id='b',type='Cylinder',dimensions=[.04,.1,.04],position=[0,.1,0]),'Cut')),
 ('pipe',graph([dict(id='pipe',type='Pipe',dimensions=[.1,.2,.1],inner_diameter=.098)])),
 ('step-scaled',graph([dict(step,scale=[2,2,2],position=[.1,.2,.3])])),
 ('step-mirrored',graph([dict(step,scale=[-1,1,1])])),
 ('step-nonuniform',graph([dict(step,scale=[2,3,4])])),
 ('step-rotated',graph([dict(step,rotation=[23,37,19])])),
 ('step-axis',graph([dict(step,axis_direction=[1,2,3],axis_point=[.1,.2,.3],axis_angle=37)])),
 ('step-cylinder-scaled',graph([dict(curved_step,scale=[2,2,2])])),
 ('step-cylinder-rotated',graph([dict(curved_step,scale=[2,2,2],rotation=[17,31,23])])),
 ('step-cylinder-mirrored',graph([dict(curved_step,scale=[-1,1,1])])),
 ('step-step',boolean(step,dict(step,id='other',position=[0,.05,0]),'Union'))]
for name,model in cases:
    result=evaluate(dict(model=model,part_id=name,quality=8));p=result['part']
    assert p['cad_validation']['status']=='VALID' and p['cad_topology_metadata']['native_history']
    second=evaluate(dict(model=copy.deepcopy(model),part_id=name,quality=8));assert set(second['part']['cad_faces'])==set(p['cad_faces'])
    try:mesh=mesh_study(ROOT,dict(parts=[dict(p,id=name)],mesh_divisions=3),.07)
    except Exception as e:
        rows.append(dict(case=name,outcome='MESH_FAILURE',validation=p['cad_validation'],diagnostic=str(e),requested_size_m=.07));save()
        if name!='pipe':raise
        refined=dict(p,id=name);refined['mesh_settings']=defaults(.01);refined['mesh_settings'].update(curvature_points=64,min_size=.00025)
        recovered=mesh_study(ROOT,dict(parts=[refined],mesh_divisions=3),.01)
        assert recovered['quality']['minimum_jacobian']>0
        rows.append(dict(case='pipe-refined',outcome='PASS',mesh_nodes=len(recovered['nodes']),mesh_elements=len(recovered['elements']),settings=refined['mesh_settings']));save()
        continue
    assert mesh['quality']['minimum_jacobian']>0
    (OUT/(name+'.json')).write_text(json.dumps(dict(schema=1,revision=1,units='m-N-Pa-kg',parts=[dict(p,id=name,name=name,material=dict(E=210e9,nu=0,density=7850),support='',load_face='',force=[0,1000,0])],mesh={},results={},analysis=dict(type='static_structural',backend='calculix',element='TET4'))))
    rows.append(dict(case=name,outcome='PASS',validation=p['cad_validation'],history=p['cad_topology_metadata'],mesh_nodes=len(mesh['nodes']),mesh_elements=len(mesh['elements'])));save()
print('CAD24_NATIVE_PASS')
