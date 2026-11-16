"""Staged migration: copy/verify first, remove originals only in commit mode."""
from storage_cleanup11 import *
import shutil,uuid,ctypes
OUT=ROOT/'docs/maintenance/evidence/external-migration'
OUT.mkdir(parents=True,exist_ok=True)
BASE=Path('D:/PROJECT')
PAIRS=[('.tools/occt-sdk','SDK/OCCT'),('.tools/godot472-migration','GODOT/TEST_ENVIRONMENTS/godot472-migration')]
def write(n,d):(OUT/n).write_text(json.dumps(d,indent=2),encoding='utf-8')
def entries(root):
 found={}
 for base,dirs,files in os.walk(root,followlinks=False,onerror=lambda e:None):
  if Path(base)==root and 'occt' in root.name.lower():dirs[:]=[d for d in dirs if d!='jobs']
  for name in dirs+files:
   p=Path(base)/name
   if p.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:raise RuntimeError('Reparse point requires review: '+str(p))
  for n in files:
   p=Path(base)/n;found[p.relative_to(root).as_posix()]=p.stat().st_size
 return found
if sys.argv[1]=='copy':
 # Called with escalation so process inspection and external destination writes are authorized.
 probe=subprocess.run(['powershell','-NoProfile','-Command',"Get-Process | Where-Object {$_.ProcessName -match '^(Godot.*|unicore_occt_worker|unicore_solver|ccx|g\+\+|cc1plus|cc1|scons)$'} | Select-Object -ExpandProperty ProcessName"],capture_output=True,text=True)
 if probe.stdout.strip():raise RuntimeError('Close active workers/build/editor first: '+probe.stdout)
 for p in ['SDK/OCCT','SDK/COMPILERS','SDK/BUILD_TOOLS','SDK/OTHER','GODOT/TEST_ENVIRONMENTS','GODOT/CACHE','GODOT/USER_DATA','CACHE/DOWNLOADS','CACHE/BUILD','CACHE/TEMP','TEST_OUTPUTS/CAD','TEST_OUTPUTS/NATIVE','TEST_OUTPUTS/GUI']:
  # OCCT final target must be absent for the atomic staging rename.
  if p!='SDK/OCCT':(BASE/p).mkdir(parents=True,exist_ok=True)
 baseline=scan();write('before.json',{k:v for k,v in baseline.items() if k!='files'})
 needed=sum(sum(entries(ROOT/src).values()) for src,_ in PAIRS)
 if shutil.disk_usage(BASE).free<needed+1024**3:raise RuntimeError('Insufficient destination free space')
 manifest=json.loads((OUT/'manifest.json').read_text()) if (OUT/'manifest.json').exists() else []
 for rel,destrel in PAIRS:
  src=ROOT/rel;dest=BASE/destrel
  assert src.resolve().is_relative_to(ROOT) and dest.resolve().is_relative_to(BASE)
  if dest.exists():
   existing=next((r for r in manifest if r['source']==str(src) and r['destination']==str(dest)),None)
   if existing and entries(dest)==existing['files']:
    print('Previously verified destination retained: '+str(dest),flush=True);continue
   raise RuntimeError('Destination exists; refusing overwrite: '+str(dest))
  original=entries(src)
  previous=list(dest.parent.glob(dest.name+'.staging-*'))
  stage=previous[0] if len(previous)==1 else dest.with_name(dest.name+'.staging-'+uuid.uuid4().hex)
  print('Copying '+str(src)+' -> '+str(stage),flush=True)
  if not stage.exists():shutil.copytree(src,stage,ignore=lambda directory,names:['jobs'] if Path(directory)==src and 'occt' in src.name else [])
  copied=entries(stage)
  if copied!=original:raise RuntimeError('Copy inventory mismatch; originals retained')
  hashes={}
  for name in original:
   if Path(name).suffix.lower() in ['.exe','.dll','.ucae','.brep'] or name.endswith(('build-manifest.json','.PKGINFO')):
    a=sha(src/name);b=sha(stage/name)
    if a!=b:raise RuntimeError('Critical hash mismatch: '+name)
    hashes[name]=a
  stage.rename(dest)
  denied=[]
  for _ in os.walk(src,onerror=lambda e:denied.append(str(e))):pass
  manifest.append(dict(source=str(src),destination=str(dest),files=original,bytes=sum(original.values()),critical_hashes=hashes,source_removed=False,excluded='Inaccessible scratch directories retained in source; SDK jobs excluded' if 'occt' in src.name else 'Inaccessible nested scratch directories retained in source',inaccessible=denied))
  write('manifest.json',manifest);print('Verified '+str(dest)+': '+str(sum(original.values()))+' bytes',flush=True)
elif sys.argv[1]=='commit':
 validation=json.loads((OUT/'validation.json').read_text())
 if not validation['passed']:raise RuntimeError('Validation has not passed; originals retained')
 manifest=json.loads((OUT/'manifest.json').read_text())
 for record in manifest:
  src=Path(record['source']);dest=Path(record['destination'])
  assert src.resolve().is_relative_to(ROOT) and dest.resolve().is_relative_to(BASE)
  current=entries(src)
  if any(n not in record['files'] or size!=record['files'][n] for n,size in current.items()):raise RuntimeError('Original changed; do not remove '+str(src))
  for name,h in record['critical_hashes'].items():
   # SDK build qualification may replace worker build artifacts; all original
   # bytes are retained in destination migration-original-build/ for recovery.
   if sha(dest/name)!=h:
    saved=dest/'migration-original-build'/name
    if not saved.is_file() or sha(saved)!=h:raise RuntimeError('Destination changed without verified original backup: '+name)
  # Check source tree containment/reparse points again, then remove only copied files.
  retained=[]
  for name in record['files']:
   p=src/name
   if not p.exists():continue
   try:
    if p.stat().st_file_attributes & stat.FILE_ATTRIBUTE_READONLY:p.chmod(stat.S_IWRITE)
    p.unlink()
   except OSError as e:retained.append(dict(path=str(p),error=str(e)))
  for base,dirs,files in os.walk(src,topdown=False):
   for n in dirs:
    try:(Path(base)/n).rmdir()
    except OSError:pass
  try:src.rmdir()
  except OSError:pass
  record['source_removed']=not retained;record['retained_files']=retained;write('manifest.json',manifest)
  print('Removed verified original '+str(src),flush=True)
