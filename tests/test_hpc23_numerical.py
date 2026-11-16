"""Check actual FEM benchmark fields, not only iteration counts; smoke all standalone builds."""
import json,subprocess
from pathlib import Path
folder=Path('.tools/hpc23-bench');rows=[]
for workload in ['elastic-8','elastic-16','slender-bending','heterogeneous-elastic','contrast-conduction-8','contrast-conduction-16']:
 if workload.startswith('contrast'):
  # Default global residual normalization is dominated by the high-k Dirichlet RHS.
  # Preserve default results; use explicitly tighter tolerances for flux-equivalence validation.
  for method in ['jacobi','block-jacobi','ic0','auto']:
   tight=Path('.tools/hpc23-tight')/workload/method
   p=subprocess.run(['bin/unicore_solver.exe','--job',str(folder/(workload+'.ucjob')),'--output',str(tight),'--threads','1','--preconditioner',method,'--relative-tolerance','1e-13','--absolute-tolerance','1e-13'],capture_output=True,text=True,timeout=10)
   assert p.returncode==0,p.stderr
  source=Path('.tools/hpc23-tight')/workload
 else:source=folder/workload
 reference=json.loads(((source/'jacobi/results.json') if workload.startswith('contrast') else (source/'jacobi-0/results.json')).read_text())
 for method in ['jacobi','block-jacobi','ic0','auto']:
  d=json.loads(((source/method/'results.json') if workload.startswith('contrast') else (source/(method+'-0')/'results.json')).read_text());errors={}
  for key in ['displacement_flat','reactions_flat','stress','strain','von_mises','temperature','heat_flux','heat_reactions']:
   if key not in reference:continue
   def flat(v):
    for x in v:
     if isinstance(x,list):yield from flat(x)
     else:yield x
   a=list(flat(reference[key]));b=list(flat(d[key]));assert len(a)==len(b)
   delta=max((abs(x-y) for x,y in zip(a,b)),default=0);scale=max(map(abs,a),default=0)
   assert delta<=1e-4*scale+1e-6,(workload,method,key,delta,scale)
   errors[key]=delta
  assert d['relative_residual']<=1e-7
  rows.append(dict(workload=workload,method=method,relative_tolerance=1e-13 if workload.startswith('contrast') else 1e-10,maximum_field_differences=errors))
for exe in ['unicore_solver.exe','unicore_solver_debug.exe','unicore_solver_noomp.exe']:
 for method in ['jacobi','block-jacobi','ic0','auto']:
  out=Path('.tools/hpc23-configs')/exe/method
  p=subprocess.run([str(Path('bin')/exe),'--job',str(folder/'elastic-8.ucjob'),'--output',str(out),'--threads','1','--preconditioner',method],capture_output=True,text=True,timeout=180);assert p.returncode==0,p.stderr
  d=json.loads((out/'results.json').read_text());values=d['displacement_flat'];error=max(abs(values[3*i]-.001*(i%9)/8) for i in range(len(values)//3));assert error<1e-8,(exe,method,error)
  rows.append(dict(executable=exe,method=method,analytic_max_error=error))
Path('docs/hpc-optimization/hpc23-numerical-validation.json').write_text(json.dumps(rows,indent=2))
print('FEM advanced-preconditioner displacement/stress/strain/reaction/temperature/flux agreement and release/debug/no-OpenMP manufactured fields PASS')
