"""Refresh Cleanup 1.0 measurements without touching engineering artifacts."""
import gzip, hashlib, json, pathlib, subprocess, sys, time
from cleanup_repository import ROOT, OUT, inventory, save, sha
def read(p):return json.loads(p.read_text(encoding='utf-8'))
baseline=read(OUT/'baseline-inventory.json')
deleted=read(OUT/'deleted-manifest.json')
original=read(ROOT/'docs/architecture/evidence/cad24-completion/final-receipt.json')
pins={p:dict(expected=v['after'],actual=sha(pathlib.Path(p))) for p,v in original['pinned_binaries'].items()}
save(OUT/'pinned-binaries.json',pins)
if not (OUT/'runtime-import-audit.json').exists():
    audit=subprocess.run([sys.executable,'native/occt/audit_runtime.py'],cwd=ROOT,capture_output=True)
    (OUT/'runtime-import-audit.json').write_bytes(audit.stdout)
    (OUT/'runtime-import-audit.stderr.txt').write_bytes(audit.stderr)
else:
    audit=subprocess.CompletedProcess([],0 if not read(OUT/'runtime-import-audit.json')['missing'] else 1)
focused=subprocess.run([sys.executable,'scripts/source_files.py'],cwd=ROOT,capture_output=True)
(OUT/'source-files.txt').write_bytes(focused.stdout)
regpath=OUT/'regressions-retry/receipt.json'
reg=read(regpath) if regpath.exists() else dict(passed=False,state='incomplete')
campaign=[]
for p in (ROOT/'docs/architecture/evidence/cad24-completion').glob('*-latest.json'):
    if p.stat().st_mtime>= (OUT/'baseline-inventory.json').stat().st_mtime:
        campaign.append(dict(path=p.relative_to(ROOT).as_posix(),receipt=read(p)))
sources=read(OUT/'source-hashes.json')
references=[]
for p in sources:
    if pathlib.Path(p).suffix not in {'.py','.gd','.ps1','.json','.cpp','.hpp'}:continue
    for number,line in enumerate((ROOT/p).read_text(encoding='utf-8',errors='replace').splitlines(),1):
        if any(token in line for token in ['.tools/','D:/msys64','D:/Downloads','D:\\Downloads','occt-sdk','cad24-completion','docs/architecture/evidence']):
            references.append(dict(source=p,line=number,text=line[:1000]))
save(OUT/'dependency-references.json',references)
jobs=[]
for f in baseline['files']:
    if f['path'].endswith('.unicore-managed-job.json'):
        p=ROOT/f['path']
        try:jobs.append(dict(path=f['path'],record=read(p)))
        except (OSError,ValueError):jobs.append(dict(path=f['path'],state='unavailable; preserved'))
save(OUT/'managed-job-protection.json',jobs)
changed=[p for p,h in sources.items() if not (ROOT/p).exists() or sha(ROOT/p)!=h]
after=inventory();save(OUT/'after-inventory.json',after)
def size(inv,p):return sum(f['size'] for f in inv['files'] if f['path'].startswith(p))
reclaimed=sum(f['size'] for f in deleted if not (ROOT/f['path']).exists())
receipt=dict(verdict='PARTIAL',reason='Only source-backed bytecode cleanup qualified; SDK slimming and external evidence archival deferred.',branch='master',head=original.get('current_head'),before_bytes=baseline['bytes'],after_bytes=after['bytes'],net_bytes_reduction=baseline['bytes']-after['bytes'],net_percent_reduction=100*(baseline['bytes']-after['bytes'])/baseline['bytes'],deleted_bytes=sum(f['size'] for f in deleted),deleted_bytes_still_absent=reclaimed,before_files=baseline['count'],after_files=after['count'],removed_files=len(deleted),relocated_files=0,preserved_baseline_files=sum((ROOT/f['path']).exists() for f in baseline['files']),source_hash_changes=changed,pinned_binaries=pins,regressions=reg,campaign=campaign,runtime_audit_exit=audit.returncode,archive=None,relocation_disk_savings=0,compressed_evidence_bytes=0,inventory_scope='Readable regular files including .git; reparse points excluded; access denied directories omitted: counts are lower bounds',directories_before=list(baseline['directories'].items())[:20],directories_after=list(after['directories'].items())[:20],groups={p:dict(before=size(baseline,p),after=size(after,p)) for p in ['.tools/occt-sdk/','.tools/occt-sdk/ucrt64/bin/','docs/architecture/evidence/']},context=dict(focused_file_count=len(focused.stdout.splitlines()),baseline_file_count=baseline['count'],mechanism='explicit source discovery script, AGENTS.md, Python Git ignore; no claimed .codexignore enforcement'),limitations=['No SDK reconstruction attempted: external D:/msys64 compiler dependency retained','No external archive destination established: all historical evidence preserved','Reference audit limited to bytecode source backing; no SDK or engineering artifacts deleted','Inventory access-denied omissions prevent exact whole-project accounting','Campaign results listed are fresh latest receipts; missing stages must not be treated as passing'])
receipt['numerical_cases']={name:dict(path=p,rows=len(read(ROOT/p))) for name,p in {'cad23':'docs/architecture/evidence/cad23/numerical.json','cad24':'docs/architecture/evidence/cad24-completion/structural-numerical.json'}.items()}
receipt['dependency_references_file']='dependency-references.json'
receipt['managed_job_protection_file']='managed-job-protection.json'
receipt['regression_receipt']=regpath.relative_to(ROOT).as_posix()
receipt['initial_regression_attempt']='regressions/receipt.json; user-profile write errors; preserved for diagnosis'
receipt['intentional_maintenance_changes']=[p for p in changed if p=='scripts/cleanup_repository.py']
receipt['unexpected_source_hash_changes']=[p for p in changed if p!='scripts/cleanup_repository.py']
save(OUT/'final-receipt.json',receipt)
lines=['# Repository Cleanup & Optimization 1.0 — PARTIAL','',receipt['reason'],'',f"Readable baseline: {baseline['bytes']:,} bytes / {baseline['count']:,} files. After: {after['bytes']:,} bytes / {after['count']:,} files.",f"Net reduction: {receipt['net_bytes_reduction']:,} bytes ({receipt['net_percent_reduction']:.4f}%). Recorded bytecode deletions: {receipt['deleted_bytes']:,} bytes / {len(deleted)} files; {reclaimed:,} bytes remain absent after testing.",'','Measurements include new inventories and test outputs. Logical file lengths are measured, not allocated NTFS blocks. Inaccessible directories are omitted; the total is a lower bound. Relocations, compression savings, external archives and SDK removals: zero. No claim of substantial space savings.','',f"Default regressions: {json.dumps(reg)}",f"Pre-existing source hash changes: {len(changed)}. Seven original binary hashes preserved: {all(v['actual']==v['expected'] for v in pins.values())}.",'','## Evidence and recovery','','See [final receipt](evidence/cleanup1/final-receipt.json), [plan](cleanup-plan.json), [deletion manifest](evidence/cleanup1/deleted-manifest.json), [baseline inventory](evidence/cleanup1/baseline-inventory.json), [after inventory](evidence/cleanup1/after-inventory.json), [source hashes](evidence/cleanup1/source-hashes.json), and [exact duplicate candidates](evidence/cleanup1/duplicate-candidates.json). Python recreates removed bytecode on import. Each deletion records source, hash, size and Git status. No production source, SDK package, job, screenshot, solver result or historical evidence was removed.','', '## Remaining work and limitations','',*['- '+x for x in receipt['limitations']],'','The PE import audit traverses executable/DLL imports with objdump and reports missing modules. Static imports alone do not establish dynamic-loading completeness. Existing runtime verification checks all 243 SDK DLLs plus external winpthread; these remain intact. Build/provision scripts and package hashes remain unchanged. Offline execution paths are unchanged.','', 'The current campaign uses existing runners, which also write established latest receipts and generate fresh jobs. All attempts remain available. No historical PASS is substituted for a new run. Complete campaign details and actual exit codes are in the machine receipt.','', '## Largest directories after cleanup','',*['- '+p+': '+str(n)+' bytes' for p,n in receipt['directories_after'][:12]],'', '## Context discovery','',f"Focused source inventory lists {receipt['context']['focused_file_count']} paths versus {baseline['count']} readable baseline files. Fixtures and required configuration remain discoverable. AGENTS.md provides architecture and testing guidance; explicit shell reads can still access ignored files. No unsupported .codexignore behavior is assumed."]
lines.extend(['','## Fresh acceptance campaign','',f"Recorded {len(campaign)} fresh stage receipts. Numerical rows: {json.dumps(receipt['numerical_cases'])}.",'','| Stage | Outcome | Exit |','| --- | --- | --- |'])
for stage in sorted(campaign,key=lambda s:s['path']):
    r=stage['receipt']
    if isinstance(r,dict):lines.append(f"| {r.get('name',stage['path'])} | {r.get('outcome','unknown')} | {r.get('exit_code')} |")
lines.extend(['', 'The cleanup inventory script was created before the baseline and later updated with rerun protection and scan-error reporting. Its intentional hash change is recorded separately from user sources. Unexpected source changes: '+str(receipt['unexpected_source_hash_changes'])+'.',''])
(ROOT/'docs/maintenance/REPOSITORY_CLEANUP_1_0.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({k:receipt[k] for k in ['verdict','before_bytes','after_bytes','removed_files','deleted_bytes','regressions']}))
