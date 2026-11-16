import subprocess,time,json
from pathlib import Path
rows=[]
for n in [32]:
 m=n+1;plane=m*m;nodes=m**3;folder=Path('.tools/extreme-axial');folder.mkdir(exist_ok=True);job=folder/'model.ucjob'
 mesh_started=time.perf_counter()
 with job.open('w') as f:
  f.write(f'UNICORE_JOB 1 static_structural\n{nodes} {n**3}\n')
  for z in range(m):
   for y in range(m):
    for x in range(m):f.write(f'{x/n} {y/n} {z/n}\n')
  for z in range(n):
   for y in range(n):
    for x in range(n):
     a=x+m*y+plane*z;f.write('8 '+' '.join(map(str,[a,a+1,a+m+1,a+m,a+plane,a+plane+1,a+plane+m+1,a+plane+m]))+' 1000 0\n')
  for i in range(nodes):
   x=i%m;y=(i//m)%m;z=i//plane;weight=(.5 if y in [0,n] else 1)*(.5 if z in [0,n] else 1)/(n*n)
   for axis in range(3):f.write(f'{weight if x==n and axis==0 else 0} {int(x==0)} 0\n')
 mesh_generation_write_s=time.perf_counter()-mesh_started
 for threads in [1,2,4,6,8,12]*3:
  start=time.perf_counter();r=subprocess.run([str(Path('bin/unicore_solver.exe').resolve()),'--job',str(job),'--output',str(folder/str(threads)),'--threads',str(threads),'--memory-mb','1024'],capture_output=True,text=True,timeout=60);assert r.returncode==0,r.stderr
  elapsed=time.perf_counter()-start;result=json.loads((folder/str(threads)/'results.json').read_text());error=max(abs(result['displacement_flat'][3*i]-.001*(i%m)/n) for i in range(nodes));assert error<1e-8,error
  rows.append({'dof':nodes*3,'elements':n**3,'threads':threads,'wall_s':elapsed,'maximum_axial_displacement_error':error,'iterations':result['iterations'],'residual':result['relative_residual'],'peak_working_set_bytes':result['peak_working_set_bytes'],'preparation_ms':result['preparation_ms'],'mesh_generation_write_s':mesh_generation_write_s,'assembly_ms':result['assembly_ms'],'solve_ms':result['solve_ms'],'post_ms':result['post_ms']})
  print(rows[-1],flush=True)
Path(__import__('sys').argv[1]).write_text(json.dumps(rows,indent=2))
