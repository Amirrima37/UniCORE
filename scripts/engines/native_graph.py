"""Native feature evaluation and serialized operation-scoped face provenance.

Kernel slots exist only within one receipt. Persistent identifiers are derived
from feature provenance and serialized geometric signatures, never slot numbers.
Modified/split/merged faces require boundary review in the document policy.
"""
import base64,hashlib,json,math,uuid
from native_occt import run
def normalized(value):
    if isinstance(value,bool):return value
    if isinstance(value,(int,float)):return float(value)
    if isinstance(value,list):return [normalized(v) for v in value]
    if isinstance(value,dict):return {k:normalized(v) for k,v in value.items()}
    return value

def verified_input_faces(previous, actual):
    # The native BREP reader may enumerate faces differently from its writer.
    # Verify a unique bijection before consulting operation-scoped history slots.
    def equivalent(a,b):
        for name in ['area','center','bounds','inertia']:
            av=a[name] if isinstance(a[name],list) else [a[name]]
            bv=b[name] if isinstance(b[name],list) else [b[name]]
            if len(av)!=len(bv) or any(abs(x-y)>1e-10*max(1.,abs(x),abs(y)) for x,y in zip(av,bv)):return False
        return a.get('orientation')==b.get('orientation')
    if len(previous)!=len(actual):raise ValueError('Native input topology coverage mismatch')
    result={};used=set()
    for face in actual:
        candidates=[(slot,record) for slot,record in previous.items() if equivalent(record['descriptor'],face)]
        if len(candidates)!=1 or candidates[0][0] in used:raise ValueError('Ambiguous serialized native input face mapping')
        slot,record=candidates[0];used.add(slot);result[face['slot']]=record
    return result

def signature(value):return hashlib.sha256(json.dumps(normalized(value),sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()[:24]
def evaluate(model):
    by_id={n['id']:n for n in model['nodes']};cache={};operations=[]
    recipes={}
    def recipe(key):
        if key not in recipes:
            n=by_id[key]
            fields={k:v for k,v in n.items() if k not in ['name','label','source_base64','base','tool']}
            for dependency in ['base','tool']:
                if dependency in n:fields[dependency]=recipe(n[dependency])
            recipes[key]=signature(fields)
        return recipes[key]
    def build(key):
        if key in cache:return cache[key]
        n=by_id[key];kind=n['type'];scale=n.get('scale',[1,1,1])
        if kind in ['Union','Cut','Intersect']:
            a,af=build(n['base']);b,bf=build(n['tool'])
            receipt,raw=run(a,{'Union':'fuse','Cut':'cut','Intersect':'common'}[kind],tool=b,feature=key)
            af=verified_input_faces(af,receipt['before']['faces'])
            bf=verified_input_faces(bf,receipt['tool_before']['faces'])
            ancestry={f['slot']:[] for f in receipt['validation']['faces']}
            for h in receipt['face_history']:
                source=(af if h['operand']==0 else bf)[h['input_slot']]
                for relation in ['unchanged','modified','generated']:
                    for target in h[relation]:ancestry[target].append(dict(identity=source['identity'],relation=relation,split=len(h['modified'])>1))
            faces={}
            for f in receipt['validation']['faces']:
                parents=sorted(ancestry[f['slot']],key=lambda p:(p['identity'],p['relation'],p['split']))
                unique={p['identity'] for p in parents}
                unchanged=len(parents)==1 and parents[0]['relation']=='unchanged'
                identity=parents[0]['identity'] if unchanged else 'N_'+signature([key,recipe(key),parents,f['area'],f['center']])
                faces[f['slot']]=dict(identity=identity,ancestry=parents,state='unchanged' if unchanged else 'merged' if len(unique)>1 else 'split' if any(p['split'] for p in parents) else 'generated' if any(p['relation']=='generated' for p in parents) else 'modified' if parents else 'ambiguous',descriptor=f)
        else:
            if kind=='STEP':
                raw=base64.b64decode(n['source_base64'],validate=True)
                if hashlib.sha256(raw).hexdigest()!=n['source_sha256']:raise ValueError('STEP source hash mismatch')
                from gmsh_study import source_length_unit
                units,factor=source_length_unit(raw)
                if n.get('source_units',units)!=units or n.get('source_to_m',factor)!=factor:raise ValueError('STEP source unit mismatch')
                n['source_units']=units;n['source_to_m']=factor
                receipt,raw=run(raw,'step',feature=key)
                if receipt['validation']['solid_count']!=1:raise ValueError('STEP assemblies/shells unsupported: exactly one solid required')
            else:
                d=n['dimensions']
                # Preserve the established analytic primitive scaling restrictions.
                if kind in ['Cylinder','Pipe'] and scale[0]!=scale[2]:raise ValueError('Elliptical primitive scaling unsupported')
                if kind=='Sphere' and len(set(scale))!=1:raise ValueError('Nonuniform sphere primitive scaling unsupported')
                d=[d[i]*scale[i] for i in range(3)]
                if any(not 1e-6<=x<=1000 for x in d):raise ValueError('Primitive dimensions outside safe range')
                receipt,raw=run(action={'Box':'box','Cylinder':'cylinder','Pipe':'cylinder','Sphere':'sphere'}[kind],dimensions=d,feature=key)
                if kind=='Pipe':
                    inner=n.get('inner_diameter',0)*scale[0]
                    if not 0<inner<d[0]:raise ValueError('Invalid pipe inner diameter')
                    _,tool=run(action='cylinder',dimensions=[inner,d[1],inner],feature=key+'/bore')
                    receipt,raw=run(raw,'cut',tool=tool,feature=key)
            seed=[key,kind,n['source_sha256']] if kind=='STEP' else [key,kind,d,n.get('inner_diameter')]
            faces={f['slot']:dict(identity='N_'+signature([seed,f['area'],f['center']]),ancestry=[],state='original',descriptor=f) for f in receipt['validation']['faces']}
        if receipt['validation']['status']!='VALID' or raw is None:raise ValueError('Native geometry rejected: '+json.dumps(receipt['validation']))
        def record(stage):
            operations.append(dict(feature=key,feature_uuid=str(uuid.uuid5(uuid.NAMESPACE_URL,'UniCORE/feature/'+key)),operation_uuid=str(uuid.uuid5(uuid.NAMESPACE_URL,'UniCORE/operation/'+key+'/'+stage)),stage=stage,receipt=receipt,faces=faces))
        record('construction')
        # Native affine transforms, explicitly separate from Gmsh's OCCT runtime.
        if kind in ['STEP','Union','Cut','Intersect'] and scale!=[1,1,1]:
            receipt,raw=run(raw,'transform',matrix=[scale[0],0,0,0,0,scale[1],0,0,0,0,scale[2],0],feature=key)
            # No asserted face continuation without transform history: review all.
            faces={f['slot']:dict(identity='N_'+signature([key,recipe(key),'transform',f['area'],f['center']]),ancestry=[],state='modified',descriptor=f) for f in receipt['validation']['faces']}
            record('scale')
        rotation=n.get('rotation',[0,0,0]);pos=n.get('position',[0,0,0])
        if any(rotation) or any(pos):
            matrix=[[1.,0.,0.],[0.,1.,0.],[0.,0.,1.]]
            for axis,angle in enumerate(rotation):
                c=math.cos(math.radians(angle));s=math.sin(math.radians(angle));r=[[1.,0.,0.],[0.,1.,0.],[0.,0.,1.]];a=(axis+1)%3;b=(axis+2)%3;r[a][a]=r[b][b]=c;r[a][b]=-s;r[b][a]=s
                matrix=[[sum(r[i][k]*matrix[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
            receipt,raw=run(raw,'transform',matrix=[v for i,row in enumerate(matrix) for v in row+[pos[i]]],feature=key)
            faces={f['slot']:dict(identity='N_'+signature([key,recipe(key),'placement',f['area'],f['center']]),ancestry=[],state='modified',descriptor=f) for f in receipt['validation']['faces']}
            record('placement')
        if receipt['validation']['status']!='VALID' or raw is None:raise ValueError('Invalid transformed output')
        angle=n.get('axis_angle',0)
        if angle:
            axis=n.get('axis_direction',[0,1,0]);point=n.get('axis_point',[0,0,0])
            if not isinstance(angle,(int,float)) or not math.isfinite(angle) or abs(angle)>1e6 or len(axis)!=3 or len(point)!=3 or any(not isinstance(x,(int,float)) or not math.isfinite(x) or abs(x)>1e6 for x in axis+point):raise ValueError('Invalid arbitrary-axis transform')
            length=math.sqrt(sum(x*x for x in axis))
            if length<1e-12:raise ValueError('Rotation axis must be nonzero')
            x,y,z=[v/length for v in axis];c=math.cos(math.radians(angle));s=math.sin(math.radians(angle));t=1-c
            rotation=[[t*x*x+c,t*x*y-s*z,t*x*z+s*y],[t*x*y+s*z,t*y*y+c,t*y*z-s*x],[t*x*z-s*y,t*y*z+s*x,t*z*z+c]]
            shift=[point[i]-sum(rotation[i][j]*point[j] for j in range(3)) for i in range(3)]
            matrix=[v for i,row in enumerate(rotation) for v in row+[shift[i]]]
            receipt,raw=run(raw,'transform',matrix=matrix,feature=key)
            faces={f['slot']:dict(identity='N_'+signature([key,recipe(key),'axis',axis,point,angle,f['area'],f['center']]),ancestry=[],state='modified',descriptor=f) for f in receipt['validation']['faces']}
            record('axis_rotation')
        if receipt['validation']['status']!='VALID' or raw is None:raise ValueError('Native transformation rejected geometry')
        if len({f['identity'] for f in faces.values()})!=len(faces):raise ValueError('Ambiguous native face signatures')
        cache[key]=(raw,faces);return cache[key]
    raw,faces=build(model['root']);return raw,faces,operations
