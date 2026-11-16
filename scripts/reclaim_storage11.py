"""Remove unreferenced obsolete build logs; losslessly compress generated output."""
from storage_cleanup11 import *
import ctypes
api=ctypes.WinDLL('kernel32',use_last_error=True)
api.GetCompressedFileSizeW.argtypes=[ctypes.c_wchar_p,ctypes.POINTER(ctypes.c_ulong)]
api.GetCompressedFileSizeW.restype=ctypes.c_ulong
def allocated(p):
 high=ctypes.c_ulong();low=api.GetCompressedFileSizeW(str(p),ctypes.byref(high))
 if low==0xffffffff and ctypes.get_last_error():raise ctypes.WinError(ctypes.get_last_error())
 return (high.value<<32)|low
with gzip.open(OUT/'before-inventory.json.gz','rt',encoding='utf-8') as f:before=json.load(f)
roots=['.tools/hpc22','.tools/hpc23-bench','.tools/godot472-migration/roaming','docs/architecture/evidence','docs/workbench-2']
tracked=set(subprocess.check_output(['git','ls-files'],cwd=ROOT,text=True).splitlines())
refs=[]
for folder in ['docs','scripts','tests','native','core','ui']:
 for base,ds,fs in os.walk(ROOT/folder):
  ds[:]=[d for d in ds if d not in ['godot-cpp','evidence','__pycache__']]
  for n in fs:
   p=Path(base)/n
   if p.suffix in ['.md','.json','.py','.ps1','.gd']:
    try:refs.append(p.read_text(encoding='utf-8',errors='replace'))
    except OSError:pass
reference_text='\n'.join(refs)
deleted=[]
for f in before['files']:
 p=ROOT/f['path']
 # Existing build binaries supersede these old compiler transcripts. Evidence logs stay.
 if p.parent!=ROOT/'.tools' or p.suffix!='.log' or 'build' not in p.name:continue
 if f['path'] in tracked or p.name in reference_text:continue
 data=p.read_text(encoding='utf-8',errors='replace')
 if not any(s in data.lower() for s in ['done building targets','scons: done','linking']):continue
 deleted.append(dict(**f,sha256=sha(p),allocated_before=allocated(p),classification='obsolete compiler transcript',reason='untracked old build transcript; no source/report references; current pinned binaries preserved',recovery='rerun original native build; transcript content intentionally discarded'))
save('deletion-plan.json',deleted)
for f in deleted:
 p=ROOT/f['path'];assert p.resolve().is_relative_to(ROOT) and sha(p)==f['sha256'];p.unlink()
save('deleted-files.json',deleted)
records=[]
for f in before['files']:
 if any(f['path'].startswith(r+'/') for r in roots):
  p=ROOT/f['path'];records.append(dict(path=f['path'],size=f['size'],sha256=sha(p),allocated_before=allocated(p)))
save('compression-before.json',records)
operations=[]
for r in roots:
 p=subprocess.run(['compact.exe','/C','/I','/Q','/S:'+str(ROOT/r),'*'],cwd=ROOT/r,capture_output=True)
 operations.append(dict(path=r,exit_code=p.returncode,stdout=p.stdout.decode(errors='replace'),stderr=p.stderr.decode(errors='replace')))
 save('compression-operations.json',operations)
for f in records:
 p=ROOT/f['path'];f['sha256_after']=sha(p);f['allocated_after']=allocated(p)
save('compression-manifest.json',records)
assert all(f['sha256']==f['sha256_after'] for f in records),'Content changed during compression; inspect manifest'
save('reclaimed-summary.json',dict(deleted_files=len(deleted),deleted_logical_bytes=sum(f['size'] for f in deleted),deleted_allocated_bytes=sum(f['allocated_before'] for f in deleted),compression_logical_bytes=sum(f['size'] for f in records),compression_allocated_before=sum(f['allocated_before'] for f in records),compression_allocated_after=sum(f['allocated_after'] for f in records),compression_disk_bytes_reclaimed=sum(f['allocated_before']-f['allocated_after'] for f in records),hashes_verified=len(records)))
print((OUT/'reclaimed-summary.json').read_text())
