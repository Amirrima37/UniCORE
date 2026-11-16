import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Real configuration, quality, local density, optimization and Gmsh validation."""
import sys,json,math,copy,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad22');sys.path.insert(0,str(ROOT/'scripts/engines'))
from mesh_config import defaults,validate
from mesh_quality import metrics
from gmsh_study import mesh_study
rows=[]
def record(name,**data):
    row=dict(test=name,outcome='PASS',**data);rows.append(row);(OUT/'validation-details.json').write_text(json.dumps(rows,indent=2));print(json.dumps(row),flush=True)
for key,value in [('target_size',float('nan')),('min_size',0),('max_size',-.1),('algorithm','unknown'),('schema',2),('schema',True),('max_nodes',1.5),('timeout_s',float('inf')),('memory_mb',99999),('curvature_points',1.5)]:
    config=defaults();config[key]=value
    try:validate(config)
    except ValueError as e:record('reject-'+key,error=str(e))
    else:raise AssertionError('Invalid settings accepted: '+key)
config=defaults();config['min_size']=.1
try:validate(config)
except ValueError as e:record('reject-inconsistent-bounds',error=str(e))
else:raise AssertionError('Bad bounds accepted')
points=[[0,0,0],[1,0,0],[.5,math.sqrt(3)/2,0],[.5,math.sqrt(3)/6,math.sqrt(2/3)]]
q=metrics(points,[[0,1,2,3]],1/6*math.sqrt(.5));assert abs(q['minimum_mean_ratio']-1)<1e-12 and abs(q['maximum_edge_ratio']-1)<1e-12
assert metrics(points,[[0,2,1,3]],1)['inverted_elements']==1
assert metrics([[0,0,0],[1,0,0],[0,1,0],[1,1,0]],[[0,1,2,3]],1)['degenerate_elements']==1
record('independent-regular-inverted-degenerate-tetrahedra',mean_ratio=q['minimum_mean_ratio'])
data=json.loads((ROOT/'docs/architecture/evidence/cad21/step-cut.json').read_text());p=data['parts'][0]
hole=next(key for key,d in p['cad_face_descriptors'].items() if d['type']=='Cylinder');density=[]
for local in [False,True]:
    config=defaults(.05);config.update(min_size=.002,boundary_extension=False,curvature_points=8)
    if local:config['local']=[dict(id='hole',face=hole,enabled=True,needs_review=False,mode='distance',size=.008,dist_min=.003,dist_max=.025)]
    p['mesh_settings']=config;start=time.monotonic();mesh=mesh_study(ROOT,data,.05)
    tris=mesh['surface_regions'][p['id']][hole];lengths=[math.dist(mesh['nodes'][tri[i]],mesh['nodes'][tri[(i+1)%3]]) for tri in tris for i in range(3)]
    density.append(dict(local=local,surface_nodes=len(mesh['groups'][p['id']][hole]),surface_triangles=len(tris),mean_surface_edge_m=sum(lengths)/len(lengths),nodes=len(mesh['nodes']),tet4=len(mesh['elements']),volume_error=mesh['quality']['relative_volume_difference'],minimum_mean_ratio=mesh['quality']['minimum_mean_ratio'],seconds=time.monotonic()-start))
    (OUT/(('local' if local else 'global')+'.mesh.json')).write_text(json.dumps(mesh))
assert density[1]['surface_nodes']>density[0]['surface_nodes']*2 and density[1]['mean_surface_edge_m']<density[0]['mean_surface_edge_m']*.7,density
record('genuine-face-local-density',measurements=density)
data=dict(parts=[dict(id='box',kind='Box',dimensions=[.1,.2,.1],position=[0,0,0],rotation=[0,0,0],scale=[1,1,1])])
for algorithm,optimization in [('delaunay','none'),('delaunay','netgen'),('hxt','gmsh')]:
    config=defaults(.04);config.update(algorithm=algorithm,optimization=optimization,min_quality=0)
    data['parts'][0]['mesh_settings']=config;mesh=mesh_study(ROOT,data,.04)
    assert mesh['quality']['minimum_jacobian']>0 and mesh['quality']['exterior_triangles']>0
    record('algorithm-'+algorithm+'-'+optimization,nodes=len(mesh['nodes']),tet4=len(mesh['elements']),before=mesh['optimization']['before']['minimum_mean_ratio'],after=mesh['quality']['minimum_mean_ratio'])
for name,changes in [('cost',dict(target_size=1e-6,min_size=1e-6,max_size=1e-6)),('quality',dict(min_quality=.999999)),('counts',dict(max_nodes=4,max_elements=1))]:
    config=defaults(.04);config.update(changes);data['parts'][0]['mesh_settings']=config
    try:mesh_study(ROOT,data,.04)
    except ValueError as e:record('reject-'+name,error=str(e))
    else:raise AssertionError('Unsafe mesh accepted '+name)
print('CAD22_VALIDATION_PASS')
