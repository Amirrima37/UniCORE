"""Windows standalone A/B: python tests/investigate_hpc22.py CONFIG_JSON REPORT_JSON.
Five fresh processes per configuration, alternating order; all result fields retained.
Run separately from builds and tests. CONFIG_JSON contains [label, executable, args] entries.
"""
import subprocess,time,json,ctypes,hashlib,os,sys
from pathlib import Path
from ctypes import wintypes
configs=json.loads(Path(sys.argv[1]).read_text()); dest=Path(sys.argv[2]); rows=[]
class IO(ctypes.Structure):
 _fields_=[(n,ctypes.c_ulonglong) for n in ['read_ops','write_ops','other_ops','read_bytes','write_bytes','other_bytes']]
def system_times():
 ts=[wintypes.FILETIME() for _ in range(3)]
 assert ctypes.windll.kernel32.GetSystemTimes(*[ctypes.byref(t) for t in ts])
 return [((t.dwHighDateTime<<32)|t.dwLowDateTime)/1e7 for t in ts]
get=ctypes.windll.kernel32.GetProcessTimes
get.argtypes=[wintypes.HANDLE]+[ctypes.POINTER(wintypes.FILETIME)]*4
job=Path('.tools/extreme-axial/model.ucjob'); reference=None
for rep in range(5):
 for label,exe,args in (configs if rep%2==0 else configs[::-1]):
  output=Path('.tools/hpc22')/label/str(rep); system_start=system_times(); start=time.perf_counter()
  p=subprocess.Popen([exe,'--job',str(job),'--output',str(output),'--threads','4','--memory-mb','1024']+args,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  try:
   stdout,stderr=p.communicate(timeout=600)
  except subprocess.TimeoutExpired:
   p.kill();p.communicate();raise
  wall=time.perf_counter()-start
  assert p.returncode==0,stderr
  ts=[wintypes.FILETIME() for _ in range(4)];assert get(wintypes.HANDLE(int(p._handle)),*[ctypes.byref(t) for t in ts])
  seconds=lambda t:((t.dwHighDateTime<<32)|t.dwLowDateTime)/1e7
  cpu=seconds(ts[2])+seconds(ts[3]);system_end=system_times();delta=[b-a for a,b in zip(system_start,system_end)];system_busy=delta[1]+delta[2]-delta[0];io=IO();getio=ctypes.windll.kernel32.GetProcessIoCounters;getio.argtypes=[wintypes.HANDLE,ctypes.POINTER(IO)];assert getio(wintypes.HANDLE(int(p._handle)),ctypes.byref(io));data=json.loads((output/'results.json').read_text())
  fields={k:data[k] for k in ['displacement_flat','reactions_flat','stress','strain','von_mises','iterations','relative_residual']}
  if reference is None:reference=fields
  assert fields==reference,'Numerical mismatch'
  row={k:v for k,v in data.items() if not isinstance(v,list)}
  row.update(io={n:getattr(io,n) for n,_ in io._fields_},system_busy_cpu_s=system_busy,other_busy_cores=(system_busy-cpu)/wall,omp_environment={k:v for k,v in os.environ.items() if k.startswith(('OMP_','GOMP_'))},label=label,rep=rep,wall_s=wall,cpu_s=cpu,busy_cores=cpu/wall,exe_sha256=hashlib.sha256(Path(exe).read_bytes()).hexdigest(),job_sha256=hashlib.sha256(job.read_bytes()).hexdigest(),exact_fields=True)
  rows.append(row);dest.write_text(json.dumps(rows,indent=2)); print(label,rep,round(wall,3),round(cpu,3),data['preparation_ms'],flush=True)

