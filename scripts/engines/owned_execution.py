"""Bounded preprocessing/CalculiX execution; no solver implementation here."""
import os,time,subprocess,threading
from datetime import datetime,timezone
from pathlib import Path
from owned_mesh_job import Job,resume_owned_process
from process_memory import peak_working_set
def execute(job,command,timeout=120,parent=None,outputs=None):
    start=time.monotonic();started=datetime.now(timezone.utc).isoformat();p=None;owner=None;peak=0;state='failed';error='';overflow=threading.Event();threads=[]
    def output_overflow():
        for name,limit in (outputs or {}).items():
            try:
                if (job/name).stat().st_size>limit:return True
            except FileNotFoundError:pass # CalculiX may replace its output while starting.
        return False
    def drain(pipe,path):
        count=0
        with path.open('wb') as f:
            while True:
                block=pipe.read1(4096)
                if not block:break
                room=max(0,4*1024*1024-count);f.write(block[:room]);count+=min(room,len(block))
                if len(block)>room:overflow.set()
    try:
        if not 0<=timeout<=180:raise ValueError('Timeout must be 0..180 seconds')
        owner=Job(1536,parent or os.getppid())
        p=subprocess.Popen(command,cwd=job,stdout=subprocess.PIPE,stderr=subprocess.PIPE,creationflags=subprocess.CREATE_NO_WINDOW|0x4)
        owner.assign(p);(job/'running.json').write_text(__import__('json').dumps(dict(pid=p.pid,parent_pid=parent or os.getppid(),job_object=True,executable=str(command[0]))))
        threads=[threading.Thread(target=drain,args=(pipe,job/name),daemon=True) for pipe,name in [(p.stdout,'stdout.txt'),(p.stderr,'stderr.txt')]]
        for thread in threads:thread.start()
        resume_owned_process(p.pid)
        deadline=time.monotonic()+timeout
        while p.poll() is None:
            peak=max(peak,peak_working_set(p))
            if (job/'cancel').exists():state='cancelled'
            elif not owner.owner_alive():state='owner_exited'
            elif time.monotonic()>deadline:state='timeout'
            elif overflow.is_set() or output_overflow():state='output_limit'
            else:time.sleep(.02);continue
            p.terminate();break
        try:p.wait(timeout=5)
        except subprocess.TimeoutExpired:p.kill();p.wait(timeout=5)
        for thread in threads:thread.join(timeout=5)
        if overflow.is_set() or output_overflow():state='output_limit'
        if state=='failed':state='completed' if p.returncode==0 else 'failed'
    except Exception as e:error=str(e)
    finally:
        if p and p.poll() is None:p.kill();p.wait(timeout=5)
        commit=owner.peak() if owner else 0
        if owner:owner.close()
    return dict(state=state,exit_code=p.returncode if p else None,error=error,seconds=time.monotonic()-start,started_utc=started,ended_utc=datetime.now(timezone.utc).isoformat(),peak_working_set_bytes=peak,peak_memory_bytes=commit,job_object=owner is not None)
