import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Actual child cancellation, genuine invalid deck, and successful recovery."""
import json, subprocess, sys, time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=godot_environment_root()/'process-tests'
base.mkdir(parents=True,exist_ok=True)
exe=root/'.tools/engines/calculix/CalculiX-2.23.0-win-x64/bin/ccx.exe'
launcher=root/'scripts/engines/run_owned_solver.py'
source=root/'.tools/engines/ccx-test/model.inp'
rows=[]
for name in ['cancel','invalid','recovery']:
    job=base/(name+'-'+str(time.time_ns()));job.mkdir()
    (job/'model.inp').write_bytes(source.read_bytes() if name!='invalid' else b'*HEADING\ninvalid\n*ELEMENT,TYPE=NOT_REAL\n1,1,2,3,4\n')
    if name=='cancel': (job/'cancel').touch()
    p=subprocess.run([sys.executable,str(launcher),str(job),str(exe)],capture_output=True,timeout=140)
    receipt=json.loads((job/'receipt.json').read_text())
    assert (job/'running.json').exists(), 'No owned solver launched'
    if name=='cancel': assert receipt['state']=='cancelled',receipt
    if name=='invalid': assert receipt['state']=='failed',receipt
    if name=='recovery': assert receipt['state']=='completed' and receipt['exit_code']==0,receipt
    rows.append(dict(test=name,launcher_exit=p.returncode,receipt=receipt,job=str(job)))
(base/'results.json').write_text(json.dumps(rows,indent=2))
print('CALCULIX_PROCESS_PASS',json.dumps(rows))

