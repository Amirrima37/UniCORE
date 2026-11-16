import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Independent interpolation/order/face-load and curved Jacobian regressions."""
import sys,json,math,random,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'));OUT=output_dir('CAD/cad23')
sys.path.insert(0,str(ROOT/'.tools/engines/gmsh-4.15.2-Windows64-sdk/lib'))
from quadratic_tet import *
from mesh_config import defaults,validate
from gmsh_study import mesh_study
import gmsh
for version,order in [(2,0),(2,3),(2,float('nan')),(99,2),(1,2)]:
    config=defaults(.07);config.update(schema=version,order=order)
    try:validate(config)
    except ValueError:pass
    else:raise AssertionError('Unknown/mixed mesh-order schema accepted')
points=[[0,0,0],[1,0,0],[0,1,0],[0,0,1]]+[[.5,.0,0],[.5,.5,0],[0,.5,0],[0,0,.5],[.5,0,.5],[0,.5,.5]]
q=element_quality(points);assert abs(q['volume']-1/6)<1e-13 and abs(q['jacobian']-1)<1e-12
for i,l in enumerate([[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1],[.5,.5,0,0],[0,.5,.5,0],[.5,0,.5,0],[.5,0,0,.5],[0,.5,0,.5],[0,0,.5,.5]]):
    assert max(abs(x-int(i==j)) for j,x in enumerate(shape(l)))<1e-14
bad=copy.deepcopy(points);bad[4]=[.5,1,0]
try:element_quality(bad)
except ValueError:pass
else:raise AssertionError('Corner-positive but curved-inverted tetrahedron accepted')
regular_face=[points[i] for i in [0,1,2,4,5,6]];weights,area,first=face_integrals(regular_face)
assert abs(area-.5)<1e-13 and max(abs(x) for x in weights[:3])<1e-13 and max(abs(x-1/6) for x in weights[3:])<1e-13
model=dict(nodes=points,elements=[list(range(10))],quadratic_boundary=dict(faces={'loaded':[[0,2,1,6,5,4]],'fixed':[[0,1,3,4,8,7]]},groups={'loaded':[0,1,2,4,5,6],'fixed':[0,1,3,4,7,8]},load_face='loaded',support='fixed',force=[0,0,1000]))
for side,face in enumerate(FACES[2:],3):model['quadratic_boundary']['faces'][str(side)]=[face];model['quadratic_boundary']['groups'][str(side)]=face
loads,constraints,proof=boundary_loads(model);assert len(constraints)==18 and all(row[0] in [4,5,6] for row in loads)
assert max(abs(a-b) for a,b in zip(proof['resultant'],[0,0,1000]))<1e-10
assert max(abs(a-b) for a,b in zip(proof['moment'],[1000/3,-1000/3,0]))<1e-10
# Independent high-order integration of z=0.2*u*v on a curved TRI6 patch.
from numpy.polynomial.legendre import leggauss
curved=copy.deepcopy(regular_face);curved[4][2]=.05
cw,ca,cm=face_integrals(curved);ab,gw=leggauss(16);independent=[0.]*6;ia=0.;im=[0.]*3
for a,wa in zip(ab,gw):
    u=(a+1)/2
    for b,wb in zip(ab,gw):
        v=(1-u)*(b+1)/2;t=1-u-v;ds=wa*wb*(1-u)/4*math.sqrt(1+.04*(u*u+v*v))
        n=[t*(2*t-1),u*(2*u-1),v*(2*v-1),4*t*u,4*u*v,4*v*t];ia+=ds
        for i in range(6):independent[i]+=n[i]*ds
        for k,value in enumerate([u,v,.2*u*v]):im[k]+=value*ds
assert max(abs(a-b) for a,b in zip(cw,independent))<1e-8 and abs(ca-ia)<1e-8 and max(abs(a-b) for a,b in zip(cm,im))<1e-8
missing=copy.deepcopy(model);missing['quadratic_boundary']['groups']['fixed'].remove(7)
try:boundary_loads(missing)
except ValueError:pass
else:raise AssertionError('Missing midside constraint accepted')
gmsh.initialize([],readConfigFiles=False)
try:
    properties=gmsh.model.mesh.getElementProperties(11);coords=properties[4]
    for i,j in enumerate(GMSH_TO_CCX):assert max(abs(coords[3*j+k]-points[i][k]) for k in range(3))<1e-14
finally:gmsh.finalize()
receipts=[]
for kind in ['Box','Cylinder','Sphere','Pipe','fuse','intersect','hole','step-cut']:
    config=defaults(.07);config.update(schema=2,order=2,curvature_points=12)
    if kind in ['fuse','intersect','hole','step-cut','Sphere','Pipe']:
        data=json.loads((ROOT/('docs/architecture/evidence/cad21/'+kind.lower()+'.json')).read_text());data['parts'][0]['mesh_settings']=config
    else:data=dict(parts=[dict(id=kind,kind=kind,dimensions=[.1,.2,.1],inner_diameter=.05,position=[0,0,0],rotation=[0,0,0],scale=[1,1,1],mesh_settings=config)])
    mesh=mesh_study(ROOT,data,.07);assert all(len(c)==10 for c in mesh['elements'])
    assert all(len(face)==6 for faces in mesh['quadratic_surfaces'][data['parts'][0]['id']].values() for face in faces)
    assert mesh['quality']['minimum_jacobian']>0 and mesh['corner_nodes']+mesh['midside_nodes']==len(mesh['nodes'])
    receipts.append(dict(case=kind,outcome='PASS',nodes=len(mesh['nodes']),tet10=len(mesh['elements']),volume_error=mesh['quality']['relative_volume_difference'],jacobian_lower=mesh['quality']['minimum_jacobian']))
(OUT/'unit-details.json').write_text(json.dumps(dict(outcome='PASS',gmsh_to_ccx=GMSH_TO_CCX,regular_volume=q['volume'],curved_inversion_rejected=True,tri6_weights=weights,force_moment=proof,cases=receipts),indent=2))
print('CAD23_UNIT_PASS')
