import json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1];folder=root/'.tools/hpc21-equivalence';folder.mkdir(exist_ok=True)
rows=[]
fixtures=[root/'.tools/extreme-thermal/model.ucjob',root/'.tools/extreme-checkpoint/model.ucjob']
fields=['temperature','heat_flux','heat_flux_history','radiative_heat_flux','radiative_power_W','heat_reactions','history','energy_balance_W','relative_residual','iterations','nonlinear_iterations','stress','strain','displacement_flat','reactions_flat']
def difference(a,b):
 if isinstance(a,list):
  assert len(a)==len(b)
  return max((difference(x,y) for x,y in zip(a,b)),default=0)
 return abs(a-b)
for job in fixtures:
 reference=None
 for exe,threads in [(root/'.tools/unicore_solver_hpc21_baseline.exe',1)]+[(root/'bin/unicore_solver.exe',t) for t in [1,2,4,6,8,12]]:
  output=folder/(job.parent.name+'-'+exe.stem+'-'+str(threads))
  result=subprocess.run([str(exe),'--job',str(job),'--output',str(output),'--threads',str(threads),'--memory-mb','1024'],capture_output=True,timeout=120)
  assert result.returncode==0,result.stderr
  data=json.loads((output/'results.json').read_text())
  if reference is None:reference=data
  errors={k:difference(reference[k],data[k]) for k in fields if k in reference}
  assert all(v==0 for v in errors.values()),errors
  rows.append({'fixture':str(job.relative_to(root)),'executable':exe.name,'threads':threads,'maximum_differences':errors})
Path('docs/hpc-optimization/hpc21-thermal-equivalence.json').write_text(json.dumps(rows,indent=2))
print('Steady conduction and transient radiation: exact field equality to old executable at 1/2/4/6/8/12 threads PASS')
