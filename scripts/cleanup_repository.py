"""Conservative cleanup inventory. No job, SDK, or evidence deletion."""
import collections, hashlib, json, os, pathlib, stat, subprocess, sys, time
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/maintenance/evidence/cleanup1'
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest()
def save(p,d):
    p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
def inventory():
    files=[];reparse=[];errors=[]
    for base,dirs,names in os.walk(ROOT,followlinks=False,onerror=lambda e:errors.append(str(e))):
        for n in dirs[:]:
            p=pathlib.Path(base)/n
            if p.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
                reparse.append(str(p.relative_to(ROOT)));dirs.remove(n)
        for n in names:
            p=pathlib.Path(base)/n;s=p.lstat();rel=p.relative_to(ROOT).as_posix()
            if s.st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:reparse.append(rel);continue
            group='G'
            if rel.startswith(('core/','ui/','modules/','shaders/','scenes/','agent/','tests/','scripts/','native/')):group='A'
            if rel.startswith('docs/'):group='E'
            if rel.startswith('.tools/'):group='G'
            if rel.startswith('.tools/occt-sdk/'):group='C'
            if rel.startswith('bin/') or rel.endswith(('.dll','.exe')):group='B'
            if '__pycache__' in p.parts:group='D'
            files.append(dict(path=rel,size=s.st_size,mtime=s.st_mtime,classification=group))
    dirs=collections.Counter();ext=collections.Counter()
    for f in files:
        parts=f['path'].split('/')
        for i in range(1,min(4,len(parts))):dirs['/'.join(parts[:i])]+=f['size']
        ext[pathlib.Path(f['path']).suffix.lower()]+=f['size']
    return dict(bytes=sum(f['size'] for f in files),count=len(files),files=files,reparse_points=reparse,scan_errors=errors,directories=dict(dirs.most_common()),extensions=dict(ext.most_common()),largest_files=sorted(files,key=lambda f:f['size'],reverse=True)[:100])
def main():
    if (OUT/'baseline-inventory.json').exists():
        raise SystemExit('Existing baseline preserved. Use cleanup_report.py to refresh measurements.')
    OUT.mkdir(parents=True,exist_ok=True)
    before=inventory();save(OUT/'baseline-inventory.json',before)
    git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT).decode(errors='replace')
    save(OUT/'git-baseline.json',dict(branch=git('branch','--show-current'),head=git('rev-parse','HEAD'),status=git('status','--porcelain=v1','--untracked-files=all'),ignored=git('ls-files','--others','--ignored','--exclude-standard')))
    # Preserve content hashes for all pre-existing source/configuration, including untracked work.
    sources={f['path']:sha(ROOT/f['path']) for f in before['files'] if f['classification']=='A' and pathlib.Path(f['path']).suffix in {'.py','.gd','.cpp','.hpp','.h','.json','.ps1','.tscn','.tres','.gdshader','.uid'}}
    save(OUT/'source-hashes.json',sources)
    sizes=collections.defaultdict(list)
    for f in before['files']:
        if f['size']>=1024*1024:sizes[f['size']].append(f['path'])
    duplicates=[]
    for size,paths in sizes.items():
        if len(paths)<2:continue
        hashes=collections.defaultdict(list)
        for p in paths:hashes[sha(ROOT/p)].append(p)
        duplicates.extend(dict(size=size,sha256=h,paths=ps,action='preserve: semantic roles not proven redundant') for h,ps in hashes.items() if len(ps)>1)
    save(OUT/'duplicate-candidates.json',duplicates)
    candidates=[]
    for f in before['files']:
        p=ROOT/f['path']
        if p.suffix!='.pyc' or '__pycache__' not in p.parts or not f['path'].startswith(('tests/','native/','scripts/')):continue
        src=p.parent.parent/(p.name.split('.')[0]+'.py')
        if not src.is_file() or git('ls-files','--',f['path']).strip():continue
        compile(src.read_bytes(),str(src),'exec')
        candidates.append(dict(path=f['path'],size=f['size'],classification='D',reason='CPython bytecode with present, compilable source',dependency_references=[src.relative_to(ROOT).as_posix()],reproducibility_status='source compilation verified',risk_level='low',proposed_action='delete bytecode only',recovery_method='Python regenerates on next import',sha256=sha(p),git_status=git('status','--porcelain','--ignored','--',f['path'])))
    save(ROOT/'docs/maintenance/cleanup-plan.json',dict(candidates=candidates,preserved_groups={'A':'all production and test sources','B':'all runtime binaries; installation pins require every SDK DLL','C':'all SDK files and package archives: offline reconstruction not yet independently qualified','D':'jobs preserved; retention defaults unchanged','E':'all historical evidence: no approved external archive destination','F':'duplicate candidates preserved pending semantic audit','G':'unknown and user-owned files preserved'}))
    for c in candidates:
        p=ROOT/c['path']
        assert p.resolve().is_relative_to(ROOT) and sha(p)==c['sha256']
        p.unlink()
    save(OUT/'deleted-manifest.json',candidates)
    save(OUT/'source-integrity.json',dict(changed=[p for p,h in sources.items() if not (ROOT/p).exists() or sha(ROOT/p)!=h],preserved=len(sources)))
    save(OUT/'after-inventory.json',inventory())
    print(json.dumps(dict(before_bytes=before['bytes'],removed_bytes=sum(c['size'] for c in candidates),removed_files=len(candidates))))
if __name__=='__main__':main()
