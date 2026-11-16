import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import output_dir
import sys,json,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from cad_model import evaluate
def graph(nodes):return dict(schema=1,units='m',root='cut',nodes=nodes)
a=dict(id='base',type='Box',dimensions=[.1,.2,.1])
b=dict(id='tool',type='Cylinder',dimensions=[.04,.3,.04])
op=dict(id='cut',type='Cut',base='base',tool='tool')
first=evaluate(dict(model=graph([a,b,op]),quality=8))['part']
reordered=evaluate(dict(model=graph([op,b,a]),quality=8))['part']
assert set(first['cad_faces'])==set(reordered['cad_faces'])
edited=evaluate(dict(model=graph([a,dict(b,dimensions=[.05,.3,.05]),op]),quality=8))['part']
preserved=set(first['cad_faces'])&set(edited['cad_faces']);deleted=set(first['cad_faces'])-set(edited['cad_faces'])
assert preserved and deleted
assert preserved<=set(edited['cad_safe_continuations'])
slot=dict(id='tool',type='Box',dimensions=[.02,.1,.2],position=[0,.075,0])
split=evaluate(dict(model=graph([a,slot,op]),quality=8))['part']
assert any(f['state']=='split' for f in split['cad_topology_metadata']['faces'])
one=evaluate(dict(model=dict(schema=1,units='m',root='base',nodes=[a]),quality=8))['part']
unrelated=evaluate(dict(model=dict(schema=1,units='m',root='other',nodes=[dict(a,id='other')]),quality=8))['part']
assert set(one['cad_faces']).isdisjoint(unrelated['cad_faces'])
# A real BREP fixture reverses shell face order while preserving the solid.
from native_graph import verified_input_faces, signature
from native_occt import run, SDK
from owned_execution import execute
import os
fixtures=ROOT/'docs/architecture/evidence/cad24-completion/fixtures'
os.environ['PATH']=str(SDK/'ucrt64/bin')+';D:/msys64/ucrt64/bin;'+os.environ.get('PATH','')
assert execute(fixtures,[str(SDK/'make_occt_fixtures.exe')],30,os.getpid())['exit_code']==0
original,_=run((fixtures/'ordered.brep').read_bytes())
reversed_input=(fixtures/'reordered.brep').read_bytes()
reversed_receipt,_=run(reversed_input)
assert original['validation']['status']==reversed_receipt['validation']['status']=='VALID'
prior={f['slot']:dict(identity='physical:'+repr(f['center']),descriptor=f) for f in original['validation']['faces']}
actual=reversed_receipt['validation']['faces']
assert [f['center'] for f in actual]!=[f['center'] for f in original['validation']['faces']]
remapped=verified_input_faces(prior,actual)
assert all(remapped[f['slot']]['identity']=='physical:'+repr(f['center']) for f in actual)
_,tool=run(action='box',dimensions=[.02,.3,.02])
operation,_=run(reversed_input,'cut',tool=tool)
assert operation['validation']['status']=='VALID'
verified_input_faces(prior,operation['before']['faces'])
_,outer=run(action='box',dimensions=[.1,.2,.1])
_,inner=run(action='box',dimensions=[.02,.03,.02])
cavity,_=run(outer,'cut',tool=inner)
assert cavity['validation']['status']=='VALID'
assert all(not h['unchanged'] for h in cavity['face_history'] if h['operand']==1), 'Reversed cavity tool faces must not be unchanged continuations'
assert signature([1,2.0])==signature([1.0,2])
# A changed upstream recipe must also version a later modified face identity.
chain=[a,b,dict(op,id='first'),dict(id='second-tool',type='Cylinder',dimensions=[.015,.3,.015],position=[.03,0,0]),dict(op,base='first',tool='second-tool')]
chain_first=evaluate(dict(model=graph(chain),quality=8))['part']
chain_edit=copy.deepcopy(chain);chain_edit[1]['dimensions']=[.05,.3,.05]
chain_second=evaluate(dict(model=graph(chain_edit),quality=8))['part']
old_modified={f['identity'] for f in chain_first['cad_topology_metadata']['faces'] if f['state']!='unchanged'}
new_modified={f['identity'] for f in chain_second['cad_topology_metadata']['faces'] if f['state']!='unchanged'}
assert old_modified.isdisjoint(new_modified)
receipt=dict(serialized_native_face_reordering_verified=True,transitive_edit_versioning=True,numeric_serialization_normalized=True,outcome='PASS',reordering=True,unique_continuations=sorted(preserved),invalidated=sorted(deleted),split_faces=split['cad_topology_metadata']['faces'],similar_unrelated_faces_disjoint=True)
(output_dir('CAD/cad24-completion')/'persistent-history.json').write_text(json.dumps(receipt,indent=2))
print('CAD24_HISTORY_PASS')
