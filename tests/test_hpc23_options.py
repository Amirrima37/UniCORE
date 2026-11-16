"""Standalone solver option validation, job trailer precedence and advanced checkpoint coverage."""
import json,subprocess,time
from pathlib import Path
root=Path(__file__).resolve().parents[1];folder=root/'.tools/hpc23-options';folder.mkdir(exist_ok=True)
exe=root/'bin/unicore_solver.exe';base=(root/'docs/extreme-mode/examples/tet.ucjob').read_text();rows=[]
def run(name,extra=(),text=base):
 job=folder/(name+'.ucjob');job.write_text(text);out=folder/name
 p=subprocess.run([str(exe),'--job',str(job),'--output',str(out),'--threads','1',*extra],capture_output=True,text=True,timeout=60)
 rows.append(dict(name=name,exit_code=p.returncode,error=p.stderr.strip()))
 return p,out
ref=None
for method in ['jacobi','block-jacobi','ic0','auto']:
 p,out=run(method,['--preconditioner',method]);assert p.returncode==0,p.stderr
 d=json.loads((out/'results.json').read_text())
 if ref is None:ref=d['displacement_flat']
 assert d['displacement_flat']==ref
 assert d['selected_preconditioner']==('jacobi' if method=='auto' else method)
for name,extra in [('method',['--preconditioner','invalid']),('limit',['--max-iterations','0']),('negative',['--relative-tolerance','-1']),('nan',['--absolute-tolerance','nan']),('zeros',['--relative-tolerance','0','--absolute-tolerance','0']),('suffix',['--relative-tolerance','1e-8suffix'])]:
 p,_=run('invalid-'+name,extra);assert p.returncode==2,(name,p.stderr)
p,out=run('trailer',text=base+'\nSOLVER ic0 123 1e-9 1e-11\n');assert p.returncode==0,p.stderr
config=json.loads((out/'configuration.json').read_text());assert config['preconditioner']=='ic0' and config['max_iterations']==123 and config['pcg_absolute_tolerance']==1e-11
p,out=run('override',['--preconditioner','jacobi','--max-iterations','456'],text=base+'\nSOLVER ic0 123 1e-9 1e-11\n');assert p.returncode==0,p.stderr
config=json.loads((out/'configuration.json').read_text());assert config['preconditioner']=='jacobi' and config['max_iterations']==456
p,_=run('bad-trailer',text=base+'\nSOLVER ic0 5\n');assert p.returncode==2
# Reuse the full checkpoint/rejection assertions, with independent files and each advanced method.
source=(root/'tests/test_extreme_checkpoint.py').read_text()
for method in ['ic0','block-jacobi']:
 s=source.replace("'2',*args]", "'2','--preconditioner','"+method+"',*args]")
 s=s.replace('.tools/extreme-checkpoint','.tools/hpc23-checkpoint-'+method).replace('docs/extreme-mode/restart.json','docs/hpc-optimization/hpc23-checkpoint-'+method+'.json')
 exec(compile(s,str(root/'tests/test_extreme_checkpoint.py'),'exec'),{'__file__':str(root/'tests/test_extreme_checkpoint.py'),'__name__':'__main__'})
(root/'docs/hpc-optimization/hpc23-options-validation.json').write_text(json.dumps(rows,indent=2))
print('Solver CLI/job options, override precedence, invalid options, advanced checkpoint/restart PASS')


# Cancellation must work while text input is still being parsed, before the monitor starts.
job=root/'.tools/hpc23-bench/contrast-conduction-16.ucjob';out=folder/'parsing-cancel';out.mkdir(exist_ok=True)
(out/'cancel.request').unlink(missing_ok=True)
p=subprocess.Popen([str(exe),'--job',str(job),'--output',str(out),'--threads','1'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
time.sleep(.05);start=time.perf_counter();(out/'cancel.request').touch()
try:stdout,stderr=p.communicate(timeout=2)
except subprocess.TimeoutExpired:p.kill();p.communicate();raise
assert p.returncode==3,(p.returncode,stderr)
(root/'docs/hpc-optimization/hpc23-cancellation.json').write_text(json.dumps(dict(exit_code=p.returncode,cancel_latency_s=time.perf_counter()-start,status=json.loads((out/'status.json').read_text())),indent=2))
print('Input parsing cancellation PASS')
