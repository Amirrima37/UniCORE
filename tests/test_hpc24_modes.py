import json,subprocess,time
from pathlib import Path
root=Path.cwd();rows=[]
for exe in ['hpc23_structural_solver_test','hpc23_hex8_test','hpc23_thermal_radiation_test','hpc23_sparse_preconditioner_test_release','hpc23_sparse_preconditioner_test_debug','hpc23_sparse_preconditioner_test_noomp','hpc23_parallel_assembly_test_release','hpc23_parallel_assembly_test_debug','hpc23_parallel_assembly_test_noomp']:
 p=subprocess.run([str(root/'.tools'/(exe+'.exe'))],capture_output=True,text=True,timeout=10);rows.append(dict(test=exe,exit=p.returncode,stdout=p.stdout,stderr=p.stderr));assert p.returncode==0,rows[-1]
for fixture in ['docs/extreme-mode/examples/tet.ucjob','.tools/hpc24-checkpoint/model.ucjob']:
 # Checkpoint helper appends whitespace only; model remains valid.
 ref=None
 for exe in ['unicore_solver.exe','unicore_solver_debug.exe','unicore_solver_noomp.exe']:
  for assembly in ['serial','row-owned']:
   out=root/'.tools/hpc24-modes'/Path(fixture).stem/exe/assembly
   p=subprocess.run([str(root/'bin'/exe),'--job',fixture,'--output',str(out),'--threads','1','--assembly',assembly],capture_output=True,text=True,timeout=10);assert p.returncode==0,p.stderr
   d=json.loads((out/'results.json').read_text());fields={k:v for k,v in d.items() if k in ['displacement_flat','stress','strain','temperature','heat_flux','history','heat_reactions']}
   if ref is None:ref=fields
   assert fields==ref
   rows.append(dict(fixture=fixture,exe=exe,assembly=assembly,exact_fields=True))
Path('docs/hpc-optimization/hpc24-regression.json').write_text(json.dumps(rows,indent=2));print('Native and standalone build/assembly regressions PASS')
