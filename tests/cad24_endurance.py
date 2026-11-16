import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Fixed 100-cycle native/mesh workload; measurements are not a leak-free claim."""
import sys,json,os,time,ctypes as C
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from native_occt import run,SDK
from cad_model import evaluate
from gmsh_study import mesh_study
from mesh_config import defaults
from process_memory import Counters
OUT=output_dir('CAD/cad24-completion');rows=[]
k=C.windll.kernel32;k.OpenProcess.argtypes=[C.c_ulong,C.c_int,C.c_ulong];k.OpenProcess.restype=C.c_void_p;k.WaitForSingleObject.argtypes=[C.c_void_p,C.c_ulong];k.CloseHandle.argtypes=[C.c_void_p]
def alive(pid):
    handle=k.OpenProcess(0x100000,False,pid)
    if not handle:return False
    try:return k.WaitForSingleObject(handle,0)==258
    finally:k.CloseHandle(handle)
def memory():
    info=Counters();info.cb=C.sizeof(info);C.windll.psapi.GetProcessMemoryInfo(C.c_void_p(-1),C.byref(info),C.sizeof(info));return info.working_set
start=time.monotonic();source=(ROOT/'tests/fixtures/step/bar.step').read_bytes()
for i in range(100):
    a,raw=run(action='box',dimensions=[.1,.2,.1]);b,tool=run(action='cylinder',dimensions=[.02+.0001*(i%10),.3,.02])
    cut,raw=run(raw,'cut',tool=tool);tr,raw=run(raw,'transform',matrix=[1,0,0,.001*(i%10),0,1,0,0,0,0,1,0])
    assert tr['validation']['status']=='VALID'
    receipts=[a,b,cut,tr]
    if i%10==0:
        step,_=run(source,'step');assert step['validation']['status']=='VALID';receipts.append(step)
        model=dict(schema=1,units='m',root='cut',nodes=[dict(id='box',type='Box',dimensions=[.1,.2,.1]),dict(id='bore',type='Cylinder',dimensions=[.02+.0001*(i%10),.3,.02]),dict(id='cut',type='Cut',base='box',tool='bore',position=[.001*(i%10),0,0])])
        evaluated=evaluate(dict(model=model,quality=8));p=evaluated['part'];p['id']='body'
        p['mesh_settings']=defaults(.06);p['mesh_settings'].update(schema=2,order=1 if i%20==0 else 2)
        p['mesh_settings'].update(curvature_points=24,min_size=.001)
        mesh=mesh_study(ROOT,dict(parts=[p],mesh_divisions=3),.06);assert mesh['quality']['minimum_jacobian']>0
        # Serialize and reload authoritative records; no native handles survive.
        restored=json.loads(json.dumps(p));assert restored['cad_sha256']==p['cad_sha256']
    orphans=[r['process']['pid'] for r in receipts if alive(r['process']['pid'])];assert not orphans
    rows.append(dict(iteration=i,host_working_set_after_cleanup=memory(),native_peak_commit=max(r['process']['peak_commit_bytes'] for r in receipts),native_exits=[r['exit_code'] for r in receipts],native_pids=[r['process']['pid'] for r in receipts],orphan_count=len(orphans),retained_native_temp_directories=len(list((SDK/'jobs').glob('*')))))
    (OUT/'endurance.json').write_text(json.dumps(dict(iterations=len(rows),elapsed_seconds=time.monotonic()-start,rows=rows,scope='100 native cycles; 10 STEP imports; 10 alternating TET4/TET10 remeshes. Separate campaigns cover solver/GUI/cancellation. No universal leak-free claim.'),indent=2))
print('CAD24_ENDURANCE_PASS')
