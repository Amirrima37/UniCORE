"""Audit actual placement decks and original seven binary pins."""
import os,json,hashlib,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=Path(os.environ['UNICORE_PLACEMENT_OUT'])
rows=json.loads((OUT/'solves.json').read_text())
if (OUT/'solves-step.json').exists():rows+=json.loads((OUT/'solves-step.json').read_text())
audits=[]
for job in sorted({r['job'] for r in rows}):
    case=next(r['case'] for r in rows if r['job']==job)
    nodes={};elements={};loads=[];mode='';element_type='';types=set();sets={};sections={};materials=set();params={}
    for line in (Path(job)/'model.inp').read_text().splitlines():
        if line.startswith('**') or not line.strip():continue
        if line.startswith('*'):
            mode=line.split(',')[0].upper();params=dict(t.strip().upper().split('=',1) for t in line.split(',')[1:] if '=' in t)
            if mode=='*MATERIAL':materials.add(params['NAME'])
            if mode=='*SOLID SECTION':sections[params['ELSET']]=params['MATERIAL']
            assert mode not in ['*TIE','*EQUATION','*MPC','*SPRING','*CONTACT PAIR']
            if mode=='*ELEMENT':element_type=line.upper().split('TYPE=')[1].split(',')[0];types.add(element_type)
            continue
        f=[x.strip() for x in line.split(',') if x.strip()]
        if mode=='*NODE':
            n=int(f[0]);assert n not in nodes;nodes[n]=list(map(float,f[1:]))
        if mode=='*ELEMENT':
            n=int(f[0]);assert n not in elements;elements[n]=list(map(int,f[1:]));assert len(elements[n])==(10 if element_type=='C3D10' else 4)
        if mode=='*ELSET':sets.setdefault(params['ELSET'],[]).extend(map(int,f))
        if mode=='*CLOAD':loads.append((int(f[0]),int(f[1])-1,float(f[2])))
    assert len(sections)==2 and all(m in materials for m in sections.values())
    covered=set()
    for region in sections:
        assert covered.isdisjoint(sets[region]);covered.update(sets[region])
    assert covered==set(elements)
    assembly=json.loads((OUT/(case+('2' if 'C3D10' in types else '1')+'.json')).read_text())
    mesh=assembly['mesh'] # Lossless Godot payload is intentionally decoded by Godot tests, not this audit.
    owners=[set(n for n,p in nodes.items() if p[0]<1),set(n for n,p in nodes.items() if p[0]>=1)]
    assert owners[0].isdisjoint(owners[1]) and set.union(*owners)==set(nodes)
    force=[[0.,0.,0.] for _ in owners];moment=[[0.,0.,0.] for _ in owners]
    for n,axis,value in loads:
        k=0 if n in owners[0] else 1;force[k][axis]+=value
        f=[0.,0.,0.];f[axis]=value;p=nodes[n]
        for i in range(3):moment[k][i]+=p[(i+1)%3]*f[(i+2)%3]-p[(i+2)%3]*f[(i+1)%3]
    for cell in elements.values():assert any(set(cell)<=owner for owner in owners)
    for k,part in enumerate(assembly['parts']):
        expected=part['force'];assert max(abs(a-b) for a,b in zip(force[k],expected))<1e-6
        # Applied traction resultant must pass through the transformed load-face centroid.
        import sys
        sys.path.insert(0,str(ROOT/'scripts/engines'))
        from instance_placement import matrix,point
        c=point(matrix(part),part['cad_face_centers'][part['load_face']])
        target=[c[(i+1)%3]*expected[(i+2)%3]-c[(i+2)%3]*expected[(i+1)%3] for i in range(3)]
        assert max(abs(a-b) for a,b in zip(moment[k],target))<max(1e-6,max(abs(x) for x in target)*1e-8), str((case,k,moment[k],target,job))
    audits.append(dict(job=job,case=case,nodes=len(nodes),elements=len(elements),force=force,moment=moment,disjoint_ownership=True))
baseline=json.loads((ROOT/'docs/architecture/evidence/cad24-completion/final-receipt.json').read_text())['baseline']['hashes']
pins={}
for name,expected in baseline.items():
    if not name.endswith(('.exe','.dll')):continue
    actual=hashlib.file_digest(Path(name).open('rb'),'sha256').hexdigest()
    assert actual==expected,name;pins[name]=actual
assert len(pins)==7
(OUT/'audit.json').write_text(json.dumps(dict(decks=audits,preservation_hashes=pins),indent=2))
print('AUDIT_PASS',len(audits),'decks; seven pins unchanged')


