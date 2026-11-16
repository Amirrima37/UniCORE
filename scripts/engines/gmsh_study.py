"""Optional native Windows Gmsh pack bridge. Output retains original upstream tags."""
import json, sys, math, hashlib, base64, tempfile, re, os, time
from collections import Counter
from pathlib import Path

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def source_cad_asset(part):
    if part.get('cad_topology_metadata',{}).get('schema',1) not in [1,2]:raise ValueError('Unsupported CAD topology metadata version')
    raw=base64.b64decode(part['cad_base64'],validate=True)
    if not raw or len(raw)>64*1024*1024 or hashlib.sha256(raw).hexdigest()!=part['cad_sha256']:
        raise ValueError('Embedded CAD asset size or SHA-256 mismatch')
    if part.get('cad_format','step')=='brep':
        if part.get('cad_model')!=part.get('cad_evaluated_model'):raise ValueError('CAD parameters changed: recompute and confirm the BRep before preview/meshing')
        if part.get('cad_source_units')!='m' or part.get('cad_source_to_m')!=1.0:raise ValueError('BRep must carry explicit metre units')
        from native_occt import validate_brep
        native=validate_brep(raw)
        return raw,'m',1.0,'asset.brep',native['validation']
    if part.get('cad_format','step')!='step':raise ValueError('Unsupported CAD serialization')
    unit,factor=source_length_unit(raw)
    from native_occt import run as native_run
    native,_=native_run(raw,'step')
    if native['validation']['status']!='VALID':raise ValueError('Native STEP validation rejected geometry: '+json.dumps(native['validation']))
    return raw,unit,factor,'asset.step',native['validation']

def cad_asset(part):
    raw,unit,factor,name,native=source_cad_asset(part)
    if not part.get('instance_uuid'):return raw,unit,factor,name,native # legacy world-space geometry
    if name.endswith('.step'):
        from native_occt import run
        receipt,raw=run(raw,'step')
        native=receipt['validation']
    from instance_placement import place
    raw,native=place(raw,part,native)
    return raw,unit,factor,'instance.brep',native


def imported_face_mapping(part,native):
    """Immutable STEP provenance; legacy names are opaque verified tokens."""
    import gmsh
    from cad_model import descriptor
    from native_graph import signature
    mapping={};used=set();old=part.get('cad_faces',[])
    for dim,tag in gmsh.model.getBoundary(gmsh.model.getEntities(3),oriented=False):
        desc=descriptor(tag)
        matches=[f for f in native['faces'] if abs(f['area']-desc['area'])<=max(1e-11,desc['area']*1e-9) and all(abs(a-b)<=max(1e-11,abs(b)*1e-9) for a,b in zip(f['center'],desc['center'])) and all(abs(a-b)<=max(1e-11,abs(b)*1e-9) for a,b in zip(f['inertia'],desc['inertia'])) and all(abs(a-b)<=max(2e-7,2*native['maximum_tolerance_m'],abs(b)*1e-9) for a,b in zip(f['bounds'],desc['bounds']))]
        if len(matches)!=1:raise ValueError('Ambiguous native STEP/Gmsh face correspondence')
        face=matches[0]
        name='S2_'+signature([part.get('id','source'),part['cad_sha256'],face['area'],face['center']])
        if old:
            tokens=[key for key in old if key in part.get('cad_face_areas',{}) and abs(part['cad_face_areas'][key]-desc['area'])<=max(1e-11,desc['area']*1e-9) and len(part.get('cad_face_centers',{}).get(key,[]))==3 and all(abs(a-b)<=max(1e-11,abs(b)*1e-9) for a,b in zip(part['cad_face_centers'][key],desc['center']))]
            if len(tokens)!=1:raise ValueError('STEP boundary identity requires explicit review; no tag fallback')
            name=tokens[0]
        if name in used:raise ValueError('Ambiguous STEP face identity')
        mapping[tag]=name;used.add(name)
    if len(mapping)!=native['face_count'] or (old and used!=set(old)):raise ValueError('Incomplete STEP face identity coverage')
    return mapping

def source_length_unit(raw):
    text = raw.decode('latin-1')
    matches = set(re.findall(r'LENGTH_UNIT\s*\(\s*\)\s*NAMED_UNIT\s*\(\s*\*\s*\)\s*SI_UNIT\s*\(\s*(\.[A-Z]+\.|\$)\s*,\s*\.METRE\.\s*\)', text, re.I))
    scales = {'.MILLI.': ('mm', 0.001), '.CENTI.': ('cm', 0.01), '$': ('m', 1.0)}
    if len(matches) != 1 or next(iter(matches)).upper() not in scales:
        raise ValueError('Unsupported or ambiguous STEP source length unit')
    return scales[next(iter(matches)).upper()]

def preview_step(root, part):
    """Tessellate OCC faces for display without generating a volume FEM mesh."""
    sys.path.insert(0, str(root/'.tools/engines/gmsh-4.15.2-Windows64-sdk/lib'))
    import gmsh
    raw, source_unit, source_to_m, asset_name,native = cad_asset(part)
    with tempfile.TemporaryDirectory(prefix='unicore-preview-') as temporary:
        source = Path(temporary)/asset_name
        source.write_bytes(raw)
        gmsh.initialize([], readConfigFiles=False)
        try:
            gmsh.option.setNumber('General.NumThreads', 1)
            gmsh.option.setString('Geometry.OCCTargetUnit', 'M')
            imported = gmsh.model.occ.importShapes(str(source), highestDimOnly=True)
            if len(imported) != 1 or imported[0][0] != 3:
                raise ValueError('STEP preview requires exactly one solid')
            solid = imported[0][1]
            gmsh.model.occ.synchronize()
            volume = gmsh.model.occ.getMass(3, solid)
            if volume <= 0: raise ValueError('STEP solid has nonpositive volume')
            faces = {}
            face_mapping={}
            if 'instance_face_names' in native:
                from instance_placement import imported_faces
                face_mapping=imported_faces(native)
            elif part.get('cad_format')=='brep':
                from cad_model import evaluated_faces
                face_mapping=evaluated_faces(part)
            else:face_mapping=imported_face_mapping(part,native)
            for dim, tag in gmsh.model.getBoundary([(3, solid)], oriented=False):
                if dim != 2: raise ValueError('Unexpected non-surface boundary')
                name = face_mapping[tag]
                area=gmsh.model.occ.getMass(2,tag);center=list(gmsh.model.occ.getCenterOfMass(2,tag))
                previous=faces.get(name,{'tags':[], 'area':0., 'center':[0.,0.,0.]})
                total=previous['area']+area
                faces[name]={'tags':previous['tags']+[tag], 'area':total,'center':[(previous['center'][i]*previous['area']+center[i]*area)/total for i in range(3)]}
            bounds = list(gmsh.model.occ.getBoundingBox(3, solid))
            span = max(bounds[i+3]-bounds[i] for i in range(3))
            gmsh.option.setNumber('Mesh.MeshSizeMin', max(span/40, 1e-6))
            gmsh.option.setNumber('Mesh.MeshSizeMax', max(span/40, 1e-6))
            gmsh.model.mesh.generate(2)
            nodes = []
            triangles = {}
            for name, info in faces.items():
                connectivity=[int(n) for tag in info['tags'] for n in gmsh.model.mesh.getElementsByType(2,tag)[1]]
                region = []
                for offset in range(0, len(connectivity), 3):
                    triangle = []
                    for node_tag in connectivity[offset:offset+3]:
                        xyz, _, _, _ = gmsh.model.mesh.getNode(int(node_tag))
                        triangle.append(len(nodes)); nodes.append(list(map(float, xyz)))
                    region.append(triangle)
                if not region: raise ValueError('CAD face has no display triangles: '+name)
                triangles[name] = region
            return {'source_sha256': part['cad_sha256'], 'nodes': nodes, 'surface_regions': {part['id']: triangles},
                    'face_areas': {name: info['area'] for name, info in faces.items()},
                    'face_centers': {name: info['center'] for name, info in faces.items()},
                    'definition_faces':native.get('definition_faces',{}),
                    'native_validation':native.get('placement_receipt',{}).get('before',native),
                    'cad_volume': volume, 'bounds': bounds, 'units': 'm',
                    'source_units': source_unit, 'source_to_m': source_to_m}
        finally:
            gmsh.finalize()

def mesh_study(root, study, size):
    if not study.get('_participation_resolved'):
        import copy
        study=copy.deepcopy(study)
        if any(not isinstance(p.get('analysis_enabled',True),bool) for p in study['parts']):raise ValueError('Invalid analysis participation')
        study['parts']=[p for p in study['parts'] if p.get('analysis_enabled',True)]
        study['_participation_resolved']=True
        if not study['parts']:raise ValueError('Enable at least one instance for analysis')
    if study.get('assembly_schema')==1:
        import copy
        study=copy.deepcopy(study)
        for part in study['parts']:
            definition=study.get('part_definitions',{}).get(part.get('definition_uuid'))
            if not definition or definition.get('uuid')!=part.get('definition_uuid'):raise ValueError('Missing instance definition')
            for key,value in definition['geometry'].items():
                if part.get(key)!=value:raise ValueError('Instance source differs from immutable definition')
                part[key]=copy.deepcopy(value)
    if len(study['parts']) > 1:
        from assembly_mesh import compose
        from assembly_interference import inspect_assembly
        interference=inspect_assembly(study['parts'])
        meshes={}; entries=[]
        for part in study['parts']:
            if part['id'] in meshes:raise ValueError('Duplicate assembly instance')
            if part['id'] in study.get('_assembly_mesh_settings',{}):
                from mesh_config import decode_numbers
                part['mesh_settings']=decode_numbers(study['_assembly_mesh_settings'][part['id']])
            mesh=mesh_study(root,dict(parts=[part]),size)
            meshes[part['id']]=mesh
            entries.append(dict(instance_id=part['id'],material_id=part['id'],mesh=mesh))
        result=compose(entries)
        orders={m['formulation'] for m in meshes.values()}
        if len(orders)!=1:raise ValueError('Mixed assembly element orders are not qualified')
        result.update(interference=interference,part_meshes=meshes,groups={},regions={},surface_regions={},quadratic_surfaces={},
                      formulation=next(iter(orders)),geometry_backend='gmsh_4.15.2',divisions=study.get('mesh_divisions',4))
        if result['formulation']=='TET10':result.update(mesh_schema=2,node_order='CalculiX C3D10')
        for key,mesh in meshes.items():
            offset=result['instances'][key]['node_range'][0]
            for field in ['groups','surface_regions','quadratic_surfaces']:
                if field not in mesh:continue
                result[field][key]={name:([offset+i for i in rows] if field=='groups' else [[offset+i for i in row] for row in rows]) for name,rows in mesh[field][key].items()}
            result['regions'][key]=result['groups'][key]
        return result
    sys.path.insert(0, str(root/'.tools/engines/gmsh-4.15.2-Windows64-sdk/lib'))
    import gmsh
    if len(study['parts']) != 1: raise ValueError('Gmsh pack requires one solid')
    p = study['parts'][0]
    from face_identity import validate_assignments
    validate_assignments(p)
    if '_mesh_settings_exact' in study:
        from mesh_config import decode_numbers
        p['mesh_settings']=decode_numbers(study['_mesh_settings_exact'])
    started=time.monotonic();config=p.get('mesh_settings')
    if config is not None:
        from mesh_config import validate
        validate(config)
    if p['kind']!='CAD' and (any(p.get('rotation',[0,0,0])) or p.get('scale',[1,1,1]) != [1,1,1]):
        raise ValueError('Transformed solids are unsupported by this pack')
    d=p['dimensions']; xyz=p['position']; lo=[xyz[i]-d[i]/2 for i in range(3)]
    if not math.isfinite(size) or size<=0 or any(not math.isfinite(v) or v<=0 for v in d):raise ValueError('Invalid geometry/mesh size')
    if p['kind']!='CAD' and math.prod(d)/size**3>100000:raise ValueError('Mesh request exceeds optional pack resource bound; use a coarser mesh')
    cad_temp = None
    if p['kind']=='CAD':
        raw, source_unit, source_to_m, asset_name,native = cad_asset(p)
        if p.get('cad_source_units', source_unit) != source_unit or p.get('cad_source_to_m', source_to_m) != source_to_m:
            raise ValueError('STEP source unit metadata mismatch')
        cad_temp=tempfile.TemporaryDirectory(prefix='unicore-cad-',dir=os.environ.get('UNICORE_MESH_JOB_TEMP'))
        (Path(cad_temp.name)/asset_name).write_bytes(raw)
    gmsh.initialize([], readConfigFiles=False)
    try:
        gmsh.option.setNumber('General.NumThreads',1)
        gmsh.option.setNumber('Mesh.MaxNumThreads1D',1)
        gmsh.option.setNumber('Mesh.MaxNumThreads2D',1)
        gmsh.option.setNumber('Mesh.MaxNumThreads3D',1)
        gmsh.option.setNumber('Mesh.MeshSizeMin',size)
        gmsh.option.setNumber('Mesh.MeshSizeMax',size)
        gmsh.option.setNumber('Mesh.ElementOrder',1)
        if p['kind']=='CAD':
            source=Path(cad_temp.name)/asset_name if cad_temp else Path(p['cad_path']).resolve()
            if source.suffix.lower() not in ('.step','.stp','.iges','.igs','.brep'):
                raise ValueError('Unsupported exact CAD file format')
            if source.stat().st_size>64*1024*1024:
                raise ValueError('CAD input exceeds 64 MiB import bound')
            if digest(source)!=hashlib.sha256(raw).hexdigest():
                raise ValueError('CAD snapshot hash mismatch')
            gmsh.option.setString('Geometry.OCCTargetUnit','M')
            imported=gmsh.model.occ.importShapes(str(source),highestDimOnly=True)
            if len(imported)!=1 or imported[0][0]!=3:
                raise ValueError('This adapter requires exactly one solid; shells and assemblies need the multi-body adapter')
            solid=imported[0][1]
            if gmsh.model.occ.getMass(3,solid)<=0:
                raise ValueError('Imported solid has nonpositive volume')
        elif p['kind']=='Box':
            solid=gmsh.model.occ.addBox(*lo,*d)
        elif p['kind']=='Cylinder':
            solid=gmsh.model.occ.addCylinder(xyz[0],xyz[1]-d[1]/2,xyz[2],0,d[1],0,d[0]/2)
        else: raise ValueError('Only Box and Cylinder supported')
        gmsh.model.occ.synchronize()
        face_mapping={}
        if p['kind']=='CAD' and 'instance_face_names' in native:
            from instance_placement import imported_faces
            face_mapping=imported_faces(native)
        elif p.get('cad_format')=='brep':
            from cad_model import evaluated_faces
            face_mapping=evaluated_faces(p)
        elif p['kind']=='CAD' and 'cad_base64' in p:face_mapping=imported_face_mapping(p,native)
        regions={}; face_areas={}
        for dim,tag in gmsh.model.getBoundary([(3,solid)],oriented=False):
            center=gmsh.model.occ.getCenterOfMass(dim,tag)
            if p['kind']=='CAD':
                name=face_mapping[tag]
            elif p['kind']=='Box':
                matches=[('XYZ'[i]+sign) for i in range(3) for sign,coordinate in [('-',lo[i]),('+',lo[i]+d[i])] if abs(center[i]-coordinate)<max(d)*1e-7]
                if len(matches)!=1: raise ValueError('Ambiguous CAD face')
                name=matches[0]
            else:
                name='Bottom' if abs(center[1]-(xyz[1]-d[1]/2))<d[1]*1e-7 else 'Top' if abs(center[1]-(xyz[1]+d[1]/2))<d[1]*1e-7 else 'Lateral'
            regions.setdefault(name,[]).append(tag)
            face_areas[name]=face_areas.get(name,0)+gmsh.model.occ.getMass(2,tag)
        for name,surface_tags in regions.items():
            group=gmsh.model.addPhysicalGroup(2,surface_tags);gmsh.model.setPhysicalName(2,group,name)
        if p['kind']=='CAD' and p.get('cad_faces') and set(p['cad_faces'])!=set(regions):
            raise ValueError('CAD topology changed: face selections cannot be remapped')
        if p['kind']=='CAD' and p.get('cad_face_areas'):
            for name, area in face_areas.items():
                reference=p['cad_face_areas'].get(name)
                if reference is None or abs(reference-area)>max(1e-9,abs(area)*1e-8):
                    raise ValueError('CAD face area changed: '+name)
        gmsh.model.addPhysicalGroup(3,[solid],name=p['id'])
        cad_volume=gmsh.model.occ.getMass(3,solid)
        if config is not None:
            from mesh_config import apply
            bounds=gmsh.model.occ.getBoundingBox(3,solid)
            apply(gmsh,config,regions,cad_volume,max(bounds[i+3]-bounds[i] for i in range(3)))
        gmsh.model.mesh.generate(3)
        optimization={}
        if config is not None:
            from mesh_quality import metrics
            pre_tags,pre_coords,_=gmsh.model.mesh.getNodes();pre_index={int(tag):i for i,tag in enumerate(pre_tags)}
            _,pre_conn=gmsh.model.mesh.getElementsByType(4)
            pre_nodes=[list(map(float,pre_coords[3*i:3*i+3])) for i in range(len(pre_tags))]
            pre_cells=[[pre_index[int(t)] for t in pre_conn[i:i+4]] for i in range(0,len(pre_conn),4)]
            if len(pre_nodes)>config['max_nodes'] or len(pre_cells)>config['max_elements']:raise ValueError('Gmsh mesh exceeds configured node/element limits; increase target/local sizes')
            before=metrics(pre_nodes,pre_cells,cad_volume);optimization['before']={k:v for k,v in before.items() if k!='per_element'}
            del pre_nodes,pre_cells,before,pre_tags,pre_coords,pre_index,pre_conn
            if config['optimization']!='none':gmsh.model.mesh.optimize('Netgen' if config['optimization']=='netgen' else '',niter=int(config['optimize_iterations']))
        order=int(config.get('order',1)) if config else 1
        if order==2:
            gmsh.option.setNumber('Mesh.SecondOrderLinear',0)
            gmsh.model.mesh.setOrder(2)
        tags,coords,_=gmsh.model.mesh.getNodes()
        tags=list(map(int,tags)); index={tag:i for i,tag in enumerate(tags)}
        nodes=[list(map(float,coords[3*i:3*i+3])) for i in range(len(tags))]
        element_type=11 if order==2 else 4;width=10 if order==2 else 4
        types,_,_=gmsh.model.mesh.getElements(3)
        if list(types)!=[element_type]:raise ValueError('Unsupported mixed-order or non-tetrahedral mesh')
        etags,connect=gmsh.model.mesh.getElementsByType(element_type)
        from quadratic_tet import GMSH_TO_CCX,exterior,subtri
        permutation=GMSH_TO_CCX if order==2 else list(range(4))
        elements=[[index[int(connect[i+j])] for j in permutation] for i in range(0,len(connect),width)]
        quadratic_faces={};outside=exterior(elements) if order==2 else {}
        groups={};faces={}
        for name,surface_tags in regions.items():
            tri=[int(n) for tag in surface_tags for n in gmsh.model.mesh.getElementsByType(9 if order==2 else 2,tag)[1]]
            if order==2:
                quadratic_faces[name]=[]
                for i in range(0,len(tri),6):
                    ids=[index[int(t)] for t in tri[i:i+6]];entry=outside.get(tuple(sorted(ids)))
                    if entry is None:raise ValueError('Quadratic CAD surface does not match a C3D10 exterior face')
                    quadratic_faces[name].append(entry['nodes'])
                faces[name]=[triangle for f in quadratic_faces[name] for triangle in subtri(f)]
            else:faces[name]=[[index[int(t)] for t in tri[i:i+3]] for i in range(0,len(tri),3)]
            groups[name]=sorted({v for triangle in faces[name] for v in triangle})
        minimum=math.inf
        volumes=0.0; boundary=Counter()
        for cell in elements:
            if order==2:
                for local in __import__('quadratic_tet').FACES:
                    for face in subtri([cell[i] for i in local]):boundary[tuple(sorted(face))]+=1
                continue
            a,b,c,e=[nodes[i] for i in cell]
            u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)];w=[e[i]-a[i] for i in range(3)]
            det=sum(u[i]*(v[(i+1)%3]*w[(i+2)%3]-v[(i+2)%3]*w[(i+1)%3]) for i in range(3))
            if not math.isfinite(det) or det<=0: raise ValueError('Invalid TET4 orientation')
            minimum=min(minimum,det)
            volumes+=det/6
            for f in [(0,1,2),(0,1,3),(0,2,3),(1,2,3)]:boundary[tuple(sorted(cell[i] for i in f))]+=1
        if any(count>2 for count in boundary.values()):raise ValueError('Nonmanifold volume mesh')
        expected={face for face,count in boundary.items() if count==1}
        actual=[tuple(sorted(triangle)) for region in faces.values() for triangle in region]
        if len(actual)!=len(set(actual)) or set(actual)!=expected:raise ValueError('CAD boundary triangles do not match TET4 exterior')
        from mesh_quality import metrics
        if order==2:
            from quadratic_tet import mesh_quality
            quality=mesh_quality(nodes,elements,cad_volume);volumes=quality['mesh_volume']
        else:quality=metrics(nodes,elements,cad_volume)
        quality['exterior_triangles']=len(actual)
        if config is not None:
            if len(nodes)>config['max_nodes'] or len(elements)>config['max_elements']:raise ValueError('Optimized mesh exceeds configured node/element limits')
            if quality.get('minimum_quadratic_quality',quality['minimum_mean_ratio'])<config['min_quality'] or quality['maximum_edge_ratio']>config['max_edge_ratio'] or quality['degenerate_elements']:raise ValueError('Mesh rejected by quality thresholds')
            optimization['after']={k:v for k,v in quality.items() if k!='per_element'}
        result=dict(nodes=nodes,elements=elements,node_tags=tags,element_tags=list(map(int,etags)),
                    material_regions=[p['id']]*len(elements),regions={p['id']:groups},groups={p['id']:groups},surface_regions={p['id']:faces},
                    divisions=study.get('mesh_divisions',4),formulation='TET10' if order==2 else 'TET4',geometry_backend='gmsh_4.15.2',
                    geometry_identity=hashlib.sha256(json.dumps(study['parts'],sort_keys=True).encode()).hexdigest(),
                    instance_placement=native.get('placement_receipt',{}) if p['kind']=='CAD' else {},
                    geometry_part={key:p[key] for key in ['id','kind','dimensions','position','rotation','scale','cad_sha256'] if key in p},
                    provenance=dict(gmsh=gmsh.__version__,threads=1,size=size,mesh_volume=volumes,cad_volume=gmsh.model.occ.getMass(3,solid),cad_sha256=p.get('cad_sha256',''),cad_face_areas=face_areas,source_units=source_unit if p['kind']=='CAD' else 'm',source_to_m=source_to_m if p['kind']=='CAD' else 1.0),
                    quality=quality)
        if p['kind']=='CAD' and 'instance_face_names' in native:
            from face_identity import proof
            result['face_resolution']=proof(p,native,face_mapping)
        result['node_owners']=[p['id']]*len(nodes)
        result['element_owners']=[p['id']]*len(elements)
        result['instances']={p['id']:dict(node_range=[0,len(nodes)],element_range=[0,len(elements)],material_id=p['id'],element_order=order)}
        result['meshing_seconds']=time.monotonic()-started
        if order==2:
            corners={i for c in elements for i in c[:4]};midsides={i for c in elements for i in c[4:]}
            if corners&midsides:raise ValueError('A quadratic node is used as both corner and midside')
            result.update(element_order=2,mesh_schema=2,node_order='CalculiX C3D10',gmsh_to_calculix_permutation=GMSH_TO_CCX,quadratic_surfaces={p['id']:quadratic_faces},corner_nodes=len(corners),midside_nodes=len(midsides),display_tessellation='TRI6 four subtriangles through all quadratic face nodes')
        if config is not None:
            result['mesh_settings']=config
            from mesh_config import encode_numbers
            result['mesh_settings_exact']=encode_numbers(config)
            result['geometry_revision']=p.get('cad_geometry_revision',p.get('cad_sha256',hashlib.sha256(json.dumps(result['geometry_part'],sort_keys=True).encode()).hexdigest()))
            result['generation_id']=hashlib.sha256(json.dumps([result['geometry_part'],config,nodes,elements],sort_keys=True,separators=(',',':')).encode()).hexdigest()
            result['optimization']=optimization
        return result
    finally:
        gmsh.finalize()
        if cad_temp: cad_temp.cleanup()

if __name__=='__main__':
    root=Path(__file__).resolve().parents[2]
    try:
        source=Path(sys.argv[1])
        if source.stat().st_size>128*1024*1024:raise ValueError('Gmsh request exceeds 128 MiB')
        study=json.loads(source.read_text(encoding='utf-8'))
        result=preview_step(root,study['parts'][0]) if len(sys.argv)>3 and sys.argv[3]=='preview' else mesh_study(root,study,float(sys.argv[3]))
        text=json.dumps(result,allow_nan=False)
        if len(text.encode())>192*1024*1024:raise ValueError('Gmsh response exceeds 192 MiB; coarsen the mesh')
        Path(sys.argv[2]).write_text(text,encoding='utf-8')
    except Exception as error:
        Path(sys.argv[2]).write_text(json.dumps(dict(error=str(error))),encoding='utf-8')
        print(str(error),file=sys.stderr);raise SystemExit(1)
