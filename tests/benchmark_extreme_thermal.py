import subprocess,time,json
from pathlib import Path
n=10;m=n+1;plane=m*m;nodes=m**3;folder=Path('.tools/extreme-thermal');folder.mkdir(exist_ok=True);job=folder/'model.ucjob';tick=time.perf_counter()
with job.open('w') as f:
 f.write(f'UNICORE_JOB 1 steady_thermal\n{nodes} {6*n**3}\n')
 for z in range(m):
  for y in range(m):
   for x in range(m):f.write(f'{x/n} {y/n} {z/n}\n')
 for z in range(n):
  for y in range(n):
   for x in range(n):
    a=x+m*y+plane*z;cell=[a,a+1,a+m+1,a+m,a+plane,a+plane+1,a+plane+m+1,a+plane+m]
    for local in [(0,1,2,6),(0,2,3,6),(0,3,7,6),(0,7,4,6),(0,4,5,6),(0,5,1,6)]:f.write('4 '+' '.join(str(cell[i]) for i in local)+' 1 0 0\n')
 for i in range(nodes):
  x=i%m;f.write(f'{int(x in [0,n])} {300+100*x/n}\n')
 f.write('0\n0 0 293.15\n')
mesh=time.perf_counter()-tick;rows=[]
for threads in [1,2,4]:
 tick=time.perf_counter();r=subprocess.run([str(Path('bin/unicore_solver.exe').resolve()),'--job',str(job),'--output',str(folder/str(threads)),'--threads',str(threads),'--memory-mb','512'],capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
 result=json.loads((folder/str(threads)/'results.json').read_text());error=max(abs(value-(300+100*(i%m)/n)) for i,value in enumerate(result['temperature']));flux=max(abs(q[0]+100) for q in result['heat_flux']);assert error<1e-6 and flux<1e-5
 rows.append({'dof':nodes,'elements':6*n**3,'threads':threads,'wall_s':time.perf_counter()-tick,'mesh_write_s':mesh,'temperature_error':error,'flux_error':flux,'assembly_ms':result['assembly_ms'],'solve_ms':result['solve_ms'],'post_ms':result['post_ms'],'peak_working_set_bytes':result['peak_working_set_bytes'],'residual':result['relative_residual'],'iterations':result['iterations']})
 print(rows[-1],flush=True)
Path('docs/extreme-mode/thermal-benchmark.json').write_text(json.dumps(rows,indent=2))
