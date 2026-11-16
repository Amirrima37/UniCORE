import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Independent audit of actual exported CalculiX NODE/CLOAD cards."""
import json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad24-completion')
USER=godot_environment_root()/'roaming/Godot/app_userdata/UniCORE'
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
rows=[]
for result in json.loads((OUT/'structural-numerical.json').read_text()):
    job=Path(result['solver_job'].replace('user://',str(USER)+'/'));nodes={};loads=[];mode=''
    for line in (job/'model.inp').read_text().splitlines():
        line=line.strip()
        if not line or line.startswith('**'):continue
        if line.startswith('*'):
            key=line.split(',')[0].upper();mode=key if key in ['*NODE','*CLOAD'] else '';continue
        fields=[s.strip() for s in line.split(',')]
        if mode=='*NODE':nodes[int(fields[0])]=[float(x.replace('D','E')) for x in fields[1:4]]
        if mode=='*CLOAD':loads.append((int(fields[0]),int(fields[1])-1,float(fields[2].replace('D','E'))))
    force=[0.,0.,0.];moment=[0.,0.,0.]
    for node,axis,value in loads:
        f=[0.,0.,0.];f[axis]=value;force[axis]+=value;m=cross(nodes[node],f)
        moment=[a+b for a,b in zip(moment,m)]
    assert max(abs(a-b) for a,b in zip(force,[0,1000,0]))<1e-5,(result['case'],force)
    residual=math.sqrt(sum((a+b)**2 for a,b in zip(moment,result['reaction_moment_Nm'])))
    scale=max(1.,math.sqrt(sum(x*x for x in moment)),max(math.sqrt(sum(x*x for x in point)) for point in nodes.values())*1000)
    assert residual/scale<1e-5,(result['case'],moment,result['reaction_moment_Nm'])
    (job/'PINNED').touch()
    rows.append(dict(case=result['case'],order=result['order'],deck=str(job/'model.inp'),applied_force_N=force,applied_moment_Nm=moment,reaction_moment_Nm=result['reaction_moment_Nm'],relative_moment_imbalance=residual/scale,node_cards=len(nodes),load_cards=len(loads)))
(OUT/'independent-deck-audit.json').write_text(json.dumps(rows,indent=2))
assert len(rows)==6
print('CAD24_DECK_AUDIT_PASS')
