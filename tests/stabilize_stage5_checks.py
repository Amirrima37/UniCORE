"""Time-bounded final Stage 5 workflow checks with retained diagnostic logs."""
import subprocess, json, time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'docs/workbench-2/stage5-final-checks'
out.mkdir(exist_ok=True)
godot=str(root/'.tools/godot/Godot_v4.0-stable_win64_console.exe')
rows=[]
def run(name,command,timeout):
    start=time.perf_counter()
    try:
        p=subprocess.run(command,cwd=root,capture_output=True,timeout=timeout)
        log=(p.stdout+p.stderr).decode('utf-8',errors='replace')
        row=dict(name=name,exit=p.returncode,seconds=time.perf_counter()-start,passed=p.returncode==0 and 'SCRIPT ERROR:' not in log)
    except subprocess.TimeoutExpired as e:
        log=((e.stdout or b'')+(e.stderr or b'')).decode('utf-8',errors='replace')
        row=dict(name=name,timeout=True,passed=False,seconds=time.perf_counter()-start)
    (out/(name+'.log')).write_text(log,encoding='utf-8')
    rows.append(row);(out/'results.json').write_text(json.dumps(rows,indent=2));print(row,flush=True)
    assert row['passed'],name

for name in ['test_stage5_provenance','test_stage5_quality','test_stage5_display','test_stage5_probes','test_cylinder_fem','test_workbench2','test_workbench2_stage2','test_workbench2_stage3']:
    run(name,[godot,'--headless','--path',str(root),'-s','res://tests/'+name+'.gd'],100)
run('checkpoint-restart',['C:/Users/Victus/AppData/Local/Python/bin/python.exe','tests/test_extreme_checkpoint.py'],120)
# The installed Godot executable selects the debug extension. Exercise the release
# extension through the same ABI, restoring the original descriptor even on failure.
descriptor=root/'bin/unicore_native.gdextension'
original=descriptor.read_bytes()
try:
    descriptor.write_bytes(original.replace(b'unicore_native.windows.template_debug.x86_64.dll',b'unicore_native.windows.template_release.x86_64.dll'))
    for name in ['test_native_structural_suite','test_native_thermal_suite','test_native_radiation']:
        run('release-extension-'+name,[godot,'--headless','--path',str(root),'-s','res://tests/'+name+'.gd'],30)
finally:
    descriptor.write_bytes(original)
run('cylinder-graphics-performance',[godot,'--path',str(root),'-s','res://tests/stabilize_stage5_graphics.gd'],100)
run('box-graphics',[godot,'--path',str(root),'-s','res://tests/capture_stage5.gd'],60)

run("box-thermal-graphics-playback",[godot,"--path",str(root),"-s","res://tests/stabilize_stage5_box_thermal.gd"],90)

import shutil
for field in ["displacement","von_mises"]:
    for width in [1280,1920]:
        shutil.copyfile(root/f"docs/workbench-2/stage5-{field}-{width}.png", root/f"docs/workbench-2/stage5-final-box-{field}-{width}.png")
