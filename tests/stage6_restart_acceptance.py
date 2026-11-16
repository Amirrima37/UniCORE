"""Existing transient format on exported Stage 6 cylinder; bounded sequential CLI runs."""
import json, subprocess, time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'docs/workbench-2/stage6-final/restart';out.mkdir(exist_ok=True)
matrix=json.loads((out.parent/'native-matrix-fields.json').read_text())
source=Path(next(r['directory'] for r in matrix if r['thermal']))/'model.ucjob'
lines=source.read_text().splitlines()
lines[0]='UNICORE_JOB 1 transient_thermal';lines[-1]='0.01 3 300'
job=out/'cylinder.ucjob';job.write_text('\n'.join(lines))
rows=[]
def run(mode,name,expected,*extra,model=job):
    exe=root/'bin'/mode
    dest=out/name
    cmd=[str(exe),'--job',str(model),'--output',str(dest),'--threads','1','--memory-mb','256',*map(str,extra)]
    start=time.perf_counter();p=subprocess.run(cmd,capture_output=True,timeout=30)
    (out/(name+'.log')).write_bytes(p.stdout+p.stderr)
    rows.append(dict(name=name,command=cmd,exit_code=p.returncode,expected=expected,seconds=time.perf_counter()-start))
    (out/'results.json').write_text(json.dumps(rows,indent=2))
    assert p.returncode==expected,(name,p.stderr)
    return dest
release='unicore_solver.exe'
ref=run(release,'reference',0)
paused=run(release,'paused',3,'--pause-after','1')
checkpoint=paused/'checkpoint.ucstate'
assert checkpoint.read_text().startswith('UNICORE_STATE 1 ')
expected=json.loads((ref/'results.json').read_text())['temperature']
for mode in [release,'unicore_solver_debug.exe','unicore_solver_noomp.exe','unicore_solver_debug_noomp.exe']:
    resumed=run(mode,'resume-'+mode,0,'--restart',checkpoint)
    actual=json.loads((resumed/'results.json').read_text())['temperature']
    error=max(abs(a-b) for a,b in zip(expected,actual));assert error<1e-7
    rows[-1]['max_temperature_difference_K']=error
bad=out/'corrupt.ucstate';bad.write_text('UNICORE_STATE 99 damaged')
run(release,'corrupt',2,'--restart',bad)
changed=out/'changed.ucjob';changed.write_text(job.read_text()+'\n')
run(release,'incompatible',2,'--restart',checkpoint,model=changed)
structural=Path(next(r['directory'] for r in matrix if not r['thermal']))/'model.ucjob'
run(release,'structural-restart-unsupported',2,'--restart',checkpoint,model=structural)
run(release,'recovery',0)
(out/'results.json').write_text(json.dumps(rows,indent=2))
print('Stage 6 cylinder transient pause=3; cross-build restart; corrupt/incompatible/structural rejection; recovery PASS')
