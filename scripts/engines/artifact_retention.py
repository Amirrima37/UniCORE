"""Opt-in managed job retention; historical/unregistered artifacts are untouched."""
import json,os,time,uuid,stat,math,ctypes as C
from pathlib import Path
import msvcrt
MARKER='.unicore-managed-job.json'
def _owner(pid):
    k=C.WinDLL('kernel32',use_last_error=True);k.OpenProcess.argtypes=[C.c_ulong,C.c_int,C.c_ulong];k.OpenProcess.restype=C.c_void_p
    k.WaitForSingleObject.argtypes=[C.c_void_p,C.c_ulong];k.CloseHandle.argtypes=[C.c_void_p];k.GetProcessTimes.argtypes=[C.c_void_p,C.c_void_p,C.c_void_p,C.c_void_p,C.c_void_p]
    handle=k.OpenProcess(0x101000,False,pid)
    if not handle:return (False,None) if C.get_last_error()==87 else (True,None)
    try:
        if k.WaitForSingleObject(handle,0)!=258:return False,None
        stamps=[C.c_uint64() for _ in range(4)]
        return True,stamps[0].value if k.GetProcessTimes(handle,*[C.byref(x) for x in stamps]) else None
    finally:k.CloseHandle(handle)
def _plain(path):return not bool(path.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT)
def _safe_tree(path):
    return _plain(path) and all(_plain(p) for p in path.rglob('*'))
def _remove_managed_tree(path):
    """Keep the management marker until child deletion succeeds, enabling retry."""
    marker=path/MARKER;record=marker.read_text();root=path.resolve()
    for child in sorted(path.rglob('*'),key=lambda p:len(p.parts),reverse=True):
        if child==marker:continue
        if not _plain(child) or not child.resolve().is_relative_to(root):raise OSError('Retention reparse/containment change')
        if child.is_dir():child.rmdir()
        else:child.unlink()
    marker.unlink()
    try:path.rmdir()
    except OSError:
        marker.write_text(record)
        raise
def sweep(base,quota=None,age=None,grace=600):
    base=Path(base).resolve();quota=int(os.environ.get('UNICORE_JOB_QUOTA_BYTES',2*1024**3)) if quota is None else quota
    age=float(os.environ.get('UNICORE_JOB_RETENTION_DAYS','7'))*86400 if age is None else age
    if quota<0 or not math.isfinite(age) or age<0 or not math.isfinite(grace) or grace<0:raise ValueError('Invalid retention configuration')
    report=dict(bytes_before=0,bytes_after=0,protected_bytes=0,removed=[],errors=[],quota_bytes=quota)
    lock=base/'.unicore-retention.lock'
    if lock.exists() and not _plain(lock):raise ValueError('Retention lock reparse point rejected')
    with lock.open('a+b') as handle:
        handle.seek(0);handle.write(b'0');handle.flush();handle.seek(0)
        try:msvcrt.locking(handle.fileno(),msvcrt.LK_NBLCK,1)
        except OSError:return dict(report,busy=True)
        try:
            candidates=[];now=time.time()
            paths=list(base.glob('gmsh_*'))+list(base.glob('.cad24-trash-*'))
            for folder in ['cad_geometry','calculix_jobs']:
                parent=base/folder
                if parent.exists() and _plain(parent):paths.extend(parent.iterdir())
            for path in paths:
                try:
                    if not path.is_dir() or not (path/MARKER).is_file():continue
                    if not _safe_tree(path) or path.resolve().is_relative_to(base) is False:continue
                    marker=path/MARKER
                    if not marker.is_file():continue
                    record=json.loads(marker.read_text())
                    if record.get('state')=='active' and record.get('owner_pid'):
                        alive,stamp=_owner(int(record['owner_pid']))
                        same_owner=alive and (record.get('owner_creation') is None or stamp is None or record['owner_creation']==stamp)
                        if not same_owner:
                            record=dict(state='completed',completed_at=marker.stat().st_mtime,recovered_abandoned_job=True)
                            temp=path/(MARKER+'.tmp');temp.write_text(json.dumps(record));temp.replace(marker)
                    size=sum(p.stat().st_size for p in path.rglob('*') if p.is_file());report['bytes_before']+=size
                    if record.get('state')!='completed' or (path/'PINNED').exists() or (path/'ARCHIVED').exists():report['protected_bytes']+=size;continue
                    completed=record['completed_at']
                    if now-completed<grace:report['protected_bytes']+=size;continue
                    candidates.append((completed,path,size))
                except (OSError,ValueError,KeyError) as e:report['errors'].append(str(e))
            retained=report['bytes_before']
            for completed,path,size in sorted(candidates):
                if now-completed<age and retained-report['protected_bytes']<=quota:continue
                try:
                    # Recheck containment and reparse points immediately before rename.
                    if not path.resolve().is_relative_to(base) or not _safe_tree(path):continue
                    trash=path.with_name('.cad24-trash-'+uuid.uuid4().hex)
                    path.rename(trash);_remove_managed_tree(trash)
                    retained-=size;report['removed'].append(str(path))
                except OSError as e:report['errors'].append(str(e))
            report['bytes_after']=retained
            report['quota_accounted_bytes']=retained-report['protected_bytes']
            report['quota_met']=report['quota_accounted_bytes']<=quota
        finally:handle.seek(0);msvcrt.locking(handle.fileno(),msvcrt.LK_UNLCK,1)
    statistics=base/'.unicore-retention-statistics.json'
    if statistics.exists() and not _plain(statistics):report['errors'].append('Retention statistics reparse point rejected')
    else:
        temporary=base/('.retention-statistics-'+uuid.uuid4().hex+'.tmp')
        try:temporary.write_text(json.dumps(report));temporary.replace(statistics)
        except OSError as e:
            report['errors'].append(str(e))
            try:temporary.unlink(missing_ok=True)
            except OSError:pass
    return report
def begin(job):
    job=Path(job).resolve()
    # Only the established Workbench job namespaces opt into management.
    base=job.parent.parent if job.parent.name in ['cad_geometry','calculix_jobs'] else job.parent if job.name.startswith('gmsh_') else None
    if base is None:return
    report=sweep(base)
    if not report.get('busy') and not report.get('quota_met',True):raise ValueError('Managed job artifact quota cannot be enforced; inspect retention statistics and close locked artifacts')
    _,stamp=_owner(os.getpid())
    (job/MARKER).write_text(json.dumps(dict(state='active',owner_pid=os.getpid(),owner_creation=stamp)))
def finish(job):
    job=Path(job)
    if (job/MARKER).exists():
        temp=job/(MARKER+'.tmp');temp.write_text(json.dumps(dict(state='completed',completed_at=time.time())))
        # Concurrent sweeps briefly open the marker on Windows. Preserve the
        # active marker on failure: owner-exit recovery can reclaim it safely.
        deadline=time.monotonic()+1
        while True:
            try:temp.replace(job/MARKER);break
            except PermissionError as error:
                if time.monotonic()>=deadline:
                    (job/'retention-warning.txt').write_text(str(error));break
                time.sleep(.02)
