"""Owned bounded Gmsh child: timeout, owner death, memory, capped logs and responses."""
import sys,subprocess,time,json,os,threading
from pathlib import Path
from owned_mesh_job import Job,resume_owned_process
from mesh_config import validate
job=Path(sys.argv[1]).resolve();state='failed';code=None;process=None;containment=None;peak=0;error='';start=time.monotonic()
from artifact_retention import begin,finish
begin(job)
overflow=threading.Event()
def drain(pipe,path):
    written=0
    with path.open('wb') as out:
        while True:
            data=pipe.read(4096)
            if not data:break
            remaining=4*1024*1024-written
            if remaining>0:out.write(data[:remaining]);written+=min(remaining,len(data))
            if len(data)>remaining:overflow.set()
try:
    source=job/'study.json'
    if source.stat().st_size>128*1024*1024:raise ValueError('Gmsh request exceeds 128 MiB')
    study=json.loads(source.read_text(encoding='utf-8-sig'));config=study['parts'][0].get('mesh_settings')
    if config is not None:validate(config)
    timeout=float(sys.argv[3]);parent=int(sys.argv[4]) if len(sys.argv)>4 else os.getppid()
    if not 0<=timeout<=180:raise ValueError('Gmsh timeout must be 0..180 seconds')
    containment=Job(int(config['memory_mb']) if config else 1536,parent)
    temp=job/'kernel-temp';temp.mkdir();env=os.environ.copy();env['UNICORE_MESH_JOB_TEMP']=str(temp)
    process=subprocess.Popen([sys.executable,str(Path(__file__).with_name('gmsh_study.py')),str(source),str(job/'mesh.json'),sys.argv[2]],stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,creationflags=subprocess.CREATE_NO_WINDOW|0x4)
    containment.assign(process);(job/'running.json').write_text(json.dumps(dict(pid=process.pid,parent_pid=parent,job_object=True)))
    readers=[threading.Thread(target=drain,args=(pipe,job/name)) for pipe,name in [(process.stdout,'stdout.txt'),(process.stderr,'stderr.txt')]]
    for reader in readers:reader.start()
    resume_owned_process(process.pid)
    deadline=time.monotonic()+timeout
    while process.poll() is None:
        if (job/'cancel').exists():state='cancelled'
        elif not containment.owner_alive():state='owner_exited'
        elif time.monotonic()>deadline:state='timeout'
        elif overflow.is_set() or ((job/'mesh.json').exists() and (job/'mesh.json').stat().st_size>192*1024*1024):state='output_limit'
        else:time.sleep(.02);continue
        process.terminate();break
    try:code=process.wait(timeout=5)
    except subprocess.TimeoutExpired:process.kill();code=process.wait()
    for reader in readers:reader.join(timeout=5)
    if overflow.is_set():state='output_limit'
    if (job/'mesh.json').exists() and (job/'mesh.json').stat().st_size>192*1024*1024:state='output_limit'
    if state=='failed':state='completed' if code==0 and (job/'mesh.json').exists() else 'failed'
except Exception as e:error=str(e)
finally:
    if process and process.poll() is None:process.kill();code=process.wait(timeout=5)
    if containment:peak=containment.peak();containment.close()
receipt=dict(state=state,exit_code=code,error=error,seconds=time.monotonic()-start,peak_memory_bytes=peak,job_object=containment is not None)
tmp=job/'receipt.tmp';tmp.write_text(json.dumps(receipt));tmp.replace(job/'receipt.json')
finish(job)
raise SystemExit(0 if state=='completed' else 1)
