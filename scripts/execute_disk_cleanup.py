"""Targeted deletions with offline recovery records; no source or evidence removal."""
from storage_cleanup11 import *
import ctypes
OUT=ROOT/'docs/maintenance/evidence/disk-cleanup'
OUT.mkdir(parents=True,exist_ok=True)
before=scan()
savepath=lambda n,d:(OUT/n).write_text(json.dumps(d,indent=2),encoding='utf-8')
savepath('before.json',{k:v for k,v in before.items() if k!='files'})
print(json.dumps(dict(accessible_bytes=before['accessible_bytes'],files=before['file_count'],top30=list(before['directories'].items())[:30],top50=sorted(before['files'],key=lambda f:f['size'],reverse=True)[:50],inaccessible=before['errors'])),flush=True)
tracked=set(subprocess.check_output(['git','ls-files'],cwd=ROOT,text=True).splitlines())
rows=[]
def remove(p,kind,recovery):
 rel=p.relative_to(ROOT).as_posix()
 assert p.resolve().is_relative_to(ROOT) and not p.is_symlink() and rel not in tracked
 if any(x.name in ['PINNED','ARCHIVED'] for parent in [p.parent,*p.parents] if parent.is_relative_to(ROOT) for x in parent.glob('PINNED')):return
 record=dict(path=rel,size=p.stat().st_size,sha256=sha(p),classification=kind,recovery=recovery)
 rows.append(record);savepath('deleted-files.json',rows);p.unlink()
# A: only the retention manager decides which managed jobs have expired.
sys.path.insert(0,str(ROOT/'scripts/engines'))
from artifact_retention import sweep
base=ROOT/'.tools/godot472-migration/roaming/Godot/app_userdata/UniCORE'
jobfiles={f['path']:f for f in before['files'] if f['path'].startswith(base.relative_to(ROOT).as_posix()+'/')}
retention=sweep(base);savepath('retention.json',retention)
for path in retention.get('removed',[]):
 prefix=Path(path).relative_to(ROOT).as_posix()+'/'
 rows.extend(dict(path=p,size=f['size'],classification='expired managed job',recovery='regenerate job from source project; retention defaults applied') for p,f in jobfiles.items() if p.startswith(prefix))
savepath('deleted-files.json',rows)
# Synthetic parser probes are byte-for-byte specified in cad23_persistence.gd.
for folder in base.glob('cad23-oversized-dat-*'):
 if folder.is_symlink() or folder.is_junction():continue
 files=list(folder.iterdir())
 if {p.name for p in files}!={'model.dat','model.inp'}:continue
 if (folder/'model.inp').read_bytes()!=b'adversarial parser fixture':continue
 p=folder/'model.dat'
 if p.stat().st_size!=32*1024*1024+1:continue
 with p.open('rb') as f:
  if any(any(b) for b in iter(lambda:f.read(1024*1024),b'')):continue
 for p in files:remove(p,'regenerable synthetic oversized parser probe','tests/cad23_persistence.gd lines 44-47 recreate exact fixture')
 folder.rmdir()
# C: compilation outputs have matching source inputs; preserve archives and DLLs.
for f in before['files']:
 p=ROOT/f['path']
 if p.suffix!='.o' or not p.exists():continue
 if not f['path'].startswith(('native/src/','.tools/cae-','native/godot-cpp/','.tools/godot-cpp-4.7/')):continue
 stem=p.name.split('.')[0]
 source=next((x for x in [p.with_name(stem+'.cpp'),p.with_name(stem+'.c')] if x.exists()),None)
 if source is None and f['path'].startswith('.tools/cae-'):source=ROOT/'native/src/bindings'/(stem+'.cpp')
 if source is not None and source.is_file() and f['path'] not in tracked:remove(p,'regenerable C++ object','Recompile '+source.relative_to(ROOT).as_posix()+' using native build scripts/SCons; final DLLs and binding archives retained')
# B: remove optional third-party static libraries only after exact comparison with
# a hash-locked local package member. Import libraries/compiler support stay.
sdk=ROOT/'.tools/occt-sdk';lock=json.loads((ROOT/'native/occt/sdk-lock.json').read_text())
targets={f['path']:f for f in before['files'] if Path(f['path']).parent==Path('.tools/occt-sdk/ucrt64/lib') and f['path'].endswith('.a') and not f['path'].endswith('.dll.a') and f['size']>1024*1024 and not any(n in Path(f['path']).name for n in ['gcc','stdc++','mingw','pthread','gomp','quadmath','gfortran','ssp'])}
env=os.environ.copy();env['PATH']='D:/msys64/usr/bin;'+env.get('PATH','')
tar='D:/msys64/usr/bin/tar.exe'
for pkg in lock['packages']:
 if not targets:break
 archive=sdk/pkg.get('local_archive',pkg['filename'])
 if not archive.exists():continue
 listing=subprocess.run([tar,'--force-local','-tf',str(archive)],env=env,capture_output=True)
 if listing.returncode:continue
 members={s.lstrip('./'):s for s in listing.stdout.decode().splitlines()}
 matches=[(rel,members.get(rel[len('.tools/occt-sdk/'):])) for rel in targets]
 matches=[(r,m) for r,m in matches if m]
 if not matches:continue
 if sha(archive)!=pkg['sha256']:continue
 for rel,member in matches:
  extracted=subprocess.run([tar,'--force-local','-xOf',str(archive),member],env=env,capture_output=True)
  if extracted.returncode==0 and hashlib.sha256(extracted.stdout).hexdigest()==sha(ROOT/rel):
   remove(ROOT/rel,'optional static link library; offline package verified',dict(archive=str(archive.relative_to(ROOT)),archive_sha256=pkg['sha256'],member=member,restore='tar --force-local -xf <archive> -C .tools/occt-sdk <member>'))
   del targets[rel]
savepath('deletion-totals.json',dict(files=len(rows),bytes=sum(r['size'] for r in rows),remaining_unverified_static_libraries=list(targets)))
print(json.dumps(dict(deleted_files=len(rows),deleted_bytes=sum(r['size'] for r in rows))),flush=True)
