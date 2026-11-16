"""Bounded sequential HPC24 paired measurements; never overwrites evidence."""
import json,subprocess,time,sys,ctypes,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
kernel=ctypes.windll.kernel32
kernel.CreateMutexW.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_wchar_p];kernel.CreateMutexW.restype=ctypes.c_void_p
mutex=kernel.CreateMutexW(None,True,'Local\\UniCORE_HPC23_BENCHMARK')
if not mutex or kernel.GetLastError()==183:raise SystemExit('Another benchmark campaign is active')
report=Path(sys.argv[1]);assert not report.exists()
folder=root/'.tools'/report.stem;folder.mkdir(exist_ok=False)
start=time.perf_counter();rows=[]
configs=[('A',sys.argv[2]),('B',sys.argv[3])] if len(sys.argv)>3 else [('A','bin/unicore_solver.exe')]
try:
 for rep in range(3):
  for job in ['elastic-16','contrast-conduction-16']:
   for label,exe in (configs if rep%2==0 else configs[::-1]):
    remaining=90-(time.perf_counter()-start)
    if remaining<=0:raise TimeoutError('campaign budget')
    source=root/'.tools/hpc23-bench'/(job+'.ucjob');out=folder/f'{job}-{label}-{rep}'
    t=time.perf_counter();p=subprocess.Popen([exe,'--job',str(source),'--output',str(out),'--threads','1','--memory-mb','1024'],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    try: _,err=p.communicate(timeout=min(10,remaining))
    except subprocess.TimeoutExpired:
     p.kill();p.communicate();rows.append(dict(job=job,label=label,timeout=True));raise
    times=(ctypes.c_ulonglong*4)();ctypes.windll.kernel32.GetProcessTimes(ctypes.c_void_p(int(p._handle)),*[ctypes.byref(times,i*8) for i in range(4)])
    row=dict(job=job,label=label,wall_s=time.perf_counter()-t,cpu_s=(times[2]+times[3])/1e7,exit=p.returncode,input_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),executable_sha256=hashlib.sha256(Path(exe).read_bytes()).hexdigest(),stderr=err.decode(errors='replace'))
    if p.returncode==0:
     row['result']=json.loads((out/'results.json').read_text())
     if (out/'preparation.json').exists():row['preparation']=json.loads((out/'preparation.json').read_text())
    rows.append(row);report.write_text(json.dumps(rows,indent=2));print(job,label,row['wall_s'],flush=True)
    assert p.returncode==0,row
finally:report.write_text(json.dumps(rows,indent=2))
