"""Rigid instance placement at the isolated OCCT/Gmsh boundary.

Document Euler angles are radians, Godot's YXZ order. Forces stay global.
No transformed bytes are written back into the definition or document.
"""
import math
from native_occt import run

def matrix(part):
    def vector(key, default):
        v=part.get(key,default)
        if not isinstance(v,list) or len(v)!=3 or any(not isinstance(x,(int,float)) or not math.isfinite(x) or abs(x)>1e6 for x in v):
            raise ValueError('Invalid instance '+key)
        return v
    if vector('scale',[1,1,1]) != [1,1,1]:raise ValueError('Instance scaling is unsupported')
    position=vector('position',[0,0,0]);rotation=vector('rotation',[0,0,0])
    r=[[1.,0.,0.],[0.,1.,0.],[0.,0.,1.]]
    for axis in [2,0,1]:
        c=math.cos(rotation[axis]);s=math.sin(rotation[axis]);a=(axis+1)%3;b=(axis+2)%3
        q=[[1.,0.,0.],[0.,1.,0.],[0.,0.,1.]];q[a][a]=q[b][b]=c;q[a][b]=-s;q[b][a]=s
        r=[[sum(q[i][k]*r[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return [v for i in range(3) for v in r[i]+[position[i]]]

def point(m,p):return [sum(m[4*i+j]*p[j] for j in range(3))+m[4*i+3] for i in range(3)]
def close(a,b):return len(a)==len(b) and all(abs(x-y)<=max(1e-10,abs(y)*1e-8) for x,y in zip(a,b))
def inertia(m,t):
    return [sum(m[4*i+k]*t[3*k+l]*m[4*j+l] for k in range(3) for l in range(3)) for i in range(3) for j in range(3)]

def place(raw,part,before):
    m=matrix(part)
    receipt,placed=run(raw,'transform',matrix=m,feature=part.get('instance_uuid',part['id']))
    after=receipt['validation']
    if not placed or after['status']!='VALID' or after['volume']<=0:raise ValueError('Invalid transformed BREP')
    if abs(after['volume']/before['volume']-1)>1e-8 or abs(after['area']/before['area']-1)>1e-8 or not close(after['centroid'],point(m,before['centroid'])):
        raise ValueError('Rigid instance invariants failed')
    # Verify a bijection using analytic rigid transport of surface moments.
    # Ambiguity blocks the operation; native enumeration is never identity.
    from face_identity import source_names
    source_ids=source_names(part,before)
    definitions={source_ids[f['slot']]:f for f in before['faces']}
    names={};used=set()
    for source in before['faces']:
        matches=[f for f in after['faces'] if close([f['area']],[source['area']]) and close(f['center'],point(m,source['center'])) and close(f['inertia'],inertia(m,source['inertia']))]
        if len(matches)!=1 or matches[0]['slot'] in used:raise ValueError('Ambiguous source-to-instance face ancestry')
        target=matches[0];used.add(target['slot'])
        if source.get('orientation')!=target.get('orientation'):raise ValueError('Rigid face orientation changed unexpectedly')
        if 'plane_outward_normal' in source:
            normal=[sum(m[4*i+j]*source['plane_outward_normal'][j] for j in range(3)) for i in range(3)]
            if not close(normal,target.get('plane_outward_normal',[])):raise ValueError('Rigid plane normal mismatch')
        elif 'plane_outward_normal' in target:raise ValueError('Surface type changed under rigid placement')
        names[target['slot']]=source_ids[source['slot']]
    if len(used)!=after['face_count']:raise ValueError('Incomplete transformed face ancestry')
    after=dict(after,definition_faces=definitions,instance_face_names=names,placement_receipt=receipt,placement_matrix=m)
    return placed,after

def imported_faces(native):
    from face_identity import imported_mapping
    return imported_mapping(native)
