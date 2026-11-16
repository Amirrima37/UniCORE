"""Verify standalone fallback on structural, steady thermal and nonlinear radiation fixtures."""
import json,subprocess
from pathlib import Path
fields=['temperature','heat_flux','heat_flux_history','radiative_heat_flux','radiative_power_W','heat_reactions','history','energy_balance_W','relative_residual','iterations','nonlinear_iterations','stress','strain','displacement_flat','reactions_flat','von_mises']
rows=[]
for job in [Path('docs/extreme-mode/examples/tet.ucjob'),Path('.tools/extreme-thermal/model.ucjob'),Path('.tools/extreme-checkpoint/model.ucjob')]:
 reference=None
 for mode in ['serial','row-owned']:
  for threads in [1,4,12]:
   out=Path('.tools/hpc22-fallback')/job.parent.name/mode/str(threads)
   subprocess.run(['bin/unicore_solver.exe','--job',str(job),'--output',str(out),'--threads',str(threads),'--memory-mb','1024','--assembly',mode],check=True,timeout=180)
   d=json.loads((out/'results.json').read_text());values={k:d[k] for k in fields if k in d}
   if reference is None:reference=values
   assert values==reference,(job,mode,threads)
   rows.append(dict(job=str(job),mode=mode,threads=threads,exact=True))
Path('docs/hpc-optimization/hpc22-fallback-equivalence.json').write_text(json.dumps(rows,indent=2))
print('Structural, conduction, transient radiation fallback exact equality PASS')
