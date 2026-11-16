"""Final sequential campaign: real exits, streams, timestamps, bounded execution."""
import json, subprocess, sys, time
from datetime import datetime, timezone
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'docs/architecture/evidence/calculix/final-campaign';out.mkdir(exist_ok=True)
godot=str(root/'.tools/godot/Godot_v4.0-stable_win64_console.exe')
steps=[
 ('export',[godot,'--headless','--path',str(root),'--script','tests/test_calculix_adapter.gd']),
 ('patch',[godot,'--headless','--path',str(root),'--script','tests/test_calculix_numerical.gd']),
 ('graphical-workbench',[godot,'--path',str(root),'--script','tests/test_calculix_workbench.gd']),
 ('owned-process',[sys.executable,'tests/test_calculix_process.py']),
 ('mesh-repeatability',[sys.executable,'tests/test_gmsh_repeatability.py']),
 ('extreme-comparison',[sys.executable,'tests/compare_calculix_extreme.py']),
 ('bar-cantilever',[godot,'--headless','--path',str(root),'--script','tests/benchmark_calculix_gmsh.gd']),
 ('default-regressions',[sys.executable,'native/run_regressions.py','--godot',godot,'--output','docs/architecture/evidence/calculix/regressions-final'])]
rows=[]
for name,args in steps:
    started=datetime.now(timezone.utc).isoformat();start=time.monotonic()
    try:
        p=subprocess.run(args,cwd=root,capture_output=True,timeout=240)
        stdout,stderr=p.stdout,p.stderr
        passed=p.returncode==0 and b'SCRIPT ERROR:' not in stdout+stderr
        row=dict(name=name,exit_code=p.returncode,passed=passed,state='completed')
    except subprocess.TimeoutExpired as error:
        stdout,stderr=error.stdout or b'',error.stderr or b''
        row=dict(name=name,exit_code=None,passed=False,state='timeout')
    (out/f'{name}.stdout.txt').write_bytes(stdout);(out/f'{name}.stderr.txt').write_bytes(stderr)
    row.update(started_utc=started,ended_utc=datetime.now(timezone.utc).isoformat(),seconds=time.monotonic()-start)
    rows.append(row);print(json.dumps(row),flush=True)
    (out/'results.json').write_text(json.dumps(rows,indent=2))
sys.exit(0 if all(row['passed'] for row in rows) else 1)
