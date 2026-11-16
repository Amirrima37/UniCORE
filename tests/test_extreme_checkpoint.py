import subprocess,json
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'.tools/extreme-checkpoint';out.mkdir(exist_ok=True)
job=out/'model.ucjob';job.write_text('''UNICORE_JOB 1 transient_thermal
4 1
0 0 0
1 0 0
0 1 0
0 0 1
4 0 1 2 3 1000000 0 1000
0 0
0 0
0 0
0 0
4
0 2 1 0 0 0 0.8 300
0 1 3 0 0 0 0.8 300
1 2 3 0 0 0 0.8 300
2 0 3 0 0 0 0.8 300
0.01 3 600
''')
exe=root/'bin/unicore_solver.exe'
def run(directory,*args):return subprocess.run([str(exe),'--job',str(job),'--output',str(out/directory),'--threads','2',*args],capture_output=True,text=True,timeout=30)
assert run('reference').returncode==0
(out/'resumed').mkdir(exist_ok=True);(out/'resumed/cancel.request').unlink(missing_ok=True)
paused=run('resumed','--pause-after','1');assert paused.returncode==3,paused.stderr
checkpoint=out/'resumed/checkpoint.ucstate'
resumed=run('resumed','--restart',str(checkpoint));assert resumed.returncode==0,resumed.stderr
reference=json.loads((out/'reference/results.json').read_text());actual=json.loads((out/'resumed/results.json').read_text());error=max(abs(a-b) for a,b in zip(reference['temperature'],actual['temperature']));assert error<1e-7
job.write_text(job.read_text()+'\n')
assert run('incompatible','--restart',str(checkpoint)).returncode==2
(root/'docs/extreme-mode/restart.json').write_text(json.dumps({'temperature_difference':error,'restart_initial_time_s':actual['times'][0],'pause_exit':3,'restart_exit':0,'incompatible_checkpoint_exit':2},indent=2))
print('Checkpoint, restart and incompatible-model rejection PASS')
