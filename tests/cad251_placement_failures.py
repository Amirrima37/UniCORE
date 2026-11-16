"""Failure propagation at the production placement boundary, plus real timeout."""
import os,sys,json,base64,copy
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
OUT=Path(os.environ['UNICORE_PLACEMENT_OUT'])
os.environ['UNICORE_CAD_JOB_TEMP']=str(OUT/'negative-native')
import instance_placement as placement
from gmsh_study import cad_asset
from native_occt import run
p=json.loads((OUT/'source-part.json').read_text());raw=base64.b64decode(p['cad_base64'])
r,_=run(raw);before=r['validation'];rows=[]
def reject(name,call):
    try:call()
    except (ValueError,KeyError,RuntimeError) as error:rows.append(dict(case=name,passed=True,error=str(error)))
    else:raise AssertionError(name+' silently accepted')
reject('missing-source',lambda:cad_asset(dict(p,cad_base64='')))
reject('invalid-transform',lambda:placement.place(raw,dict(p,rotation=[float('nan'),0,0]),before))
reject('unsupported-scale',lambda:placement.place(raw,dict(p,scale=[2,1,1]),before))
with patch.object(placement,'run',side_effect=ValueError('worker failed')):
    reject('native-worker-failure',lambda:placement.place(raw,p,before))
with patch.object(placement,'run',return_value=({'validation':dict(before,status='INVALID')},raw)):
    reject('invalid-transformed-geometry',lambda:placement.place(raw,p,before))
reject('missing-ancestry',lambda:placement.place(raw,dict(p,cad_face_centers={}),before))
with patch.object(placement,'run',return_value=({'validation':dict(before,centroid=[1,0,0])},raw)):
    reject('double-transform-invariant',lambda:placement.place(raw,p,before))
os.environ['UNICORE_OCCT_TIMEOUT_S']='0'
reject('real-native-timeout',lambda:run(raw,'transform',matrix=placement.matrix(p)))
os.environ.pop('UNICORE_OCCT_TIMEOUT_S')
# A real import failure is injected at the public Gmsh import boundary.
sys.path.insert(0,str(ROOT/".tools/engines/gmsh-4.15.2-Windows64-sdk/lib"))
import gmsh
from gmsh_study import mesh_study
with patch.object(gmsh.model.occ,'importShapes',side_effect=RuntimeError('Gmsh import failed')):
    reject('gmsh-import-failure',lambda:mesh_study(ROOT,dict(parts=[p]),.05))
(OUT/'negative.json').write_text(json.dumps(rows,indent=2));print('NEGATIVE_PASS',len(rows))
