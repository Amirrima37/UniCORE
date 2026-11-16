"""Small cleanup validation; bulky output stays in a temporary workspace."""
from storage_cleanup11 import *
import tempfile
OUT=ROOT/'docs/maintenance/evidence/disk-cleanup'
external=Path(tempfile.mkdtemp(prefix='unicore-cleanup-checks-'))
env=os.environ.copy();env.update(APPDATA=str(external/'profile/roaming'),LOCALAPPDATA=str(external/'profile/local'),UNICORE_PYTHON=sys.executable)
godot='D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
original=json.loads((ROOT/'docs/architecture/evidence/cad24-completion/final-receipt.json').read_text())
pins={p:dict(expected=v['after'],actual=sha(Path(p))) for p,v in original['pinned_binaries'].items()}
rows=[]
native="import sys,json; sys.path.insert(0,'scripts/engines'); from native_occt import run; r,b=run(action='box',dimensions=[.1,.2,.1]); assert r['validation']['status']=='VALID'; print('OCCT startup, DLL resolution and native box PASS')"
for name,cmd,timeout in [('native',[sys.executable,'-c',native],120),('editor',[godot,'--headless','--editor','--path',str(ROOT),'--quit'],180),('regressions',[sys.executable,'native/run_regressions.py','--godot',godot,'--output',str(external/'regressions')],1200)]:
 try:
  p=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,timeout=timeout)
  (external/(name+'.stdout.txt')).write_bytes(p.stdout);(external/(name+'.stderr.txt')).write_bytes(p.stderr)
  row=dict(name=name,exit_code=p.returncode,passed=p.returncode==0 and b'SCRIPT ERROR:' not in p.stdout+p.stderr)
 except subprocess.TimeoutExpired as e:row=dict(name=name,exit_code=None,passed=False,error='timeout')
 rows.append(row);print(json.dumps(row),flush=True)
 (OUT/'validation.json').write_text(json.dumps(dict(external_output=str(external),pins=pins,all_pins_unchanged=all(v['expected']==v['actual'] for v in pins.values()),tests=rows),indent=2))
after=scan();(OUT/'after.json').write_text(json.dumps({k:v for k,v in after.items() if k!='files'},indent=2))
before=json.loads((OUT/'before.json').read_text());deleted=json.loads((OUT/'deleted-files.json').read_text())
remaining=[r['path'] for r in deleted if (ROOT/r['path']).exists()]
receipt=dict(before_accessible_bytes=before['accessible_bytes'],after_accessible_bytes=after['accessible_bytes'],net_reduction_bytes=before['accessible_bytes']-after['accessible_bytes'],percent_reduction=100*(before['accessible_bytes']-after['accessible_bytes'])/before['accessible_bytes'],deleted_files=len(deleted),deleted_file_bytes=sum(r['size'] for r in deleted),deleted_paths_regenerated=remaining,before_files=before['file_count'],after_files=after['file_count'],inaccessible_paths=after['errors'],physical_storage_note='Logical file lengths; prior NTFS compression means logical bytes removed do not equal physical disk blocks freed. No relocation or compression counted as deletion.',all_pins_unchanged=all(v['expected']==v['actual'] for v in pins.values()),tests=rows,external_validation_output=str(external),top_remaining=list(after['directories'].items())[:20])
(OUT/'final-receipt.json').write_text(json.dumps(receipt,indent=2))
counts=collections.Counter();sizes=collections.Counter()
for r in deleted:counts[r['classification']]+=1;sizes[r['classification']]+=r['size']
lines=['# Executed disk cleanup','',f"Accessible size: {before['accessible_bytes']:,} → {after['accessible_bytes']:,} bytes. Net reduction: {receipt['net_reduction_bytes']:,} bytes ({receipt['percent_reduction']:.2f}%). Deleted {len(deleted)} files totaling {receipt['deleted_file_bytes']:,} logical bytes.",'','Prior NTFS compression is not counted as deletion or savings in this result. Physical blocks reclaimed are not measured; compressed synthetic zero-filled files occupy much less storage than their logical lengths. Inaccessible paths are listed in the receipt; their sizes remain unknown.','',*['- '+k+': '+str(counts[k])+' files, '+str(sizes[k])+' bytes' for k in counts],'',f"Seven pinned hashes unchanged: {receipt['all_pins_unchanged']}. Validation: {json.dumps(rows)}. Raw logs and regressions are outside the repository: `{external}`.",'','[Deletion manifest](evidence/disk-cleanup/deleted-files.json) records paths, sizes, hashes and recovery instructions. [Final receipt](evidence/disk-cleanup/final-receipt.json) contains exact measurements. Locked local SDK packages were retained and each removed optional static library was verified byte-for-byte against its package member. C++ sources, final binding archives, import libraries, runtime DLLs and executables remain.','', 'Blocked opportunities: managed jobs remain within the existing 2 GiB quota and seven-day retention. Unregistered historical jobs and HPC benchmark results are unique evidence; no external archive destination is configured. SDK archives remain necessary for offline recovery. Project save files and all historical evidence remain. 30% reduction was not safely reached.','', 'Largest remaining directories (nested totals overlap):','',*['- '+p+': '+str(n)+' bytes' for p,n in receipt['top_remaining']]]
(ROOT/'docs/maintenance/EXECUTED_DISK_CLEANUP.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps(receipt),flush=True)
