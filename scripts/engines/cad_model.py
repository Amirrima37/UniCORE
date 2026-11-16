"""Exact isolated OCCT feature graph, verified BREP handoff to pinned Gmsh.

No mesh operations construct geometry. BREP is an evaluated cache; graph inputs
are authoritative. Native operation history supplies identity; descriptors
verify the independent Gmsh import without relying on enumeration order.
"""
import base64, hashlib, json, math, sys, tempfile, copy, os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tools/engines/gmsh-4.15.2-Windows64-sdk/lib'))
import gmsh
from gmsh_study import source_length_unit
VERSION=1
MAX_BYTES=64*1024*1024
TOL=1e-8
KERNEL_SHA256='6cac3eefb477265d9fa60bbd869dbbbf7c7ca4cb308c0f8f2b43e91d43de3c1c'
def digest(raw):return hashlib.sha256(raw).hexdigest()
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),allow_nan=False)
def validate(model):
    if model.get('schema')!=VERSION or model.get('units')!='m':raise ValueError('Unsupported CAD schema/units; expected version 1, metres')
    nodes=model.get('nodes')
    if not isinstance(nodes,list) or not 1<=len(nodes)<=64:raise ValueError('CAD graph requires 1..64 features')
    ids=[n.get('id') for n in nodes]
    if any(not isinstance(i,str) or not i or len(i)>100 for i in ids) or len(set(ids))!=len(ids):raise ValueError('Invalid/duplicate feature IDs')
    by_id=dict(zip(ids,nodes));seen=set();visiting=set()
    def visit(i):
        if i not in by_id:raise ValueError('Missing CAD dependency: '+str(i))
        if i in visiting:raise ValueError('Cyclic CAD graph')
        if i in seen:return
        visiting.add(i);n=by_id[i]
        if n.get('type') in ['Union','Cut','Intersect']:
            if n.get('base')==n.get('tool'):raise ValueError('Boolean operands must be distinct features')
            visit(n.get('base'));visit(n.get('tool'))
        elif n.get('type') not in ['Box','Cylinder','Sphere','Pipe','STEP']:raise ValueError('Unsupported CAD feature')
        for key,default in [('position',[0,0,0]),('rotation',[0,0,0]),('scale',[1,1,1])]:
            v=n.get(key,default)
            if not isinstance(v,list) or len(v)!=3 or any(not isinstance(x,(int,float)) or not math.isfinite(x) or abs(x)>1e6 or (key=='scale' and abs(x)<=1e-8) for x in v):raise ValueError('Invalid CAD transform: '+key)
        visiting.remove(i);seen.add(i)
    for i in ids:visit(i)
    if model.get('root') not in by_id:raise ValueError('Missing CAD root')
    return by_id
def descriptor(tag):
    edges=[]
    for dim,edge in gmsh.model.getBoundary([(2,tag)],combined=False,oriented=False):
        lo,hi=gmsh.model.getParametrizationBounds(1,edge)
        points=[list(gmsh.model.getValue(1,edge,[float(lo[0]+(hi[0]-lo[0])*s)])) for s in [0,.25,.5,.75,1]]
        reverse=list(reversed(points));points=min([points,reverse],key=lambda p:tuple(round(v,10) for xyz in p for v in xyz))
        edges.append(dict(type=gmsh.model.getType(1,edge),length=gmsh.model.occ.getMass(1,edge),bounds=list(gmsh.model.occ.getBoundingBox(1,edge)),points=points))
    edges.sort(key=lambda e:(e['type'],tuple(round(x,10) for x in e['bounds']),tuple(round(v,10) for p in e['points'] for v in p)))
    return dict(type=gmsh.model.getType(2,tag),area=gmsh.model.occ.getMass(2,tag),center=list(gmsh.model.occ.getCenterOfMass(2,tag)),bounds=list(gmsh.model.occ.getBoundingBox(2,tag)),inertia=list(gmsh.model.occ.getMatrixOfInertia(2,tag)),edges=edges)
def same_face(a,b):
    def same(x,y):
        if type(x) is dict and type(y) is dict:return set(x)==set(y) and all(same(x[k],y[k]) for k in x)
        if type(x) is list and type(y) is list:return len(x)==len(y) and all(same(u,v) for u,v in zip(x,y))
        if isinstance(x,(int,float)) and isinstance(y,(int,float)):return abs(x-y)<=max(1e-11,abs(x)*1e-9,abs(y)*1e-9)
        return x==y
    if a.get('type')!=b.get('type'):return False
    for key in ['area','center','bounds','inertia']:
        x=a[key] if isinstance(a[key],list) else [a[key]];y=b[key] if isinstance(b[key],list) else [b[key]]
        if len(x)!=len(y) or any(abs(u-v)>max(1e-11,abs(u)*1e-9,abs(v)*1e-9) for u,v in zip(x,y)):return False
    return same(a.get('edges'),b.get('edges'))
def map_faces(previous,current,scope):
    """One-to-one full descriptor equality only; split/merge => unassigned."""
    candidates={tag:[key for key,old in previous.items() if same_face(old,desc)] for tag,desc in current.items()}
    counts={key:sum(key in matches for matches in candidates.values()) for key in previous}
    mapping={};used=set();ambiguous=[]
    for tag in sorted(current):
        matches=candidates[tag]
        if len(matches)==1 and counts[matches[0]]==1:key=matches[0]
        else:
            if matches:ambiguous.extend(matches)
            signature=canonical(current[tag]);key='F_'+digest((scope+signature).encode())[:24]
            if key in used:raise ValueError('Indistinguishable coincident faces require topology review')
        mapping[tag]=key;used.add(key)
    return mapping,dict(preserved=sorted(set(previous)&used),invalidated=sorted(set(previous)-used),ambiguous=sorted(set(ambiguous)),strategy='unique-complete-descriptor-v1; no face-index fallback')
def evaluated_faces(part):
    current={tag:descriptor(tag) for dim,tag in gmsh.model.getBoundary(gmsh.model.getEntities(3),oriented=False) if dim==2}
    expected=part.get('cad_face_descriptors',{})
    mapping,history=map_faces(expected,current,part.get('cad_geometry_revision',''))
    if expected and (history['invalidated'] or set(mapping.values())!=set(expected)):raise ValueError('BRep face identity mismatch: review CAD topology before meshing')
    return mapping
def verify_kernel():
    library=ROOT/'.tools/engines/gmsh-4.15.2-Windows64-sdk/lib/gmsh-4.15.dll'
    with library.open('rb') as f:actual=hashlib.file_digest(f,'sha256').hexdigest()
    if actual!=KERNEL_SHA256 or gmsh.__version__!='4.15.2':raise ValueError('CAD kernel pin mismatch; restore the locked Gmsh 4.15.2/OCCT pack')
def evaluate(request):
    verify_kernel()
    model=request['model'];by_id=validate(model);memo={};history=[]
    quality=int(request.get('quality',20))
    if not 8<=quality<=60:raise ValueError('Preview quality must be 8..60')
    with tempfile.TemporaryDirectory(prefix='unicore-cad21-',dir=os.environ.get('UNICORE_CAD_JOB_TEMP')) as tmp:
        tmp=Path(tmp);gmsh.initialize([],readConfigFiles=False)
        try:
            gmsh.option.setNumber('General.NumThreads',1);gmsh.option.setNumber('General.Terminal',0)
            gmsh.option.setNumber('Geometry.Tolerance',TOL);gmsh.option.setNumber('Geometry.ToleranceBoolean',TOL)
            gmsh.option.setNumber('Geometry.OCCBooleanPreserveNumbering',0)
            gmsh.option.setNumber('Geometry.OCCBooleanSimplify',1)
            gmsh.option.setString('Geometry.OCCTargetUnit','M')
            from native_graph import evaluate as native_evaluate
            native_raw,native_faces,native_operations=native_evaluate(model)
            native_path=tmp/'native.brep';native_path.write_bytes(native_raw)
            imported=gmsh.model.occ.importShapes(str(native_path),highestDimOnly=True)
            if len(imported)!=1 or imported[0][0]!=3:raise ValueError('Native/Gmsh solid count mismatch')
            solid=imported[0][1];gmsh.model.occ.synchronize()
            discarded=[(d,t) for d,t in gmsh.model.getEntities(3) if t!=solid]
            if discarded:gmsh.model.occ.remove(discarded,recursive=True)
            gmsh.model.occ.synchronize()
            if len(gmsh.model.getEntities(3))!=1:raise ValueError('Expected one evaluated solid')
            edge_uses={}
            for dim,face in gmsh.model.getBoundary([(3,solid)],oriented=False):
                for edge_dim,edge in gmsh.model.getBoundary([(2,face)],combined=False,oriented=True):
                    edge=abs(edge)
                    if gmsh.model.occ.getMass(1,edge)>TOL:edge_uses[edge]=edge_uses.get(edge,0)+1
            if any(count!=2 for count in edge_uses.values()):raise ValueError('Nonclosed/nonmanifold CAD boundary edges')
            volume=gmsh.model.occ.getMass(3,solid);bounds=list(gmsh.model.occ.getBoundingBox(3,solid))
            current={tag:descriptor(tag) for dim,tag in gmsh.model.getBoundary([(3,solid)],oriented=False)}
            revision=digest(canonical(model).encode())
            mapping,tracking=map_faces(request.get('previous_faces',{}),current,model['root'])
            mapping={};used=set()
            for tag,desc in current.items():
                matches=[f for f in native_faces.values() if abs(f['descriptor']['area']-desc['area'])<=max(1e-11,desc['area']*1e-9) and all(abs(a-b)<=max(1e-11,abs(b)*1e-9) for a,b in zip(f['descriptor']['center'],desc['center'])) and all(abs(a-b)<=max(1e-11,abs(b)*1e-9) for a,b in zip(f['descriptor']['inertia'],desc['inertia'])) and all(abs(a-b)<=max(2e-7,2*native_operations[-1]['receipt']['validation']['maximum_tolerance_m'],abs(b)*1e-9) for a,b in zip(f['descriptor']['bounds'],desc['bounds']))]
                if len(matches)!=1 or matches[0]['identity'] in used:raise ValueError('Ambiguous OCCT/Gmsh face mapping; no index or nearest-face fallback')
                mapping[tag]=matches[0]['identity'];used.add(mapping[tag])
            if len(mapping)!=len(native_faces):raise ValueError('Incomplete native face coverage')
            native_validation=native_operations[-1]['receipt']['validation']
            if abs(volume-native_validation['volume'])>max(1e-15,volume*1e-9):raise ValueError('Native/Gmsh volume mismatch')
            area=sum(d['area'] for d in current.values())
            if abs(area-native_validation['area'])>max(1e-13,area*1e-9):raise ValueError('Native/Gmsh surface area mismatch')
            centroid=list(gmsh.model.occ.getCenterOfMass(3,solid))
            center_delta=max(abs(a-b) for a,b in zip(centroid,native_validation['centroid']))
            if any(abs(a-b)>max(1e-11,abs(b)*1e-9) for a,b in zip(centroid,native_validation['centroid'])):raise ValueError('Native/Gmsh centroid mismatch')
            bounds_delta=max(abs(a-b) for a,b in zip(bounds,native_validation['bounds']))
            bounds_budget=max(2e-7,2*native_validation['maximum_tolerance_m'],max(abs(v) for v in bounds)*1e-9)
            if bounds_delta>bounds_budget:raise ValueError('Native/Gmsh bounding box mismatch')
            tracking=dict(preserved=sorted(set(request.get('previous_faces',{}))&used),invalidated=sorted(set(request.get('previous_faces',{}))-used),strategy='native-feature-history-v1; checked descriptor mapping',native_history=True)
            # Native BRep serialization, independently reimported by the existing bridge.
            path=tmp/'result.brep';gmsh.write(str(path));raw=path.read_bytes()
            if len(raw)>MAX_BYTES:raise ValueError('BRep exceeds 64 MiB output bound')
            gmsh.write(str(tmp/'result.step'))
            span=max(bounds[i+3]-bounds[i] for i in range(3));h=max(span/quality,1e-6)
            gmsh.option.setNumber('Mesh.MeshSizeMin',h);gmsh.option.setNumber('Mesh.MeshSizeMax',h)
            gmsh.model.mesh.generate(2)
            tags,coords,_=gmsh.model.mesh.getNodes();index={int(t):i for i,t in enumerate(tags)}
            if len(tags)>300000:raise ValueError('Display tessellation exceeds 300000 vertices')
            nodes=[list(map(float,coords[3*i:3*i+3])) for i in range(len(tags))];surfaces={}
            for tag,key in mapping.items():
                _,conn=gmsh.model.mesh.getElementsByType(2,tag);surfaces[key]=[[index[int(t)] for t in conn[i:i+3]] for i in range(0,len(conn),3)]
            part=dict(kind='CAD',cad_model=model,cad_format='brep',cad_base64=base64.b64encode(raw).decode(),cad_sha256=digest(raw),cad_geometry_revision=revision,cad_faces=sorted(mapping.values()),cad_face_descriptors={key:current[tag] for tag,key in mapping.items()},cad_face_areas={key:current[tag]['area'] for tag,key in mapping.items()},cad_face_centers={key:current[tag]['center'] for tag,key in mapping.items()},cad_volume=volume,cad_bounds=bounds,cad_source_units='m',cad_source_to_m=1.0,cad_kernel={'gmsh':'4.15.2','occt':'7.8.1','tolerance_m':TOL},dimensions=[bounds[i+3]-bounds[i] for i in range(3)],position=[0.,0.,0.],rotation=[0.,0.,0.],scale=[1.,1.,1.])
            part['cad_evaluated_model']=copy.deepcopy(model)
            # Gmsh sanity checks are not independent native BRep qualification.
            part['cad_validation']={'schema':1,'status':'inconclusive','native_available':False,'checks':{'single_solid':True,'positive_volume':True,'boundary_edge_incidence':True},'diagnostic':'Native BRepCheck_Analyzer and per-face OCCT history unavailable in the pinned public Gmsh API. Meshing success is not proof of BRep validity.'}
            part['cad_topology_metadata']={'schema':1,'strategy':'descriptor-verification-only','native_history':False,'geometry_revision':revision,'feature_ids':sorted(by_id),'operation_history':history}
            part['cad_validation']=dict(schema=1,native_available=True,**native_validation)
            part['cad_topology_metadata']=dict(schema=2,strategy='native-feature-history-v1',native_history=True,geometry_revision=revision,operations=native_operations,faces=list(native_faces.values()))
            part['cad_safe_continuations']=[f['identity'] for f in native_faces.values() if f['state'] in ['unchanged','original']]
            part['cad_cross_kernel']=dict(solid_count=1,face_count=len(mapping),volume_difference_m3=abs(volume-native_validation['volume']),area_difference_m2=abs(area-native_validation['area']),centroid_difference_m=center_delta,bounds_difference_m=bounds_delta,bounds_budget_m=bounds_budget,complete_boundary_coverage=True)
            return dict(ok=True,part=part,preview=dict(nodes=nodes,surface_regions={request.get('part_id','cad'):surfaces},face_areas=part['cad_face_areas'],face_centers=part['cad_face_centers'],cad_volume=volume,bounds=bounds,units='m',source_sha256=part['cad_sha256']),topology=tracking,operation_history=native_operations,validation={'single_solid':True,'positive_volume':True,'direct_BRepCheck_Analyzer':True})
        finally:gmsh.finalize()
if __name__=='__main__':
    source=Path(sys.argv[1]);output=Path(sys.argv[2])
    try:
        if source.stat().st_size>96*1024*1024:raise ValueError('CAD request exceeds 96 MiB')
        request=json.loads(source.read_text(encoding='utf-8-sig'))
        if request.get('action')=='validate_model':
            from native_graph import evaluate as native_evaluate
            validate(request['model'])
            _,_,operations=native_evaluate(request['model'])
            result=dict(ok=True,validation=operations[-1]['receipt']['validation'])
        elif request.get('action')=='validate':
            from native_occt import run as native_run
            part=request['part'];raw=base64.b64decode(part['cad_base64'],validate=True)
            if digest(raw)!=part['cad_sha256']:raise ValueError('CAD cache hash mismatch')
            if part.get('cad_format','step')=='step':source_length_unit(raw)
            validation,_=native_run(raw,'validate' if part.get('cad_format','step')=='brep' else 'step')
            result=dict(ok=True,validation=validation['validation'])
        elif request.get('action')=='review_faces':
            verify_kernel()
            from gmsh_study import preview_step
            part=copy.deepcopy(request['part'])
            for key in ['boundary_schema','boundary_refs','cad_definition_faces','cad_face_descriptors']:part.pop(key,None)
            part.update(cad_faces=[],cad_face_areas={},cad_face_centers={},position=[0,0,0],rotation=[0,0,0])
            result=dict(ok=True,metadata=preview_step(ROOT,part))
        elif request.get('action')=='preview_assembly':
            verify_kernel()
            from gmsh_study import preview_step
            nodes=[];regions={};metadata={}
            for part in request['parts']:
                if part['kind']!='CAD':continue
                part=copy.deepcopy(part)
                if not part.get('cad_faces') or not part.get('cad_definition_faces'):
                    source=copy.deepcopy(part);source.pop('boundary_schema',None);source.pop('boundary_refs',None)
                    # Resolve source descriptors at identity placement through the same worker.
                    source['position']=[0,0,0];source['rotation']=[0,0,0]
                    original=preview_step(ROOT,source)
                    part['cad_faces']=list(original['face_areas']);part['cad_face_areas']=original['face_areas'];part['cad_face_centers']=original['face_centers'];part['cad_definition_faces']=original['definition_faces']
                    metadata[part['id']]=original
                preview=preview_step(ROOT,part);offset=len(nodes);nodes.extend(preview['nodes'])
                regions[part['id']]={key:[[n+offset for n in tri] for tri in triangles] for key,triangles in preview['surface_regions'][part['id']].items()}
            result=dict(ok=True,preview=dict(nodes=nodes,surface_regions=regions,source_metadata=metadata))
        elif request.get('action')=='preview':
            verify_kernel()
            from gmsh_study import preview_step
            result=dict(ok=True,preview=preview_step(ROOT,request['part']))
        else:result=evaluate(request)
        text=canonical(result)
        if len(text.encode())>96*1024*1024:raise ValueError('CAD response exceeds 96 MiB')
    except Exception as e:text=canonical(dict(ok=False,error=str(e)))
    output.write_text(text,encoding='utf-8')
