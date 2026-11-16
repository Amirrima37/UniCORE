import subprocess,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
jobs=[root/'docs/extreme-mode/examples/tet.ucjob',root/'.tools/extreme-checkpoint/model.ucjob'];rows=[]
for index,job in enumerate(jobs):
 values=[]
 for executable in ['unicore_solver.exe','unicore_solver_debug.exe']:
  output=root/'.tools/extreme-config'/str(index)/executable
  r=subprocess.run([str(root/'bin'/executable),'--job',str(job),'--output',str(output),'--threads','2','--memory-mb','256'],capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
  result=json.loads((output/'results.json').read_text());values.append(result)
 key='displacement_flat' if index==0 else 'temperature';error=max(abs(a-b) for a,b in zip(values[0][key],values[1][key]));assert error<(1e-12 if index==0 else 1e-7)
 rows.append({'analysis':values[0]['analysis_type'],'maximum_debug_release_difference':error,'release_residual':values[0]['relative_residual'],'debug_residual':values[1]['relative_residual']})
(root/'docs/extreme-mode/configurations.json').write_text(json.dumps(rows,indent=2));print('Debug/release standalone structural and nonlinear thermal execution PASS')
