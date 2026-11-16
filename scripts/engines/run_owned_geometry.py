"""Bounded geometry child, kill-on-close Windows Job Object and parent monitor."""
import ctypes as C, ctypes.wintypes as W, sys, subprocess, time, json, os
from pathlib import Path
job=Path(sys.argv[1]).resolve();timeout=float(sys.argv[2]);parent=int(sys.argv[3])
from artifact_retention import begin,finish
from owned_mesh_job import resume_owned_process
begin(job)
if not 0<=timeout<=120:raise SystemExit('CAD timeout must be 0..120 seconds')
k=C.WinDLL('kernel32',use_last_error=True)
P=C.c_void_p;k.CreateJobObjectW.argtypes=[P,W.LPCWSTR];k.CreateJobObjectW.restype=P
k.SetInformationJobObject.argtypes=[P,C.c_int,P,W.DWORD];k.AssignProcessToJobObject.argtypes=[P,P]
k.OpenProcess.argtypes=[W.DWORD,W.BOOL,W.DWORD];k.OpenProcess.restype=P
k.WaitForSingleObject.argtypes=[P,W.DWORD];k.CloseHandle.argtypes=[P]
class BASIC(C.Structure):
    _fields_=[('ProcessTime',C.c_int64),('JobTime',C.c_int64),('Flags',W.DWORD),('MinWorking',C.c_size_t),('MaxWorking',C.c_size_t),('ActiveLimit',W.DWORD),('Affinity',C.c_size_t),('Priority',W.DWORD),('Scheduling',W.DWORD)]
class IO(C.Structure):_fields_=[(name,C.c_uint64) for name in ['ReadOp','WriteOp','OtherOp','ReadBytes','WriteBytes','OtherBytes']]
class EXT(C.Structure):_fields_=[('Basic',BASIC),('IO',IO),('ProcessMemory',C.c_size_t),('JobMemory',C.c_size_t),('PeakProcess',C.c_size_t),('PeakJob',C.c_size_t)]
handle=None;process=None;parent_handle=None;state='failed';error='';contained=False
start=time.monotonic();peak_process=0;peak_job=0
try:
    handle=k.CreateJobObjectW(None,None);limits=EXT();limits.Basic.Flags=0x2000|0x100;limits.ProcessMemory=768*1024*1024
    if not handle or not k.SetInformationJobObject(handle,9,C.byref(limits),C.sizeof(limits)):raise OSError('Cannot establish CAD Job Object memory/kill-on-close limits')
    parent_handle=k.OpenProcess(0x100000,False,parent)
    if not parent_handle:raise OSError('Cannot monitor CAD owner process')
    temporary=job/'kernel-temp';temporary.mkdir()
    env=os.environ.copy();env['UNICORE_CAD_JOB_TEMP']=str(temporary)
    with (job/'stdout.txt').open('wb') as out,(job/'stderr.txt').open('wb') as err:
        process=subprocess.Popen([sys.executable,str(Path(__file__).with_name('cad_model.py')),str(job/'request.json'),str(job/'result.json')],stdout=out,stderr=err,env=env,creationflags=subprocess.CREATE_NO_WINDOW|0x4)
        if not k.AssignProcessToJobObject(handle,P(int(process._handle))):raise OSError('Cannot contain CAD worker in Job Object')
        contained=True;(job/'running.json').write_text(json.dumps(dict(pid=process.pid,parent_pid=parent,job_object=True)))
        resume_owned_process(process.pid)
        deadline=time.monotonic()+timeout
        while process.poll() is None:
            sizes={}
            for path in job.rglob('*'):
                try:
                    if path.is_file():sizes[str(path.relative_to(job))]=path.stat().st_size
                except FileNotFoundError:pass # A completed nested native job removes its private files.
            if (job/'cancel').exists():state='cancelled'
            elif k.WaitForSingleObject(parent_handle,0)!=258:state='owner_exited'
            elif time.monotonic()>deadline:state='timeout'
            elif any(sizes.get(name,0)>4*1024*1024 for name in ['stdout.txt','stderr.txt']) or sizes.get('result.json',0)>96*1024*1024 or sum(sizes.values())>256*1024*1024:state='output_limit'
            else:time.sleep(.02);continue
            process.terminate();break
        process.wait(timeout=5)
        if any((job/name).exists() and (job/name).stat().st_size>limit for name,limit in [('stdout.txt',4*1024*1024),('stderr.txt',4*1024*1024),('result.json',96*1024*1024)]):state='output_limit'
        if state=='failed':state='completed' if process.returncode==0 and (job/'result.json').is_file() else 'failed'
except Exception as e:error=str(e)
finally:
    if process and process.poll() is None:
        process.kill();process.wait(timeout=5)
    if parent_handle:k.CloseHandle(parent_handle)
    if handle:
        k.QueryInformationJobObject.argtypes=[P,C.c_int,P,W.DWORD,P]
        usage=EXT()
        if k.QueryInformationJobObject(handle,9,C.byref(usage),C.sizeof(usage),None):peak_process=usage.PeakProcess;peak_job=usage.PeakJob
        k.CloseHandle(handle)
receipt=dict(state=state,exit_code=process.returncode if process else None,error=error,job_object=contained,seconds=time.monotonic()-start,peak_process_memory_bytes=peak_process,peak_job_memory_bytes=peak_job,memory_limit_bytes=768*1024*1024)
temporary_receipt=job/'receipt.tmp';temporary_receipt.write_text(json.dumps(receipt));temporary_receipt.replace(job/'receipt.json')
finish(job)
raise SystemExit(0 if state=='completed' else 1)
