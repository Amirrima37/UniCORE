import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Real OCC construction/Booleans, independent volumes, topology and Gmsh."""
import sys,json,math,hashlib,base64,time,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from cad_model import evaluate,validate
from gmsh_study import mesh_study
OUT=output_dir('CAD/cad21');OUT.mkdir(parents=True,exist_ok=True)
def box(i='a',**kwargs):return dict(id=i,type='Box',dimensions=[.1,.2,.1],**kwargs)
def graph(nodes,root):return dict(schema=1,units='m',root=root,nodes=nodes)
def boolean(a,b,kind):return graph([a,b,dict(id='result',type=kind,base=a['id'],tool=b['id'])],'result')
raw=(ROOT/'tests/fixtures/step/bar.step').read_bytes()
step=dict(id='step',type='STEP',source_name='bar.step',source_base64=base64.b64encode(raw).decode(),source_sha256=hashlib.sha256(raw).hexdigest())
cases=[('fuse',boolean(box(),box('b',position=[.05,0,0]),'Union'),.003),('hole',boolean(box(),dict(id='tool',type='Cylinder',dimensions=[.04,.3,.04]),'Cut'),.002-math.pi*.02**2*.2),('pipe',graph([dict(id='pipe',type='Pipe',dimensions=[.1,.2,.1],inner_diameter=.06)],'pipe'),math.pi*(.05**2-.03**2)*.2),('intersect',boolean(box(),box('b',position=[.05,0,0]),'Intersect'),.001),('step-cut',boolean(step,dict(id='tool',type='Cylinder',dimensions=[.04,1.2,.04],position=[.05,.5,.05]),'Cut'),.01-math.pi*.02**2),('sphere',graph([dict(id='sphere',type='Sphere',dimensions=[.1,.1,.1])],'sphere'),4/3*math.pi*.05**3)]
rows=[]
for name,model,expected in cases:
    start=time.monotonic();r=evaluate(dict(model=model,part_id=name,quality=12));p=r['part']
    relative=abs(p['cad_volume']/expected-1);assert relative<1e-8,(name,p['cad_volume'],expected)
    p.update(id=name,name=name,material=dict(E=210e9,nu=0,density=7850),support='',load_face='',force=[0,1000,0])
    f=OUT/(name+'.json');f.write_text(json.dumps(dict(schema=1,revision=1,units='m-N-Pa-kg',parts=[p],mesh={},results={},analysis=dict(type='static_structural',backend='calculix',element='TET4')),indent=2))
    mesh=mesh_study(ROOT,dict(parts=[p],mesh_divisions=3),.04 if name!='step-cut' else .05)
    assert mesh['quality']['minimum_jacobian']>0 and set(mesh['groups'][name])==set(p['cad_faces'])
    row=dict(case=name,outcome='PASS',expected_volume_m3=expected,volume_m3=p['cad_volume'],relative_error=relative,faces=len(p['cad_faces']),nodes=len(mesh['nodes']),tet4=len(mesh['elements']),quality=mesh['quality'],elapsed_s=time.monotonic()-start,geometry_revision=p['cad_geometry_revision']);rows.append(row)
    (OUT/(name+'.mesh.json')).write_text(json.dumps(mesh));print(json.dumps(row),flush=True)
    (OUT/'geometry-receipt.json').write_text(json.dumps(rows,indent=2))
# Rebuild same exact graph and reimport serialized BRep: geometry stays identical.
original=evaluate(dict(model=graph([box()],'a'),quality=12));previous=original['part']['cad_face_descriptors']
reopened=evaluate(dict(model=json.loads(json.dumps(original['part']['cad_model'])),previous_faces=previous,quality=12))
assert set(reopened['part']['cad_faces'])==set(previous) and reopened['topology']['invalidated']==[]
split_model=boolean(box(),dict(id='slot',type='Box',dimensions=[.02,.12,.12],position=[0,.08,0]),'Cut')
split=evaluate(dict(model=split_model,previous_faces=previous,quality=12))
top=[key for key,d in previous.items() if abs(d['center'][1]-.1)<1e-8 and d['type']=='Plane'][0]
bottom=[key for key,d in previous.items() if abs(d['center'][1]+.1)<1e-8 and d['type']=='Plane'][0]
assert top in split['topology']['invalidated'] and bottom in split['topology']['preserved']
top_faces=[d for d in split['part']['cad_face_descriptors'].values() if abs(d['center'][1]-.1)<1e-8 and d['type']=='Plane'];assert len(top_faces)==2
edited=json.loads(json.dumps(cases[1][1]));edited['nodes'][1]['dimensions'][0]=.06
changed=evaluate(dict(model=edited,quality=12));assert changed['part']['cad_volume']<rows[1]['volume_m3']
negative=[]
for name,model in [('empty',boolean(box(),box('b',position=[1,0,0]),'Intersect')),('disjoint-union',boolean(box(),box('b',position=[1,0,0]),'Union')),('cycle',graph([dict(id='loop',type='Cut',base='loop',tool='a'),box()],'loop')),('corrupt-step',graph([{**step,'source_sha256':'invalid'}],'step'))]:
    try:evaluate(dict(model=model,quality=12))
    except Exception as error:negative.append(dict(case=name,outcome='PASS',error=str(error)))
    else:raise AssertionError('Invalid CAD accepted: '+name)
(OUT/'topology-receipt.json').write_text(json.dumps(dict(outcome='PASS',unchanged_faces_preserved=True,split_selected_face_invalidated=top,split_face_count=2,bottom_preserved=bottom,parameter_edit_volume_m3=changed['part']['cad_volume'],negative=negative),indent=2))
additional=[]
for name,model,expected in [
    ('scaled-rotated-box',graph([box(scale=[2,3,4],rotation=[15,30,45],position=[.3,.4,.5])],'a'),.002*24),
    ('scaled-cylinder',graph([dict(id='c',type='Cylinder',dimensions=[.1,.2,.1],scale=[2,3,2])],'c'),math.pi*.1**2*.6),
    ('blind-cavity',boolean(box(),dict(id='t',type='Cylinder',dimensions=[.04,.1,.04],position=[0,.1,0]),'Cut'),.002-math.pi*.02**2*.05),
    ('step-step',boolean(step,{**step,'id':'step2','position':[.05,0,0]},'Union'),.015)]:
    result=evaluate(dict(model=model,quality=12));actual=result['part']['cad_volume'];assert abs(actual/expected-1)<1e-8,(name,actual,expected)
    additional.append(dict(case=name,outcome='PASS',volume_m3=actual,expected_m3=expected))
(OUT/'additional-geometry.json').write_text(json.dumps(additional,indent=2))
unit_cases=[]
for token,unit,multiplier in [(b'$', 'm',1e9),(b'.CENTI.','cm',1e3)]:
    changed_raw=raw.replace(b'SI_UNIT(.MILLI.,.METRE.)',b'SI_UNIT('+token+b',.METRE.)')
    assert changed_raw!=raw
    node={**step,'source_base64':base64.b64encode(changed_raw).decode(),'source_sha256':hashlib.sha256(changed_raw).hexdigest()}
    node.pop('source_units',None);node.pop('source_to_m',None)
    result=evaluate(dict(model=graph([node],'step'),quality=8));actual=result['part']['cad_volume']
    assert abs(actual/(.01*multiplier)-1)<1e-8 and node['source_units']==unit
    unit_cases.append(dict(unit=unit,outcome='PASS',volume_m3=actual,source_to_m=node['source_to_m']))
(OUT/'units-receipt.json').write_text(json.dumps(unit_cases,indent=2))
# Genuine multi-solid STEP import must be rejected rather than selecting body 1.
import gmsh
with tempfile.TemporaryDirectory(prefix='cad21-assembly-') as temporary:
    gmsh.initialize([],readConfigFiles=False)
    try:
        gmsh.model.occ.addBox(0,0,0,.1,.1,.1);gmsh.model.occ.addBox(.3,0,0,.1,.1,.1);gmsh.model.occ.synchronize()
        file=Path(temporary)/'assembly.step';gmsh.write(str(file));assembly=file.read_bytes()
    finally:gmsh.finalize()
    node=dict(id='assembly',type='STEP',source_base64=base64.b64encode(assembly).decode(),source_sha256=hashlib.sha256(assembly).hexdigest())
    try:evaluate(dict(model=graph([node],'assembly'),quality=8))
    except ValueError as error:
        assert 'assemblies/shells unsupported' in str(error)
        (OUT/'assembly-rejection.json').write_text(json.dumps(dict(outcome='PASS',error=str(error)),indent=2))
    else:raise AssertionError('STEP assembly accepted')
print('CAD21_GEOMETRY_PASS')
