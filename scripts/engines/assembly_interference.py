"""Native pair checks on the actual world-space instance BREPs, before meshing."""
import copy,hashlib,json,os,time,uuid
from pathlib import Path
from native_occt import run,verify_installation,SDK
from development_paths import test_output_root
VERSION='occt-solid-pair-v1'

def instance_brep(part):
    if part['kind']=='CAD':
        from gmsh_study import cad_asset
        raw,_,_,name,_=cad_asset(part)
        if name.endswith('.step'):
            _,raw=run(raw,'step')
        return raw
    actions={'Box':'box','Cylinder':'cylinder','Sphere':'sphere'}
    action=actions.get(part['kind'])
    if not action:raise ValueError('Native interference geometry unsupported: '+part['kind'])
    _,raw=run(action=action,dimensions=part['dimensions'])
    from instance_placement import matrix
    _,placed=run(raw,'transform',matrix=matrix(part),feature=part.get('instance_uuid',part['id']))
    return placed

def classify(a,b,revisions=None,use_cache=True):
    started=time.monotonic()
    verify_installation()
    manifest=json.loads((SDK/'build-manifest.json').read_text())
    hashes=[hashlib.sha256(raw).hexdigest() for raw in [a,b]]
    identity=dict(algorithm=VERSION,hashes=hashes,revisions=revisions,worker=manifest['worker_sha256'],source=manifest['source_sha256'])
    key=hashlib.sha256(json.dumps(identity,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    parent=Path(os.environ.get('UNICORE_INTERFERENCE_CACHE_ROOT',str(test_output_root()/'CAD/interference-cache')))
    path=parent/(key+'.json')
    if use_cache and path.is_file():
        try:
            cached=json.loads(path.read_text())
            r=cached['receipt']
            if cached['identity']==identity and r['input_hashes']==hashes and r['pair']['algorithm']==VERSION and r['pair']['classification'] in ['SEPARATED','TOUCHING','OVERLAPPING'] and hashlib.sha256(json.dumps(r,sort_keys=True).encode()).hexdigest()==cached['receipt_sha256']:
                return dict(r['pair'],cache_hit=True,native_calls=0,seconds=time.monotonic()-started,cache_key=key,receipt=r)
        except (ValueError,KeyError,TypeError):pass
    try:
        receipt,_=run(a,'classify_pair',tool=b)
        pair=receipt['pair']
        if pair.get('classification') not in ['SEPARATED','TOUCHING','OVERLAPPING','INVALID','INCONCLUSIVE']:raise ValueError('Unknown native pair classification')
    except Exception as error:
        return dict(classification='INCONCLUSIVE',diagnostic='Native pair failed: '+str(error),cache_hit=False,native_calls=1,seconds=time.monotonic()-started,cache_key=key)
    if use_cache and pair['classification'] in ['SEPARATED','TOUCHING','OVERLAPPING']:
        parent.mkdir(parents=True,exist_ok=True)
        if sum(1 for _ in parent.glob('*.json'))<512:
            temporary=parent/(key+'.'+uuid.uuid4().hex+'.tmp')
            temporary.write_text(json.dumps(dict(identity=identity,receipt=receipt,receipt_sha256=hashlib.sha256(json.dumps(receipt,sort_keys=True).encode()).hexdigest())))
            temporary.replace(path)
    return dict(pair,cache_hit=False,native_calls=1,seconds=time.monotonic()-started,cache_key=key,receipt=receipt)

def inspect_assembly(parts):
    geometry=[];pairs=[]
    for part in parts:
        try:geometry.append(instance_brep(part))
        except Exception as error:raise ValueError('INVALID/INCONCLUSIVE instance '+str(part.get('name'))+' ['+str(part.get('instance_uuid',part['id']))+']: '+str(error)) from error
    for i,a in enumerate(parts):
        for j in range(i+1,len(parts)):
            b=parts[j]
            revisions=[[p.get('geometry_revision',0),p.get('transformation_revision',0)] for p in [a,b]]
            pair=classify(geometry[i],geometry[j],revisions)
            pair['instances']=[dict(id=p['id'],uuid=p.get('instance_uuid',p['id']),name=p.get('name',p['id'])) for p in [a,b]]
            pairs.append(pair)
            if pair['classification'] not in ['SEPARATED','TOUCHING']:
                raise ValueError(pair['classification']+': '+str(pair['instances'])+'; '+pair['diagnostic']+'; inspect geometry, separate bodies, or repair inputs and retry')
    return dict(schema=1,algorithm=VERSION,pairs=pairs,geometry_parts=[{key:p.get(key) for key in ['id','instance_uuid','definition_uuid','geometry_revision','transformation_revision','kind','dimensions','position','rotation','scale','cad_sha256']} for p in parts],native_calls=sum(p['native_calls'] for p in pairs),cache_hits=sum(p['cache_hit'] for p in pairs))
