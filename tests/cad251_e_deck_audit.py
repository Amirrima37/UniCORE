"""Independent audit of actual accepted INP/DAT bytes, including ownership."""
import json,math
from pathlib import Path
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def norm(a):return math.sqrt(sum(x*x for x in a))
def audit(job,expected_bodies=None):
    job=Path(job);receipt=json.loads((job/'receipt.json').read_text())
    assert receipt['state']=='completed' and receipt['exit_code']==0 and receipt['job_object']
    assert 'Job finished' in (job/'stdout.txt').read_text(errors='replace')
    nodes={};cells={};sets={};sections={};fixed=set();loads=[];mode='';params={};order=None;generate=False
    for line in (job/'model.inp').read_text().splitlines():
        if not line.strip() or line.startswith('**'):continue
        if line.startswith('*'):
            mode=line.split(',')[0].upper();params=dict(v.strip().upper().split('=',1) for v in line.split(',')[1:] if '=' in v)
            generate='GENERATE' in [v.strip().upper() for v in line.split(',')[1:]]
            assert mode not in ['*TIE','*EQUATION','*MPC','*SPRING','*SPRING1','*SPRING2','*CONTACT PAIR','*SURFACE INTERACTION','*COUPLING']
            if mode=='*ELEMENT':
                assert params['TYPE'] in ['C3D4','C3D10'];order=1 if params['TYPE']=='C3D4' else 2
            if mode=='*SOLID SECTION':sections[params['ELSET']]=params['MATERIAL']
            continue
        f=[x.strip() for x in line.split(',') if x.strip()]
        if mode=='*NODE':
            n=int(f[0]);assert n not in nodes;nodes[n]=list(map(float,f[1:]))
        elif mode=='*ELEMENT':
            n=int(f[0]);assert n not in cells;cells[n]=list(map(int,f[1:]));assert len(cells[n])==(4 if order==1 else 10)
            if 'ELSET' in params:sets.setdefault(params['ELSET'],[]).append(n)
        elif mode=='*ELSET':sets.setdefault(params['ELSET'],[]).extend(range(int(f[0]),int(f[1])+1,int(f[2])) if generate else map(int,f))
        elif mode=='*BOUNDARY':fixed.add(int(f[0]))
        elif mode=='*CLOAD':loads.append((int(f[0]),int(f[1])-1,float(f[2])))
    assert nodes and cells and sections
    if expected_bodies is not None:assert len(sections)==expected_bodies
    owners=[];covered=set();owned_nodes=set()
    for region in sections:
        ids=set(sets[region]);assert not covered&ids;covered|=ids
        own={n for e in ids for n in cells[e]};assert not own&owned_nodes;owned_nodes|=own;owners.append(own)
    assert covered==set(cells) and owned_nodes==set(nodes)
    u={};rf={};field=None
    for line in (job/'model.dat').read_text().splitlines():
        if 'displacements (' in line:field=u;continue
        if 'forces (' in line:field=rf;continue
        if 'stresses (' in line:field=None
        if field is None:continue
        values=line.split()
        if len(values)==4 and values[0].isdigit():field[int(values[0])]=[float(x.replace('D','E')) for x in values[1:]]
    assert set(u)==set(nodes) and set(rf)==set(nodes)
    totals=[]
    for own in owners:
        force=[0.,0.,0.];moment=[0.,0.,0.];reaction=[0.,0.,0.];reaction_moment=[0.,0.,0.];loaded=set()
        for n,axis,value in loads:
            if n not in own:continue
            loaded.add(n);force[axis]+=value;f=[0.,0.,0.];f[axis]=value;m=cross(nodes[n],f)
            moment=[a+b for a,b in zip(moment,m)]
        for n in own&fixed:
            reaction=[a+b for a,b in zip(reaction,rf[n])];m=cross(nodes[n],rf[n]);reaction_moment=[a+b for a,b in zip(reaction_moment,m)]
        imbalance=norm([a+b for a,b in zip(force,reaction)])/max(1000.,norm(force))
        moment_error=norm([a+b for a,b in zip(moment,reaction_moment)])/max(1000.,norm(moment))
        assert imbalance<1e-5 and moment_error<1e-5,(job,imbalance,moment_error)
        mean=[sum(u[n][i] for n in loaded)/len(loaded) for i in range(3)] if loaded else [0.,0.,0.]
        totals.append(dict(nodes=len(own),global_force_N=force,global_moment_Nm=moment,reaction_N=reaction,reaction_moment_Nm=reaction_moment,mean_loaded_displacement_m=mean,reaction_relative_error=imbalance,moment_relative_error=moment_error))
    return dict(job=str(job),order=order,bodies=len(owners),nodes=len(nodes),elements=len(cells),independent_node_ownership=True,no_coupling=True,totals=totals)
