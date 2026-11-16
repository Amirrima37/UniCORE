"""Audit actual decks against native world-face evidence, without exporter code."""
import json,math,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=Path(os.environ.get('UNICORE_FACE_OUT') or (ROOT/'face-identity-attempt.txt').read_text().strip())
rows=sum([json.loads((OUT/('solves-'+c+'.json')).read_text()) for c in ['duplicate','translated','rotated','step','touching','reassigned']],[])
audits=[]
for job in sorted({r['job'] for r in rows}):
    evidence=[r for r in rows if r['job']==job];assert len(evidence)==2
    nodes={};cells={};sets={};sections={};loads=[];fixed=set();mode='';params={}
    for line in (Path(job)/'model.inp').read_text().splitlines():
        if not line.strip() or line.startswith('**'):continue
        if line.startswith('*'):
            mode=line.split(',')[0].upper();params=dict(t.strip().upper().split('=',1) for t in line.split(',')[1:] if '=' in t)
            assert mode not in ['*TIE','*EQUATION','*MPC','*SPRING','*CONTACT PAIR']
            if mode=='*SOLID SECTION':sections[params['ELSET']]=params['MATERIAL']
            if mode=='*ELEMENT':assert params['TYPE']==('C3D10' if evidence[0]['order']==2 else 'C3D4')
            continue
        f=[v.strip() for v in line.split(',') if v.strip()]
        if mode=='*NODE':
            n=int(f[0]);assert n not in nodes;nodes[n]=list(map(float,f[1:]))
        if mode=='*ELEMENT':
            n=int(f[0]);assert n not in cells;cells[n]=list(map(int,f[1:]));assert len(cells[n])==(10 if evidence[0]['order']==2 else 4)
        if mode=='*ELSET':sets.setdefault(params['ELSET'],[]).extend(map(int,f))
        if mode=='*BOUNDARY':fixed.add(int(f[0]))
        if mode=='*CLOAD':loads.append((int(f[0]),int(f[1])-1,float(f[2])))
    owners=[];covered=set();assert len(sections)==2
    for region in sections:
        assert covered.isdisjoint(sets[region]);covered.update(sets[region]);owners.append({n for e in sets[region] for n in cells[e]})
    assert covered==set(cells) and owners[0].isdisjoint(owners[1]) and owners[0]|owners[1]==set(nodes)
    totals=[]
    for k,row in enumerate(evidence):
        ref=row['references'];proof=row['resolution'];assert proof['instance_uuid']==row['instance']
        for r in ref.values():assert r['instance_uuid']==row['instance'] and r['definition_uuid']==row['definition']
        def face_nodes(key):
            d=proof['world_faces'][ref[key]['definition_face_id']];normal=d['plane_outward_normal'];c=d['center'];bounds=d['bounds']
            return {n for n in owners[k] if abs(sum((nodes[n][i]-c[i])*normal[i] for i in range(3)))<2e-7 and all(bounds[i]-2e-7<=nodes[n][i]<=bounds[i+3]+2e-7 for i in range(3))}
        support=face_nodes('support');loaded=face_nodes('load_face')
        assert support and loaded and fixed&owners[k]==support # Includes every TET10 midside.
        force=[0.,0.,0.];moment=[0.,0.,0.]
        for n,axis,value in loads:
            if n not in owners[k]:continue
            assert n in loaded
            force[axis]+=value;f=[0.,0.,0.];f[axis]=value;p=nodes[n]
            for i in range(3):moment[i]+=p[(i+1)%3]*f[(i+2)%3]-p[(i+2)%3]*f[(i+1)%3]
        assert max(abs(a-b) for a,b in zip(force,row['force_N']))<1e-5
        assert max(abs(a-b) for a,b in zip(moment,row['moment_Nm']))<max(1e-5,max(abs(v) for v in row['moment_Nm'])*3e-7)
        totals.append(dict(instance=row['instance'],support_face=ref['support']['definition_face_id'],load_face=ref['load_face']['definition_face_id'],support_nodes=len(support),load_nodes=len(loaded),force_N=force,moment_Nm=moment,correct_plane_membership=True))
    coincident=len({tuple(nodes[n]) for n in owners[0]}&{tuple(nodes[n]) for n in owners[1]})
    if evidence[0]['case']=='touching':assert coincident>0
    audits.append(dict(job=job,case=evidence[0]['case'],order=evidence[0]['order'],nodes=len(nodes),elements=len(cells),coincident_unwelded_coordinates=coincident,totals=totals,no_coupling=True))
(OUT/'deck-audit.json').write_text(json.dumps(audits,indent=2))
print('FACE_DECK_AUDIT_PASS',len(audits))
