"""Sequential A/B on the SAME saved files. Restores source files even on failure."""
import subprocess,os,json,time,ctypes as C,ctypes.wintypes as W,statistics
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'docs/workbench-2'
paths=['core/cae/extreme_jobs.gd','core/cae/structural_display.gd','core/cae/thermal_display.gd','ui/cae/cae_workspace.gd']
saved={p:(root/p).read_bytes() for p in paths}
summary=[]
class Memory(C.Structure):
    _fields_=[('cb',W.DWORD),('faults',W.DWORD),('peak',C.c_size_t),('working',C.c_size_t),('quota_peak_paged',C.c_size_t),('quota_paged',C.c_size_t),('quota_peak_nonpaged',C.c_size_t),('quota_nonpaged',C.c_size_t),('pagefile',C.c_size_t),('peak_pagefile',C.c_size_t)]
psapi=C.WinDLL('psapi');psapi.GetProcessMemoryInfo.argtypes=[W.HANDLE,C.POINTER(Memory),W.DWORD]
try:
    for variant in ['A','B']:
        for path in paths:
            if variant=='A':
                text=(root/'.tools/stage51-baseline'/Path(path).name).read_text(encoding='utf-8-sig')
                if path.endswith('extreme_jobs.gd') or path.endswith('structural_display.gd'):text+='\nvar timings := {}\n'
                if path.endswith('cae_workspace.gd'):text+='\nvar post_timings := {}\n'
                (root/path).write_text(text,encoding='utf-8')
            else:(root/path).write_bytes(saved[path])
        env=os.environ.copy();env['UNICORE_STAGE51_VARIANT']=variant
        start=time.monotonic();peak=0
        with open(out/f'stage51-{variant}.log','wb') as log:
            p=subprocess.Popen([str(root/'.tools/godot/Godot_v4.0-stable_win64.exe'),'--path',str(root),'-s','res://tests/benchmark_stage51.gd'],cwd=root,env=env,stdout=log,stderr=log)
            while p.poll() is None:
                counters=Memory();counters.cb=C.sizeof(Memory)
                if psapi.GetProcessMemoryInfo(W.HANDLE(int(p._handle)),C.byref(counters),counters.cb):peak=max(peak,counters.peak)
                if time.monotonic()-start>150:p.kill();raise TimeoutError(variant)
                time.sleep(.05)
        assert p.returncode==0,(variant,p.returncode)
        raw=json.loads((out/f'stage51-{variant}.json').read_text())
        rows=[]
        for case in sorted({r['case'] for r in raw}):
            for operation in ['import','switch']:
                samples=[r['ms'] for r in raw if r['case']==case and r['operation']==operation]
                rows.append(dict(case=case,operation=operation,n=len(samples),median_ms=statistics.median(samples),min_ms=min(samples),max_ms=max(samples)))
        summary.append(dict(variant=variant,peak_working_set_bytes=peak,seconds=time.monotonic()-start,rows=rows))
        (out/'stage51-comparison.json').write_text(json.dumps(summary,indent=2));print(summary[-1],flush=True)
finally:
    for path in paths:(root/path).write_bytes(saved[path])
