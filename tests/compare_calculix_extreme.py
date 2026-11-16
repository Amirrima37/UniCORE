"""Identical actual Workbench Gmsh mesh and consistent surface nodal forces."""
import json, math, subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=root/'docs/architecture/evidence/calculix/extreme-comparison';base.mkdir(exist_ok=True)
rows=[]
for kind in ['Box','Cylinder']:
    data=json.loads((base.parent/'workbench'/f'{kind}.json').read_text())
    mesh=data['mesh'];p=data['parts'][0];reference=data['results']
    n=len(mesh['nodes']);forces=[[0.]*3 for _ in range(n)];weights={};total=0
    for tri in mesh['surface_regions'][p['id']][p['load_face']]:
        a,b,c=[mesh['nodes'][int(i)] for i in tri]
        u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
        area=math.sqrt(sum((u[(i+1)%3]*v[(i+2)%3]-u[(i+2)%3]*v[(i+1)%3])**2 for i in range(3)))/2
        total+=area
        for i in tri:weights[int(i)]=weights.get(int(i),0)+area/3
    for i,w in weights.items():forces[i]=[f*w/total for f in p['force']]
    fixed=set(map(int,mesh['groups'][p['id']][p['support']]))
    job=base/f'{kind}.ucjob'
    with job.open('w') as f:
        f.write(f'UNICORE_JOB 1 static_structural\n{n} {len(mesh["elements"])}\n')
        for node in mesh['nodes']:f.write(' '.join(map(str,node))+'\n')
        for cell in mesh['elements']:f.write('4 '+' '.join(str(int(i)) for i in cell)+f' {p["material"]["E"]} {p["material"]["nu"]}\n')
        for i in range(n):
            for axis in range(3):f.write(f'{forces[i][axis]:.17g} {int(i in fixed)} 0\n')
    out=base/kind
    result=subprocess.run([str(root/'bin/unicore_solver.exe'),'--job',str(job),'--output',str(out),'--threads','1','--memory-mb','1024'],capture_output=True,timeout=120)
    (base/f'{kind}.stdout.txt').write_bytes(result.stdout);(base/f'{kind}.stderr.txt').write_bytes(result.stderr)
    assert result.returncode==0,result.stderr
    r=json.loads((out/'results.json').read_text())
    expected=[v for u in reference['displacement'] for v in u]
    relative=math.sqrt(sum((a-b)**2 for a,b in zip(expected,r['displacement_flat']))/sum(a*a for a in expected))
    # Extreme tensor order xx yy zz xy yz xz; CalculiX xx yy zz xy xz yz.
    stress_error=math.sqrt(sum((s[i]-t[j])**2 for s,t in zip(reference['stress'],r['stress']) for i,j in enumerate([0,1,2,3,5,4]))/sum(v*v for s in reference['stress'] for v in s))
    load_norm=math.sqrt(sum(f*f for f in p['force']))
    balance=math.sqrt(sum((sum(v[axis] for v in reference['reactions'])+p['force'][axis])**2 for axis in range(3)))/load_norm
    assert balance<1e-5,balance
    rows.append(dict(kind=kind,exit_code=result.returncode,displacement_relative_l2=relative,stress_relative_l2=stress_error,calculix_reaction_balance_relative=balance,extreme_residual=r['relative_residual']))
    assert relative<1e-4 and stress_error<1e-4,rows[-1]
(base/'results.json').write_text(json.dumps(rows,indent=2))
print('CALCULIX_EXTREME_COMPARISON',json.dumps(rows))
