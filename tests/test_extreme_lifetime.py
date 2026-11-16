import subprocess,json,time
from pathlib import Path
folder=Path('.tools/lifetime-large')
folder.mkdir(exist_ok=True)
n=24;m=n+1;plane=m*m;nodes=m**3
with (folder/'model.ucjob').open('w') as stream:
 stream.write(f'UNICORE_JOB 1 static_structural\n{nodes} {n**3}\n')
 for z in range(m):
  for y in range(m):
   for x in range(m):stream.write(f'{10*x/n} {.1*y/n} {.1*z/n}\n')
 for z in range(n):
  for y in range(n):
   for x in range(n):
    a=x+m*y+plane*z;stream.write('8 '+' '.join(map(str,[a,a+1,a+m+1,a+m,a+plane,a+plane+1,a+plane+m+1,a+plane+m]))+' 1000 0.25\n')
 for i in range(nodes):
  for axis in range(3):stream.write(f'{1e-6/(m*m) if i%m==n and axis==1 else 0} {int(i%m==0)} 0\n')
for name in ['status.json','results.json','cancel.request']:(folder/name).unlink(missing_ok=True)
r=subprocess.run([str(Path('.tools/godot/Godot_v4.0-stable_win64.exe').resolve()),'--headless','--path','.','--script','tests/launch_extreme_then_exit.gd'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,text=True,timeout=30)
assert r.returncode==0
initial=None
for i in range(100):
 try:initial=json.loads((folder/'status.json').read_text())
 except (OSError,ValueError):time.sleep(.1);continue
 if initial['state']=='Running':break
 time.sleep(.1)
assert initial['state']=='Running',initial
duplicate=subprocess.run([str(Path('bin/unicore_solver.exe').resolve()),'--job',str((folder/'model.ucjob').resolve()),'--output',str(folder.resolve())],capture_output=True,text=True,timeout=10)
assert duplicate.returncode==6,duplicate.stderr
(folder/'cancel.request').write_text('cancel after Godot exited')
for i in range(100):
 time.sleep(.1)
 try:final=json.loads((folder/'status.json').read_text())
 except (OSError,ValueError):continue
 if final['state']=='Cancelled':break
assert final['state']=='Cancelled',final
Path('docs/extreme-mode/lifetime.json').write_text(json.dumps({'godot_exit':r.returncode,'duplicate_launch_exit':duplicate.returncode,'status_after_godot_exit':initial,'action':'cancel after confirmed Godot exit','final_status':final},indent=2))
print('Independent lifetime and cancellation after Godot closed PASS')
