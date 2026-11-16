"""Independent audit of actual solver decks; never imports the exporter."""
import json,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from instance_placement import matrix,point
OUT=Path((ROOT/'interference-attempt.txt').read_text())
rows=sum([json.loads((OUT/('solves-'+case+'.json')).read_text()) for case in ['rotated-disjoint','touching','step']],[])
audits=[]
for job in sorted({r['job'] for r in rows}):
    row=next(r for r in rows if r['job']==job);case=row['case'];order=row['order']
    study=json.loads((OUT/(case+str(order)+'.json')).read_text())
    nodes={};elements={};sets={};sections={};loads=[];mode='';params={};materials=set()
    for line in (Path(job)/'model.inp').read_text().splitlines():
        if not line.strip() or line.startswith('**'):continue
        if line.startswith('*'):
            mode=line.split(',')[0].upper();params=dict(t.strip().upper().split('=',1) for t in line.split(',')[1:] if '=' in t)
            assert mode not in ['*TIE','*EQUATION','*MPC','*SPRING','*CONTACT PAIR']
            if mode=='*SOLID SECTION':sections[params['ELSET']]=params['MATERIAL']
            if mode=='*MATERIAL':materials.add(params['NAME'])
            if mode=='*ELEMENT':assert params['TYPE']==('C3D10' if order==2 else 'C3D4')
            continue
        f=[x.strip() for x in line.split(',') if x.strip()]
        if mode=='*NODE':
            n=int(f[0]);assert n not in nodes;nodes[n]=list(map(float,f[1:]))
        if mode=='*ELEMENT':
            n=int(f[0]);assert n not in elements;elements[n]=list(map(int,f[1:]));assert len(elements[n])==(10 if order==2 else 4)
        if mode=='*ELSET':sets.setdefault(params['ELSET'],[]).extend(map(int,f))
        if mode=='*CLOAD':loads.append((int(f[0]),int(f[1])-1,float(f[2])))
    assert len(sections)==2 and len(materials)==2
    covered=set();owners=[]
    for region,material in sections.items():
        assert material in materials and covered.isdisjoint(sets[region]);covered.update(sets[region])
        owners.append({n for e in sets[region] for n in elements[e]})
    assert covered==set(elements) and owners[0].isdisjoint(owners[1]) and owners[0]|owners[1]==set(nodes)
    totals=[]
    for k,part in enumerate(study['parts']):
        force=[0.,0.,0.];moment=[0.,0.,0.]
        for n,axis,value in loads:
            if n not in owners[k]:continue
            force[axis]+=value;f=[0.,0.,0.];f[axis]=value;p=nodes[n]
            for i in range(3):moment[i]+=p[(i+1)%3]*f[(i+2)%3]-p[(i+2)%3]*f[(i+1)%3]
        expected=part['force'];assert max(abs(a-b) for a,b in zip(force,expected))<1e-5
        c=point(matrix(part),part['cad_face_centers'][part['load_face']])
        target=[c[(i+1)%3]*expected[(i+2)%3]-c[(i+2)%3]*expected[(i+1)%3] for i in range(3)]
        assert max(abs(a-b) for a,b in zip(moment,target))<max(1e-6,max(abs(v) for v in target)*2e-7),str((case,order,k,moment,target,job))
        totals.append(dict(force_N=force,moment_Nm=moment))
    coincident=len({tuple(nodes[n]) for n in owners[0]}&{tuple(nodes[n]) for n in owners[1]})
    if case=='touching':assert coincident>0 # Separate IDs at identical interface coordinates.
    audits.append(dict(job=job,case=case,order=order,nodes=len(nodes),elements=len(elements),coincident_unwelded_coordinates=coincident,totals=totals,disjoint_node_ownership=True,no_coupling=True))
(OUT/'deck-audit.json').write_text(json.dumps(audits,indent=2))
print('INTERFERENCE_DECK_AUDIT_PASS',len(audits))

