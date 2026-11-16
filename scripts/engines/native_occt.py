"""Isolated OCCT process; only bounded job-local BREP/JSON crosses the ABI."""
import hashlib,json,os,subprocess,tempfile,uuid,shutil,time
from contextlib import contextmanager
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
from development_paths import sdk_root
SDK=sdk_root()
EXE=SDK/'unicore_occt_worker.exe'
_verified=False
def verify_installation():
    global _verified
    if _verified:return
    manifest=json.loads((SDK/'build-manifest.json').read_text())
    def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
    if manifest.get('schema')!=1 or sha(EXE)!=manifest['worker_sha256'] or sha(ROOT/'native/occt/worker.cpp')!=manifest['source_sha256']:raise ValueError('Native worker build pin mismatch; rebuild the isolated OCCT SDK')
    for name,expected in manifest['dlls'].items():
        if Path(name).name!=name or sha(SDK/'ucrt64/bin'/name)!=expected:raise ValueError('Native OCCT runtime pin mismatch: '+name)
    if sha(Path('D:/msys64/ucrt64/bin/libwinpthread-1.dll'))!=manifest['external_winpthread_sha256']:raise ValueError('Native winpthread prerequisite pin mismatch')
    _verified=True
@contextmanager
def workspace():
    parent=Path(os.environ.get('UNICORE_CAD_JOB_TEMP') or os.environ.get('UNICORE_MESH_JOB_TEMP') or SDK/'jobs')
    parent.mkdir(parents=True,exist_ok=True)
    job=Path(tempfile.mkdtemp(prefix='occt-',dir=parent))
    try:yield str(job)
    except Exception as e:raise ValueError(str(e)+'; native diagnostics retained: '+str(job)) from e
    else:
        if not job.resolve().is_relative_to(parent.resolve()):raise ValueError('Native temporary containment failure')
        deadline=time.monotonic()+1
        while job.exists():
            try:shutil.rmtree(job)
            except OSError as e:
                if time.monotonic()<deadline:time.sleep(.02);continue
                # Cleanup is separate from geometry validity. The enclosing
                # managed job retains and later reclaims these diagnostics.
                (parent/('cleanup-warning-'+job.name+'.json')).write_text(json.dumps(dict(path=str(job),error=str(e))))
                break
def run(raw=b'',action='validate',tool=None,matrix=None,feature='geometry',dimensions=None):
    verify_installation()
    if (not raw and dimensions is None) or len(raw)>64*1024*1024:raise ValueError('Native BREP size limit')
    with workspace() as directory:
        job=Path(directory);(job/'input.brep').write_bytes(raw)
        q=dict(schema=1,units='m',input='input.brep',action=action,operation_id=str(uuid.uuid4()),feature_id=feature,input_hashes=[hashlib.sha256(raw).hexdigest()])
        if tool is not None:
            if len(tool)>64*1024*1024:raise ValueError('Native tool size limit')
            (job/'tool.brep').write_bytes(tool);q['tool']='tool.brep';q['input_hashes'].append(hashlib.sha256(tool).hexdigest())
        if matrix is not None:q['matrix']=matrix
        if dimensions is not None:q['dimensions']=dimensions
        (job/'request.json').write_text(json.dumps(q,allow_nan=False))
        env=os.environ.copy();env['PATH']=str(SDK/'ucrt64/bin')+os.pathsep+'D:/msys64/ucrt64/bin'+os.pathsep+env.get('PATH','')
        from owned_mesh_job import Job,resume_owned_process
        timeout=float(os.environ.get('UNICORE_OCCT_TIMEOUT_S','40'))
        if not 0<=timeout<=120:raise ValueError('Native timeout must be 0..120 seconds')
        containment=Job(768,os.getpid());p=None;started=time.monotonic();peak=0
        with (job/'stdout.txt').open('wb') as out,(job/'stderr.txt').open('wb') as err:
            try:
                p=subprocess.Popen([str(EXE),'request.json'],cwd=job,env=env,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW|0x4)
                containment.assign(p)
                (job/'running.json').write_text(json.dumps(dict(pid=p.pid,action=action,operation_id=q['operation_id'])))
                resume_owned_process(p.pid)
                while p.poll() is None:
                    if not containment.owner_alive():raise ValueError('Native OCCT owner exited')
                    if os.environ.get('UNICORE_NATIVE_CANCEL_FILE') and Path(os.environ['UNICORE_NATIVE_CANCEL_FILE']).exists():raise ValueError('Native OCCT cancelled')
                    if time.monotonic()-started>timeout:raise ValueError('Native OCCT timeout')
                    if any(f.stat().st_size>4*1024*1024 for f in [job/'stdout.txt',job/'stderr.txt']):raise ValueError('Native log bound')
                    for name,limit in [('output.brep.tmp',64*1024*1024),('output.brep',64*1024*1024),('response.json.tmp',16*1024*1024),('response.json',16*1024*1024)]:
                        try:
                            if (job/name).stat().st_size>limit:raise ValueError('Native output bound: '+name)
                        except FileNotFoundError:pass
                    time.sleep(.02)
                peak=containment.peak()
            finally:
                containment.close()
                if p is not None:
                    if p.poll() is None:p.kill()
                    p.wait(timeout=5)
                    receipt=job/'process-receipt.tmp'
                    receipt.write_text(json.dumps(dict(pid=p.pid,exit_code=p.returncode,seconds=time.monotonic()-started,job_object=True)))
                    receipt.replace(job/'process-receipt.json')
        response=job/'response.json'
        if not response.exists():raise ValueError('Native OCCT failed to publish response; exit '+str(p.returncode))
        if response.stat().st_size>16*1024*1024:raise ValueError('Native response exceeds bound')
        r=json.loads(response.read_text());r['exit_code']=p.returncode
        r['process']=dict(pid=p.pid,exit_code=p.returncode,peak_commit_bytes=peak,seconds=time.monotonic()-started,job_object=True)
        if p.returncode or not r.get('ok'):
            if action=='step' and r.get('before',{}).get('solid_count',1)!=1:raise ValueError('STEP assemblies/shells unsupported: exactly one native solid required')
            raise ValueError('Native OCCT: '+str(r.get('error','kernel failure')))
        if r.get('schema')!=1 or r.get('worker_version')!='1' or r.get('units')!='m' or r.get('occt_version')!='7.8.1' or r.get('operation_id')!=q['operation_id'] or r.get('input_hashes')!=q['input_hashes']:raise ValueError('Native operation identity/version mismatch')
        if action=='transform' and r.get('validation',{}).get('status')=='VALID':
            before=r['before'];after=r['validation'];m=matrix
            det=m[0]*(m[5]*m[10]-m[6]*m[9])-m[1]*(m[4]*m[10]-m[6]*m[8])+m[2]*(m[4]*m[9]-m[5]*m[8])
            expected=abs(det)*before['volume']
            if expected<=0 or abs(after['volume']/expected-1)>1e-8:raise ValueError('Unsupported native transform: affine volume invariant failed')
            center=[sum(m[4*i+j]*before['centroid'][j] for j in range(3))+m[4*i+3] for i in range(3)]
            if any(abs(a-b)>max(1e-10,abs(b)*1e-8) for a,b in zip(after['centroid'],center)):raise ValueError('Unsupported native transform: centroid invariant failed')
            if r.get('transform_api')=='BRepBuilderAPI_Transform':
                squared_scale=sum(m[4*i]**2 for i in range(3))
                if abs(after['area']/(before['area']*squared_scale)-1)>1e-8:raise ValueError('Unsupported native transform: area invariant failed')
        output=job/'output.brep'
        result=output.read_bytes() if output.exists() else None
        if result is not None:
            if len(result)>64*1024*1024:raise ValueError('Native output limit')
            if r.get('output_sha256')!=hashlib.sha256(result).hexdigest():raise ValueError('Native BREP output SHA-256 mismatch')
        return r,result
def validate_brep(raw):
    result,_=run(raw)
    if result['validation']['status']!='VALID':raise ValueError('Native OCCT rejected geometry: '+json.dumps(result['validation']))
    return result
