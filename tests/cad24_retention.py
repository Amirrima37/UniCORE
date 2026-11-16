import sys,tempfile,json,time
import msvcrt,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from artifact_retention import sweep,MARKER,finish
import threading
with tempfile.TemporaryDirectory(dir=ROOT/'.tools') as tmp:
    base=Path(tmp)
    for name,state in [('gmsh_old','completed'),('gmsh_active','active'),('gmsh_pinned','completed'),('gmsh_archived','completed')]:
        p=base/name;p.mkdir();(p/'payload').write_bytes(b'X'*1000)
        (p/MARKER).write_text(json.dumps(dict(state=state,completed_at=time.time()-10000)))
    (base/'gmsh_pinned/PINNED').touch();(base/'gmsh_archived/ARCHIVED').touch()
    (base/'project.ucae').write_text('preserve');(base/'gmsh_historical').mkdir()
    report=sweep(base,quota=0,age=0,grace=0)
    assert not (base/'gmsh_old').exists()
    for name in ['gmsh_active','gmsh_pinned','gmsh_archived','gmsh_historical','project.ucae']:assert (base/name).exists(),name
    assert len(report['removed'])==1 and not report['errors']
    with (base/'.unicore-retention.lock').open('r+b') as lock:
        msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
        assert sweep(base,quota=0,age=0,grace=0)['busy']
        lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_UNLCK,1)
    failed=base/'gmsh_locked';failed.mkdir();(failed/MARKER).write_text(json.dumps(dict(state='completed',completed_at=time.time()-10000)));(failed/'payload').write_bytes(b'locked')
    with (failed/'payload').open('rb') as held:failed_report=sweep(base,quota=0,age=0,grace=0)
    assert failed_report['errors'],'Expected Windows file-sharing deletion failure'
    recovered=sweep(base,quota=0,age=0,grace=0)
    assert recovered['removed'] and not recovered['errors']
    report['failed_cleanup']=failed_report;report['recovery']=recovered;report['concurrent_sweeper_skipped']=True
    with tempfile.TemporaryDirectory(dir=ROOT/'.tools') as outside:
        target=Path(outside);(target/MARKER).write_text(json.dumps(dict(state='completed',completed_at=time.time()-10000)));(target/'preserve').write_text('outside approved root')
        junction=base/'gmsh_escape'
        p=subprocess.run(['cmd.exe','/c','mklink','/J',str(junction),str(target)],capture_output=True)
        assert p.returncode==0,p.stderr
        sweep(base,quota=0,age=0,grace=0)
        assert (target/'preserve').exists() and junction.exists()
        junction.rmdir()
        report['reparse_escape_protected']=True
    dead=base/'gmsh_abandoned';dead.mkdir();(dead/'payload').write_text('abandoned')
    process=subprocess.run([sys.executable,'-c','pass'],capture_output=True)
    (dead/MARKER).write_text(json.dumps(dict(state='active',owner_pid=4294967294,owner_creation=1)))
    reclaimed=sweep(base,quota=0,age=0,grace=0)
    assert not dead.exists() and reclaimed['removed']
    report['abandoned_job_recovered']=True
    completing=base/'gmsh_completing';completing.mkdir();(completing/MARKER).write_text(json.dumps(dict(state='active')))
    held=(completing/MARKER).open('rb');release=threading.Timer(.15,held.close);release.start()
    finish(completing);release.join()
    assert json.loads((completing/MARKER).read_text())['state']=='completed'
    assert not (completing/'retention-warning.txt').exists()
    report['concurrent_completion_marker_retry']=True
    out=ROOT/'docs/architecture/evidence/cad24-completion/retention.json';out.write_text(json.dumps(report,indent=2))
print('CAD24_RETENTION_PASS')
