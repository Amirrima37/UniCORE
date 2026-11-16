"""Immutable-source face names and verified rigid transport, not enumeration IDs."""
import hashlib,json,math,time

def canonical(value):
    if isinstance(value,dict):return {k:canonical(v) for k,v in sorted(value.items())}
    if isinstance(value,list):return [canonical(v) for v in value]
    if isinstance(value,(int,float)):return float(value)
    return value
def digest(value):return hashlib.sha256(json.dumps(canonical(value),sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()

def source_names(part,before):
    from instance_placement import close
    old=part.get('cad_faces',[]);names={};used=set()
    saved=part.get('cad_definition_faces',part.get('cad_face_descriptors',{}))
    for source in before['faces']:
        matches=[]
        for key in old:
            if not close([part.get('cad_face_areas',{}).get(key,-1)],[source['area']]) or not close(part.get('cad_face_centers',{}).get(key,[]),source['center']):continue
            desc=saved.get(key,{})
            if 'inertia' in desc and not close(desc['inertia'],source['inertia']):continue
            if 'bounds' in desc and any(abs(a-b)>max(2e-7,abs(b)*1e-9) for a,b in zip(desc['bounds'],source['bounds'])):continue
            if 'plane_outward_normal' in desc and not close(desc['plane_outward_normal'],source.get('plane_outward_normal',[])):continue
            matches.append(key)
        if old:
            if len(matches)!=1 or matches[0] in used:raise ValueError('Ambiguous/missing definition face identity; explicit source-face review required')
            name=matches[0]
        else:
            descriptor={key:value for key,value in source.items() if key not in ['slot']}
            name='DF_'+digest([part['cad_sha256'],descriptor])[:32]
            if name in used:raise ValueError('Indistinguishable definition faces; identity cannot be fabricated')
        names[source['slot']]=name;used.add(name)
    if old and used!=set(old):raise ValueError('Deleted definition face or incomplete source identity')
    return names

def validate_assignments(part):
    from instance_placement import close
    if part.get('kind')!='CAD':return
    # Legacy direct engine callers have no document reference schema. Godot's
    # document compatibility path migrates them before current-schema solving.
    if 'boundary_schema' not in part:return
    if part['boundary_schema']!=1 or not isinstance(part.get('boundary_refs'),dict):raise ValueError('Invalid assembly boundary schema')
    if not isinstance(part.get('instance_uuid'),str) or len(part['instance_uuid'])!=36:raise ValueError('Missing boundary instance UUID')
    for key in ['support','load_face']:
        face=part.get(key,'');r=part['boundary_refs'].get(key)
        if not face and r is None:continue
        if not isinstance(r,dict) or r.get('state')!='resolved':raise ValueError('Unresolved boundary '+key+'; select a replacement face or clear')
        expected=dict(instance_uuid=part.get('instance_uuid'),definition_uuid=part.get('definition_uuid'),geometry_revision=part.get('geometry_revision'),transformation_revision=part.get('transformation_revision',0),source_sha256=part.get('cad_sha256'),definition_face_id=face,coordinate_system='global')
        if any(r.get(k)!=v for k,v in expected.items()):raise ValueError('Stale or cross-instance boundary '+key)
        if face not in part.get('cad_faces',[]):raise ValueError('Deleted definition face '+face)
        anchor=r.get('source_face')
        if not isinstance(anchor,dict) or 'area' not in anchor or 'center' not in anchor:raise ValueError('Missing source-face assignment anchor')
        table=part.get('cad_definition_faces',part.get('cad_face_descriptors',{})).get(face,{})
        current=dict(table,area=part.get('cad_face_areas',{}).get(face,-1),center=part.get('cad_face_centers',{}).get(face,[]))
        for key,value in anchor.items():
            a=value if isinstance(value,list) else [value];v=current.get(key,[]);b=v if isinstance(v,list) else [v]
            if not close(a,b):raise ValueError('Source-face assignment anchor mismatch')

def proof(part,native,mapping):
    names=native.get('instance_face_names',{})
    if not names:raise ValueError('Missing verified instance face provenance')
    world={names[f['slot']]:f for f in native['faces']}
    if set(world)!=set(mapping.values()):raise ValueError('Incomplete meshed face identity')
    return dict(schema=1,instance_uuid=part.get('instance_uuid'),definition_uuid=part.get('definition_uuid'),geometry_revision=part.get('geometry_revision'),transformation_revision=part.get('transformation_revision',0),source_sha256=part['cad_sha256'],placed_sha256=native['placement_receipt']['output_sha256'],source_faces=native['definition_faces'],world_faces=world,mesh_surfaces={key:[tag for tag,name in mapping.items() if name==key] for key in world},resolution_seconds=native.get('face_resolution_seconds',0),strategy='unique-native-rigid-moments-and-oriented-plane-normal; exact-source-descriptors; no nearest/index fallback')

def imported_mapping(native):
    import gmsh
    from cad_model import descriptor
    from instance_placement import close
    started=time.monotonic();groups={f['slot']:[] for f in native['faces']};descriptors={}
    tolerance=max(2e-7,2*native['maximum_tolerance_m'])
    def bounds_close(a,b):return all(abs(x-y)<=max(tolerance,abs(y)*1e-9) for x,y in zip(a,b))
    for _,tag in gmsh.model.getBoundary(gmsh.model.getEntities(3),oriented=False):
        d=descriptor(tag);descriptors[tag]=d
        exact=[f for f in native['faces'] if close([f['area']],[d['area']]) and close(f['center'],d['center']) and close(f['inertia'],d['inertia']) and bounds_close(f['bounds'],d['bounds']) and (('plane_outward_normal' in f)==(d['type']=='Plane'))]
        if len(exact)>1:raise ValueError('Ambiguous complete native/Gmsh face descriptors')
        candidates=exact
        if not candidates and d['type']=='Plane':
            candidates=[f for f in native['faces'] if 'plane_outward_normal' in f and d['area']<f['area'] and abs(sum((d['center'][i]-f['center'][i])*f['plane_outward_normal'][i] for i in range(3)))<tolerance and all(d['bounds'][i]>=f['bounds'][i]-tolerance and d['bounds'][i+3]<=f['bounds'][i+3]+tolerance for i in range(3))]
        if len(candidates)!=1:raise ValueError('Ambiguous/unproven OCCT-to-Gmsh subdivision; no nearest-face fallback')
        f=candidates[0]
        if 'plane_outward_normal' in f:
            lo,hi=gmsh.model.getParametrizationBounds(2,tag)
            normal=gmsh.model.getNormal(tag,[(lo[i]+hi[i])/2 for i in range(2)])
            if abs(abs(sum(normal[i]*f['plane_outward_normal'][i] for i in range(3)))-1)>1e-8:raise ValueError('Native/Gmsh plane normal mismatch')
        groups[f['slot']].append(tag)
    mapping={}
    for f in native['faces']:
        tags=groups[f['slot']]
        if not tags:raise ValueError('Missing native face in imported solid')
        area=sum(descriptors[t]['area'] for t in tags)
        center=[sum(descriptors[t]['area']*descriptors[t]['center'][i] for t in tags)/area for i in range(3)]
        moments=[0.]*9
        for tag in tags:
            d=descriptors[tag];delta=[d['center'][i]-center[i] for i in range(3)];length=sum(v*v for v in delta)
            for i in range(3):
                for j in range(3):moments[3*i+j]+=d['inertia'][3*i+j]+d['area']*((length if i==j else 0)-delta[i]*delta[j])
        bounds=[min(descriptors[t]['bounds'][i] for t in tags) for i in range(3)]+[max(descriptors[t]['bounds'][i+3] for t in tags) for i in range(3)]
        if not close([area],[f['area']]) or not close(center,f['center']) or not close(moments,f['inertia']) or not bounds_close(bounds,f['bounds']):raise ValueError('Imported face partition does not conserve complete surface moments/bounds')
        if len(tags)>1:
            edges={t:{abs(e) for dim,e in gmsh.model.getBoundary([(2,t)],oriented=False)} for t in tags};seen={tags[0]}
            while True:
                expanded=seen|{t for t in tags if any(edges[t]&edges[s] for s in seen)}
                if expanded==seen:break
                seen=expanded
            if seen!=set(tags):raise ValueError('Disconnected imported face partition')
        for tag in tags:mapping[tag]=native['instance_face_names'][f['slot']]
    bounds=gmsh.model.occ.getBoundingBox(3,gmsh.model.getEntities(3)[0][1])
    if not bounds_close(bounds,native['bounds']):raise ValueError('Transformed BREP/Gmsh bounds mismatch')
    native['face_resolution_seconds']=time.monotonic()-started
    return mapping
