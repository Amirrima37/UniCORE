from storage_cleanup11 import *
with gzip.open(OUT/'before-inventory.json.gz','rt',encoding='utf-8') as f:before=json.load(f)
references=[]
for folder in ['docs','native','scripts','tests','core','ui']:
 for base,dirs,files in os.walk(ROOT/folder):
  dirs[:]=[d for d in dirs if d not in ['evidence','godot-cpp','__pycache__']]
  for n in files:
   p=Path(base)/n
   if p.suffix in ['.md','.json','.py','.ps1','.gd']:
    try:references.append(p.read_text(encoding='utf-8',errors='replace'))
    except OSError:pass
refs='\n'.join(references)
tracked=set(subprocess.check_output(['git','ls-files'],cwd=ROOT,text=True).splitlines());rows=[]
for f in before['files']:
 p=ROOT/f['path']
 if p.parent!=ROOT/'.tools' or p.suffix!='.log' or 'build' not in p.name or p.name in refs or f['path'] in tracked:continue
 raw=p.read_bytes();text=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8',errors='replace')
 if 'scons: done building targets.' not in text:continue
 rows.append(dict(**f,sha256=sha(p),classification='superseded successful build log',reason='Successful earlier build; current native binaries retained; no source/report references found',recovery='Rebuild with native build scripts to generate a fresh compiler transcript; old transcript intentionally deleted'))
save('old-build-log-deletion-plan.json',rows)
for f in rows:
 p=ROOT/f['path'];assert p.resolve().is_relative_to(ROOT) and sha(p)==f['sha256'];p.unlink()
save('old-build-logs-deleted.json',rows)
print(json.dumps(dict(files=len(rows),bytes=sum(f['size'] for f in rows))))
