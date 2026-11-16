"""Versioned SI sizing policy shared by CLI mesh workers and acceptance tools."""
import math,copy,struct
def encode_numbers(value):
    if type(value) in [int,float]:return {'binary64':struct.pack('<d',float(value)).hex()}
    if isinstance(value,list):return [encode_numbers(x) for x in value]
    if isinstance(value,dict):return {k:encode_numbers(v) for k,v in value.items()}
    return value
def decode_numbers(value):
    if isinstance(value,list):return [decode_numbers(x) for x in value]
    if isinstance(value,dict):
        if set(value)=={'binary64'}:return struct.unpack('<d',bytes.fromhex(value['binary64']))[0]
        return {k:decode_numbers(v) for k,v in value.items()}
    return value
ALGORITHMS={'delaunay':1,'hxt':10}
def defaults(size=.05):
    return dict(schema=1,target_size=size,min_size=size/10,max_size=size,curvature_points=0,boundary_extension=True,algorithm='delaunay',optimization='gmsh',optimize_iterations=1,max_nodes=100000,max_elements=500000,timeout_s=120.,memory_mb=1536,min_quality=.03,max_edge_ratio=100.,local=[])
def validate(config,faces=None):
    if not isinstance(config,dict):raise ValueError('Invalid mesh settings')
    version=config.get('schema')
    if type(version) not in [int,float] or version not in [1,2]:raise ValueError('Unsupported mesh settings schema')
    if set(config)!=(set(defaults())|({'order'} if version==2 else set())):raise ValueError('Unknown/missing mesh settings fields')
    if version==2 and (type(config['order']) not in [int,float] or config['order'] not in [1,2]):raise ValueError('Only linear TET4 or quadratic TET10 order supported')
    for key,lo,hi,integer in [('target_size',1e-6,1000,False),('min_size',1e-6,1000,False),('max_size',1e-6,1000,False),('curvature_points',0,100,True),('optimize_iterations',1,5,True),('max_nodes',4,200000,True),('max_elements',1,1000000,True),('timeout_s',.1,180,False),('memory_mb',768,4096,True),('min_quality',0,1,False),('max_edge_ratio',1,10000,False)]:
        v=config[key]
        if type(v) not in [int,float] or not math.isfinite(v) or not lo<=v<=hi or (integer and int(v)!=v):raise ValueError('Invalid mesh setting '+key)
    if not config['min_size']<=config['target_size']<=config['max_size']:raise ValueError('Mesh sizes require min <= target <= max')
    if type(config['boundary_extension']) is not bool or not isinstance(config['algorithm'],str) or config['algorithm'] not in ALGORITHMS or config['optimization'] not in ['none','gmsh','netgen']:raise ValueError('Unsupported mesh algorithm/optimization/boundary setting')
    if not isinstance(config['local'],list) or len(config['local'])>64:raise ValueError('At most 64 local mesh rules are supported')
    ids=set()
    for rule in config['local']:
        if not isinstance(rule,dict) or set(rule)!=set(['id','face','enabled','needs_review','mode','size','dist_min','dist_max']):raise ValueError('Malformed local sizing rule')
        if not isinstance(rule['id'],str) or not rule['id'] or rule['id'] in ids or not isinstance(rule['face'],str) or not rule['face']:raise ValueError('Invalid/duplicate local refinement identity')
        ids.add(rule['id'])
        if type(rule['enabled']) is not bool or type(rule['needs_review']) is not bool or rule['mode'] not in ['face','distance']:raise ValueError('Unsupported local sizing state/mode')
        for key in ['size','dist_min','dist_max']:
            if type(rule[key]) not in [int,float] or not math.isfinite(rule[key]):raise ValueError('Nonfinite local sizing distance')
        if not config['min_size']<=rule['size']<=config['max_size'] or not 0<=rule['dist_min']<rule['dist_max']<=1000:raise ValueError('Local sizes must lie inside global bounds and require 0 <= near < far')
        if rule['enabled'] and (rule['needs_review'] or (faces is not None and rule['face'] not in faces)):raise ValueError('Local refinement face requires review: '+rule['face'])
    return copy.deepcopy(config)
def apply(gmsh,config,regions,volume,span):
    validate(config,regions)
    if volume/config['target_size']**3*6>config['max_elements']*4 or span/config['min_size']>20000:raise ValueError('Mesh request exceeds preflight density budget; increase size or limits within supported bounds')
    gmsh.option.setNumber('Mesh.Algorithm3D',ALGORITHMS[config['algorithm']])
    gmsh.option.setNumber('Mesh.MeshSizeMin',config['min_size']);gmsh.option.setNumber('Mesh.MeshSizeMax',config['max_size'])
    gmsh.option.setNumber('Mesh.MeshSizeFromCurvature',config['curvature_points']);gmsh.option.setNumber('Mesh.MeshSizeFromPoints',0)
    gmsh.option.setNumber('Mesh.MeshSizeExtendFromBoundary',int(config['boundary_extension']))
    gmsh.option.setNumber('Mesh.Optimize',0);gmsh.option.setNumber('Mesh.OptimizeNetgen',0)
    fields=[];base=gmsh.model.mesh.field.add('MathEval');gmsh.model.mesh.field.setString(base,'F',str(config['target_size']));fields.append(base)
    for rule in config['local']:
        if not rule['enabled']:continue
        tags=regions[rule['face']];tags=tags if isinstance(tags,list) else [tags];area=sum(gmsh.model.occ.getMass(2,tag) for tag in tags)
        near=0 if rule['mode']=='face' else rule['dist_min'];far=rule['size'] if rule['mode']=='face' else rule['dist_max']
        if area*(near+rule['size'])*2/rule['size']**3>config['max_elements']*4:raise ValueError('Local face refinement exceeds estimated density budget; coarsen the local size')
        distance=gmsh.model.mesh.field.add('Distance');gmsh.model.mesh.field.setNumbers(distance,'SurfacesList',tags);gmsh.model.mesh.field.setNumber(distance,'Sampling',100)
        threshold=gmsh.model.mesh.field.add('Threshold')
        for key,value in dict(InField=distance,SizeMin=rule['size'],SizeMax=config['target_size'],DistMin=near,DistMax=far).items():gmsh.model.mesh.field.setNumber(threshold,key,value)
        fields.append(threshold)
    combine=gmsh.model.mesh.field.add('Min');gmsh.model.mesh.field.setNumbers(combine,'FieldsList',fields);gmsh.model.mesh.field.setAsBackgroundMesh(combine)
