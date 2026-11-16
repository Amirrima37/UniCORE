"""Plane strain reference using actual Stage 6 pipe meshes; test-only native jobs.
All axial DOFs vanish, with in-plane symmetry constraints at x=0 and z=0.
End faces have no in-plane tractions; no clamped-end boundary layer is present.
Accuracy criterion fixed before execution: displacement and stress RMS errors must
decrease at densities 1,2,4. No absolute continuum accuracy threshold is claimed.
"""
import json, math, subprocess, time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'docs/workbench-2/stage6-final/lame';out.mkdir(exist_ok=True)
jobs=root/'.tools/cae-appdata/Godot/app_userdata/UniCORE/extreme_jobs'
fixtures={}
for p in sorted(jobs.glob('*/project.json')):
    d=json.loads(p.read_text());parts=d.get('parts',[]);mesh=d.get('mesh',{})
    if len(parts)!=1 or parts[0].get('kind')!='Pipe':continue
    if len(mesh.get('nodes',[])) not in [96,480,2880]:continue
    fixtures[mesh['divisions']]=(p,d)
rows=[]
def sub(a,b):return [x-y for x,y in zip(a,b)]
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
previous=[float('inf')]*3
for density in [1,2,4]:
    path,d=fixtures[density];part=d['parts'][0];mesh=d['mesh']
    rot=part.get('rotation',[0,0,0]);position=part['position']
    def local(v):
        x,y,z=sub(v,position)
        a=x*math.cos(rot[1])-z*math.sin(rot[1]);c=x*math.sin(rot[1])+z*math.cos(rot[1])
        b=y*math.cos(rot[0])+c*math.sin(rot[0]);zz=-y*math.sin(rot[0])+c*math.cos(rot[0])
        return [a*math.cos(rot[2])+b*math.sin(rot[2]),-a*math.sin(rot[2])+b*math.cos(rot[2]),zz]
    nodes=list(map(local,mesh['nodes']));cells=mesh['elements']
    assert abs(max(v[1] for v in nodes)-min(v[1] for v in nodes)-0.1)<1e-10
    forces=[[0.,0.,0.] for _ in nodes]
    for face in mesh['surface_regions'][part['id']]['InnerWall']:
        a,b,c=[nodes[i] for i in face];normal=cross(sub(b,a),sub(c,a))
        for i in face:
            for j in range(3):forces[i][j]-=normal[j]/6 # p=1, area vector=cross/2, three nodes
    tokens=['UNICORE_JOB 1 static_structural',f'{len(nodes)} {len(cells)}']
    tokens+=[' '.join(map(repr,v)) for v in nodes]
    tokens+=['4 '+' '.join(map(str,cell))+' 1000 0.25' for cell in cells]
    for v,f in zip(nodes,forces):
        for j in range(3):tokens.append(f'{f[j]:.17g} {int(j==1 or abs(v[j])<1e-12)} 0')
    job=out/f'density-{density}.ucjob';job.write_text('\n'.join(tokens))
    dest=out/f'density-{density}'
    cmd=[str(root/'bin/unicore_solver.exe'),'--job',str(job),'--output',str(dest),'--threads','1','--memory-mb','256']
    start=time.perf_counter();p=subprocess.run(cmd,capture_output=True,timeout=30)
    (out/f'density-{density}.log').write_bytes(p.stdout+p.stderr)
    row=dict(density=density,source_snapshot=str(path),command=cmd,exit_code=p.returncode,seconds=time.perf_counter()-start)
    rows.append(row);(out/'results.json').write_text(json.dumps(rows,indent=2))
    assert p.returncode==0,p.stderr
    r=json.loads((dest/'results.json').read_text())
    assert r['ok'] and r['relative_residual']<1e-8
    # a=.05, b=.1, pi=1, po=0; stress A +/- B/r^2.
    A=.05**2/(.1**2-.05**2);B=.05**2*.1**2/(.1**2-.05**2)
    ue=un=0.
    for i,(x,y,z) in enumerate(nodes):
        radius=math.hypot(x,z);ur=1.25/1000*(.5*A*radius+B/radius)
        exact=[ur*x/radius,0,ur*z/radius]
        for j in range(3):
            value=r['displacement_flat'][3*i+j];assert math.isfinite(value)
            ue+=(value-exact[j])**2;un+=exact[j]**2
    se=[0.,0.];sn=[0.,0.]
    for cell,s in zip(cells,r['stress']):
        points=[nodes[i] for i in cell];x,y,z=[sum(v[j] for v in points)/4 for j in range(3)]
        radius=math.hypot(x,z);nx,nz=x/radius,z/radius
        volume=abs(dot(sub(points[1],points[0]),cross(sub(points[2],points[0]),sub(points[3],points[0]))))/6
        actual=[nx*nx*s[0]+nz*nz*s[2]+2*nx*nz*s[5],nz*nz*s[0]+nx*nx*s[2]-2*nx*nz*s[5]]
        for j,exact in enumerate([A-B/radius**2,A+B/radius**2]):
            assert math.isfinite(actual[j]);se[j]+=(actual[j]-exact)**2*volume;sn[j]+=exact**2*volume
    errors=[math.sqrt(ue/un),*[math.sqrt(a/b) for a,b in zip(se,sn)]]
    row.update(nodal_displacement_relative_rms=errors[0],radial_stress_centroid_relative_rms=errors[1],hoop_stress_centroid_relative_rms=errors[2],residual=r['relative_residual'],nodes=len(nodes),tets=len(cells))
    (out/'results.json').write_text(json.dumps(rows,indent=2))
    assert all(a<b for a,b in zip(errors,previous)),(errors,previous)
    previous=errors
print('Plane strain Lame displacement/radial stress/hoop stress refinement PASS')
