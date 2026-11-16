"""Real HEX8 elasticity / TET4 conduction benchmark; no synthetic solver matrices.
Default pass: small FEM diagnostics with strict case/campaign budgets; large cases require opt-in. New output folders, complete results, CPU and wall accounting.
"""
import argparse,ctypes,hashlib,json,math,os,subprocess,time
from pathlib import Path
from ctypes import wintypes
P=argparse.ArgumentParser()
P.add_argument('--suite',choices=['diagnostic','small','large','all','additional'],default='diagnostic')
P.add_argument('--report',default='docs/hpc-optimization/hpc23-diagnostic-'+str(int(time.time()))+'.json')
P.add_argument('--case-budget-s',type=float,default=10)
P.add_argument('--campaign-budget-s',type=float,default=90)
P.add_argument('--allow-large',action='store_true')
P.add_argument('--max-dof',type=int,default=15000)
args=P.parse_args()
if not math.isfinite(args.case_budget_s) or not math.isfinite(args.campaign_budget_s) or args.case_budget_s<=0 or args.campaign_budget_s<=0:P.error('Budgets must be positive')
if args.suite in ['large','all','additional'] and not args.allow_large:P.error('Large cases require explicit --allow-large and a suitable --max-dof; no automatic large campaign')
if Path(args.report).exists():P.error('Report exists; choose a new path to preserve completed measurements')
kernel=ctypes.windll.kernel32
kernel.CreateMutexW.argtypes=[ctypes.c_void_p,wintypes.BOOL,wintypes.LPCWSTR];kernel.CreateMutexW.restype=wintypes.HANDLE
campaign_mutex=kernel.CreateMutexW(None,True,'Local\\UniCORE_HPC23_BENCHMARK')
if not campaign_mutex or kernel.GetLastError()==183:raise SystemExit('Another HPC23 benchmark campaign is active')
folder=Path('.tools/hpc23-bench');folder.mkdir(exist_ok=True)
run_folder=folder/('bounded-'+str(time.time_ns()));run_folder.mkdir()
rows=[];campaign_start=time.perf_counter();reference_times={};pathological=set()
# Preserve an exact-configuration ledger across passes, including timed-out/severely slow cases.
ledger=Path('docs/hpc-optimization/hpc23-pathological.json')
if ledger.exists():pathological={tuple(x) for x in json.loads(ledger.read_text())}
def remember(key):
 pathological.add(key);ledger.write_text(json.dumps(sorted(pathological),indent=2))
class FileTime(ctypes.Structure):
 _fields_=[('low',wintypes.DWORD),('high',wintypes.DWORD)]
def cpu_seconds(p):
 ts=[FileTime() for _ in range(4)];get=ctypes.windll.kernel32.GetProcessTimes
 get.argtypes=[wintypes.HANDLE]+[ctypes.POINTER(FileTime)]*4
 assert get(wintypes.HANDLE(int(p._handle)),*[ctypes.byref(t) for t in ts])
 return sum(((t.high<<32)|t.low)/1e7 for t in ts[2:])

def memory():
 class Status(ctypes.Structure):
  _fields_=[('length',wintypes.DWORD),('load',wintypes.DWORD)]+[(n,ctypes.c_ulonglong) for n in ['total','available','page','availpage','virtual','availvirtual','extended']]
 m=Status();m.length=ctypes.sizeof(m);assert ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m));return m.available

def model(name,nx,ny,nz,kind='structural',length=1,hetero=False,bending=False):
 path=folder/(name+'.ucjob');mx=nx+1;my=ny+1;plane=mx*my;nodes=plane*(nz+1)
 with path.open('w') as f:
  f.write(f'UNICORE_JOB 1 {"steady_thermal" if kind=="thermal" else "static_structural"}\n{nodes} {nx*ny*nz*(6 if kind=="thermal" else 1)}\n')
  for z in range(nz+1):
   for y in range(ny+1):
    for x in range(nx+1):f.write(f'{length*x/nx} {y/ny} {z/nz}\n')
  for z in range(nz):
   for y in range(ny):
    for x in range(nx):
     a=x+mx*y+plane*z;ids=[a,a+1,a+mx+1,a+mx,a+plane,a+plane+1,a+plane+mx+1,a+plane+mx];contrast=(1e6 if kind=='thermal' else 1e4) if hetero and x>=nx//2 else 1
     if kind=='thermal':
      for local in [(0,1,2,6),(0,2,3,6),(0,3,7,6),(0,7,4,6),(0,4,5,6),(0,5,1,6)]:f.write('4 '+' '.join(str(ids[i]) for i in local)+f' {contrast} 0 0\n')
     else:f.write('8 '+' '.join(map(str,ids))+f' {1000*contrast} {0.3 if bending or hetero else 0}\n')
  for z in range(nz+1):
   for y in range(ny+1):
    for x in range(nx+1):
     if kind=='thermal':f.write(f'{int(x in [0,nx])} {300+100*x/nx}\n')
     else:
      weight=(.5 if y in [0,ny] else 1)*(.5 if z in [0,nz] else 1)/(ny*nz)
      for axis in range(3):f.write(f'{weight if x==nx and axis==int(bending) else 0} {int(x==0)} 0\n')
  if kind=='thermal':f.write('0\n0 0 293.15\n')
 return path,nodes*(1 if kind=='thermal' else 3)

def save():Path(args.report).write_text(json.dumps(rows,indent=2))
def benchmark(name,nx,ny,nz,kind='structural',length=1,hetero=False,bending=False,reps=3,large=False):
 dof=(nx+1)*(ny+1)*(nz+1)*(1 if kind=='thermal' else 3);available=memory();history=rows
 if args.suite=='additional':history=rows+json.loads(Path('docs/hpc-optimization/hpc23-large.json').read_text())
 observed=[r['peak_working_set_bytes']/r['dof'] for r in history if r.get('kind')==kind and r.get('exit_code')==0 and r['dof']>=100000]
 estimate=int(dof*(max(observed)*1.25 if observed else (5500 if kind=='structural' else 6500)))
 # Keep 25% headroom for the host; estimate includes global hash matrix + CSR + factor.
 if large and estimate>available*.75:
  rows.append(dict(workload=name,dof=dof,skipped=True,reason='Estimated FEM/CSR/factor memory exceeds 75% of available RAM',estimated_bytes=estimate,available_bytes=available));save();print(name,'SKIP RAM',flush=True);return
 if dof>args.max_dof or time.perf_counter()-campaign_start>=args.campaign_budget_s:
  rows.append(dict(workload=name,dof=dof,skipped=True,reason='DOF guard or campaign budget'));save();return
 job,dof=model(name,nx,ny,nz,kind,length,hetero,bending);reference=None
 methods=['jacobi','block-jacobi','ic0','auto'] if not large else (['jacobi','ic0'] if kind=='thermal' and args.suite=='additional' else ['jacobi','block-jacobi','ic0'])
 if args.suite=='diagnostic':methods=['jacobi','ic0'] if kind=='thermal' else ['jacobi','block-jacobi','ic0']
 # Input preflight is conservative (4KiB per element), independently of measured peak.
 elements=nx*ny*nz*(6 if kind=='thermal' else 1);budget=max(1024,math.ceil(((dof/(1 if kind=='thermal' else 3))*1024+elements*4096)/1048576)+256,math.ceil(estimate*1.25/1048576))
 for rep in range(1 if args.suite=='diagnostic' else reps):
  for method in (methods if rep%2==0 else methods[::-1]):
   # Scalar thermal block requests are already proven to fall back; do not rerun them as block tests.
   if kind=='thermal' and method=='block-jacobi':
    rows.append(dict(workload=name,dof=dof,method=method,skipped=True,selected_preconditioner='jacobi',preconditioner_fallback='BLOCK_STRUCTURE_UNAVAILABLE',reason='Known fallback; not a Block Jacobi measurement'));save();continue
   for threads in ([1,2] if args.suite=='diagnostic' else [4]):
    key=(name,method,threads)
    if key in pathological:
     rows.append(dict(workload=name,dof=dof,method=method,threads=threads,skipped=True,reason='Previously pathological configuration'));save();continue
    remaining=args.campaign_budget_s-(time.perf_counter()-campaign_start)
    if remaining<=0:save();return
    limit=min(args.case_budget_s,remaining)
    previous=reference_times.get((name,method))
    if threads>1 and previous:limit=min(limit,max(1.0,1.75*previous))
    output=run_folder/name/(method+'-'+str(threads)+'-'+str(rep));output.mkdir(parents=True,exist_ok=True)
    start=time.perf_counter();samples=[];cancel_sent=False;timed_out=False
    p=subprocess.Popen(['bin/unicore_solver.exe','--job',str(job),'--output',str(output),'--threads',str(threads),'--memory-mb',str(budget),'--preconditioner',method],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    try:
     while True:
      elapsed=time.perf_counter()-start
      if elapsed>=limit:
       timed_out=True;p.kill();stdout,stderr=p.communicate();break
      if elapsed>=max(0,limit-.25) and not cancel_sent:
       (output/'cancel.request').touch();cancel_sent=True
      try:
       stdout,stderr=p.communicate(timeout=min(.2,max(.001,limit-elapsed)));break
      except subprocess.TimeoutExpired:
       status={}
       try:status=json.loads((output/'status.json').read_text())
       except (FileNotFoundError,json.JSONDecodeError):pass
       samples.append(dict(wall_s=time.perf_counter()-start,cpu_s=cpu_seconds(p),phase=status.get('phase'),state=status.get('state')))
    except BaseException:
     (output/'cancel.request').touch()
     try:p.communicate(timeout=.25)
     except subprocess.TimeoutExpired:p.kill();p.communicate()
     raise
    wall=time.perf_counter()-start
    row=dict(workload=name,dof=dof,elements=elements,kind=kind,method=method,requested_preconditioner=method,threads=threads,rep=rep,wall_s=wall,case_budget_s=limit,timeout=timed_out,exit_code=p.returncode,stderr=stderr.decode(errors='replace'),available_bytes=available,budget_mib=budget,job_sha256=hashlib.sha256(job.read_bytes()).hexdigest(),exe_sha256=hashlib.sha256(Path('bin/unicore_solver.exe').read_bytes()).hexdigest(),output=str(output),samples=samples)
    row['cpu_s']=cpu_seconds(p);row['average_busy_cores']=row['cpu_s']/wall;row['cpu_utilization_percent']=100*row['average_busy_cores']/os.cpu_count()
    if timed_out or cancel_sent or (threads>1 and previous and wall>1.75*previous and wall>.5):
     row['pathological']=True;remember(key)
     if samples and samples[-1]['state']=='Validating':
      for blocked_method in methods:
       for blocked_threads in [1,2,4]:remember((name,blocked_method,blocked_threads))
    if threads==1 and p.returncode==0:reference_times[(name,method)]=wall
    if p.returncode==0:
     data=json.loads((output/'results.json').read_text());row.update({k:v for k,v in data.items() if not isinstance(v,list)})
     key='temperature' if kind=='thermal' else 'displacement_flat';values=data[key]
     if reference is None:reference=values
     row['relative_solution_difference']=max(abs(a-b) for a,b in zip(reference,values))/max(max(map(abs,reference)),1e-30)
     if kind=='thermal':
      def exact(i):
       x=(i%(nx+1))/nx
       return 300+100*((min(x,.5)+max(0,x-.5)/1e6)/(.5+.5/1e6) if hetero else x)
      row['analytic_max_error']=max(abs(t-exact(i)) for i,t in enumerate(values))
     elif not hetero and not bending:row['analytic_max_error']=max(abs(values[3*i]-.001*length*(i%(nx+1))/nx) for i in range(len(values)//3))
     del data
    rows.append(row);save();print(name,method,rep,'wall',round(wall,3),'it',row.get('iterations'),'res',row.get('relative_residual'),'fallback',row.get('preconditioner_fallback'),flush=True)
if args.suite in ['small','all']:
 benchmark('elastic-8',8,8,8)
 benchmark('elastic-16',16,16,16)
 benchmark('slender-bending',48,4,4,length=12,bending=True)
 benchmark('heterogeneous-elastic',16,8,8,hetero=True)
 benchmark('contrast-conduction-8',8,8,8,kind='thermal',hetero=True)
 benchmark('contrast-conduction-16',16,16,16,kind='thermal',hetero=True)
if args.suite in ['large','all']:
 for n in [32,43,54,69]:benchmark('elastic-large-'+str(n),n,n,n,reps=5 if n==32 else 3,large=True)
 for n in [46,62,78,99]:benchmark('thermal-large-'+str(n),n,n,n,kind='thermal',hetero=True,reps=3,large=True)

if args.suite=='additional':
 benchmark('elastic-large-43-retry',43,43,43,reps=3,large=True)
 benchmark('thermal-large-62-retry',62,62,62,kind='thermal',hetero=True,reps=1,large=True)
 benchmark('thermal-large-78-retry',78,78,78,kind='thermal',hetero=True,reps=1,large=True)
 benchmark('thermal-large-99-retry',99,99,99,kind='thermal',hetero=True,reps=1,large=True)

if args.suite=='diagnostic':
 benchmark('diagnostic-elastic-8',8,8,8,reps=1)
 benchmark('diagnostic-conduction-8',8,8,8,kind='thermal',hetero=True,reps=1)
 benchmark('diagnostic-conduction-16',16,16,16,kind='thermal',hetero=True,reps=1)
