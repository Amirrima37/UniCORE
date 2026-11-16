import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
import sys,json,copy,math
import os,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from cad_model import evaluate
from native_occt import run
from gmsh_study import mesh_study
from mesh_config import defaults
from owned_execution import execute
OUT=output_dir('CAD/cad24-completion');rows=[]
base=dict(id='base',type='Box',dimensions=[.1,.2,.1])
first=dict(id='first',type='Cylinder',dimensions=[.02,.3,.02],position=[-.02,0,0])
second=dict(first,id='second',position=[.02,0,0])
cases=[('nested-cuts',[base,first,dict(id='cut1',type='Cut',base='base',tool='first'),second,dict(id='final',type='Cut',base='cut1',tool='second')]),
 ('nearly-coincident',[base,dict(base,id='other',position=[.1-1e-10,0,0]),dict(id='final',type='Union',base='base',tool='other')]),
 ('tiny-feature',[base,dict(first,dimensions=[.00001,.3,.00001]),dict(id='final',type='Cut',base='base',tool='first')]),
 ('tangent-cylinders',[dict(id='a',type='Cylinder',dimensions=[.1,.2,.1]),dict(id='b',type='Cylinder',dimensions=[.1,.2,.1],position=[.1,0,0]),dict(id='final',type='Union',base='a',tool='b')])]
for name,nodes in cases:
    try:
        result=evaluate(dict(model=dict(schema=1,units='m',root='final',nodes=nodes),quality=8));p=result['part']
        row=dict(case=name,native=p['cad_validation'],history=p['cad_topology_metadata'],cross_kernel=p['cad_cross_kernel'],gmsh_import=True)
        if name=='tiny-feature':
            job=OUT/'matrix-mesh'/('tiny-'+str(time.time_ns()));job.mkdir(parents=True)
            body=dict(p,id=name);body['mesh_settings']=defaults(.04)
            source=job/'study.json';source.write_text(json.dumps(dict(parts=[body],mesh_divisions=3)))
            receipt=execute(job,[sys.executable,str(ROOT/'scripts/engines/gmsh_study.py'),str(source),str(job/'mesh.json'),'.04'],30,os.getpid(),{'mesh.json':192*1024*1024})
            row['mesh_process']=receipt;row['mesh_job']=str(job)
            if receipt['state']=='completed':
                mesh=json.loads((job/'mesh.json').read_text());assert mesh['quality']['minimum_jacobian']>0;row.update(outcome='PASS',mesh_elements=len(mesh['elements']))
            else:row.update(outcome='MESH_FAILURE',diagnostic=(job/'stderr.txt').read_text(errors='replace'))
        else:
            try:
                mesh=mesh_study(ROOT,dict(parts=[dict(p,id=name)],mesh_divisions=3),.04);assert mesh['quality']['minimum_jacobian']>0
                row.update(outcome='PASS',mesh_elements=len(mesh['elements']))
            except Exception as e:row.update(outcome='MESH_FAILURE',diagnostic=str(e))
    except ValueError as e:row=dict(case=name,outcome='REJECTED',diagnostic=str(e),scope='Only one valid manifold solid is accepted; no false claim of successful meshing')
    rows.append(row);(OUT/'geometry-extra-matrix.json').write_text(json.dumps(rows,indent=2))
_,curved=run(action='cylinder',dimensions=[.1,.2,.1])
try:
    r,_=run(curved,'transform',matrix=[2,0,0,0,0,3,0,0,0,0,4,0])
    assert r['validation']['status']=='VALID'
    rows.append(dict(case='curved-nonuniform',outcome='PASS',native=r))
except ValueError as e:rows.append(dict(case='curved-nonuniform',outcome='UNSUPPORTED',diagnostic=str(e),scope='Native affine invariant budget failed; no triangulated substitute'))
(OUT/'geometry-extra-matrix.json').write_text(json.dumps(rows,indent=2))
print('CAD24_EXTRA_MATRIX_COMPLETE')
