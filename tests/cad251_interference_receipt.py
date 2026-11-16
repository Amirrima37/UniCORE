"""Seal measured checkpoint evidence; failures prevent a PASS receipt."""
import json,hashlib,sys,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=Path((ROOT/'interference-attempt.txt').read_text())
def read(name):return json.loads((OUT/name).read_text())
def sha(p):
    with Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def original_worker():
    s=(ROOT/'native/occt/worker.cpp').read_text().replace('#include <BRepExtrema_DistShapeShape.hxx>\n','')
    a=s.index('static J classifyPair(');b=s.index('int main(',a);s=s[:a]+s[b:]
    s=s.replace('std::string action=q.at("action");bool isPair=action=="classify_pair";bool isBoolean=action=="fuse"||action=="cut"||action=="common"||isPair;', 'std::string action=q.at("action");bool isBoolean=action=="fuse"||action=="cut"||action=="common";')
    s=s.replace(' if(isPair){response["pair"]=classifyPair(s,read(q.at("tool")));response["ok"]=true;}\n else {\n','')
    s=s.replace('\n }\n }catch(const Standard_Failure','\n }catch(const Standard_Failure')
    return s.replace('\n','\r\n').encode()
matrix=read('native-matrix.json');assert len(matrix)==17 and all(r['result']['classification'] in r['expected'] for r in matrix)
rows=sum([read('solves-'+c+'.json') for c in ['rotated-disjoint','touching','step']],[])
assert len(rows)==24 and all(r['error']<1e-4 and r['imbalance']<1e-5 and r['completion']['state']=='completed' and r['completion']['exit_code']==0 for r in rows)
assert all('INTERFERENCE_SOLVES_PASS' in (OUT/(case+'-final.log')).read_text() for case in ['rotated-disjoint','touching','step'])
assert 'INTERFERENCE_GUI_PASS' in (OUT/'gui.log').read_text()
rejections=read('rejection.json');assert rejections[0]['result']['classification']=='INVALID' and len(rejections)==3
assert 'PLACEMENT_PASS' in (OUT/'placement-B.stdout.txt').read_text()
negative=read('negative.json');assert len(negative)==9 and all(r['passed'] for r in negative)
audit=read('deck-audit.json');assert len(audit)==12 and all(r['disjoint_node_ownership'] and r['no_coupling'] for r in audit)
cache=read('cache.json');assert not cache[0]['cache_hit'] and cache[1]['cache_hit'] and not cache[2]['cache_hit']
regroot=OUT.parent/'default-regressions-sealed';reg=json.loads((regroot/'receipt.json').read_text());assert reg['passed'] and reg['recorded']==28
assert 'ASSEMBLY_PASS' in (ROOT/'assembly-test-c.log').read_text()
baseline=json.loads((ROOT/'docs/architecture/evidence/cad251-native-placement/final-receipt.json').read_text())['preservation_hashes']
pins={p:sha(p) for p in baseline};assert pins==baseline and len(pins)==7
sys.path.insert(0,str(ROOT/'scripts/engines'))
from development_paths import sdk_root
sdk=sdk_root();manifest=json.loads((sdk/'build-manifest.json').read_text())
assert manifest['source_sha256']==sha(ROOT/'native/occt/worker.cpp') and manifest['worker_sha256']==sha(sdk/'unicore_occt_worker.exe')
archives=[]
for directory in OUT.parent.glob('sdk-before-*'):
    previous=json.loads((directory/'build-manifest.json').read_text())
    original=original_worker()
    assert hashlib.sha256(original).hexdigest()==previous['source_sha256']
    (directory/'original-worker.cpp').write_bytes(original)
    assert previous['worker_sha256']==sha(directory/'unicore_occt_worker.exe')
    assert previous['dlls']==manifest['dlls']
    archives.append(dict(directory=str(directory),files={p.name:sha(p) for p in directory.iterdir() if p.is_file()},restoration='With all workers stopped, restore executable and build-manifest.json together; restore original-worker.cpp to native/occt/worker.cpp before using the original sealed worker. SDK packages, lock and DLLs remain in place.'))
assert archives
runtime=json.loads(subprocess.check_output([sys.executable,str(ROOT/'native/occt/audit_runtime.py')],cwd=ROOT,text=True));assert runtime['missing']==[]
(OUT/'runtime-audit.json').write_text(json.dumps(runtime,indent=2))
production=['native/occt/worker.cpp','scripts/engines/native_occt.py','scripts/engines/assembly_interference.py','scripts/engines/gmsh_study.py','core/cae/calculix_workbench.gd','core/cae/assembly_model.gd','ui/cae/cae_workspace.gd']
screenshots={}
for case in ['rotated-disjoint','touching','overlap-rejected']:
    for width in [1280,1920]:
        path=OUT/(case+'-'+str(width)+'.png');assert path.is_file();screenshots[str(path)]=sha(path)
successful=[r['result'] for r in matrix if r['result'].get('receipt')]
perf=dict(native_pair_calls=sum(r['native_calls'] for r in successful),pair_seconds=[r['seconds'] for r in successful],peak_native_commit_bytes=max(r['receipt']['process']['peak_commit_bytes'] for r in successful),cache_miss_seconds=cache[0]['seconds'],cache_hit_seconds=cache[1]['seconds'],revision_changed_cache_miss=not cache[2]['cache_hit'],mesh_classification_snapshots=[dict(case=r['case'],order=r['order'],reopen=r['reopen'],cache_hits=r['interference']['cache_hits'],native_calls=r['interference']['native_calls']) for r in rows[::2]])
receipt=dict(schema=1,checkpoint='CAD 2.5.1-C',verdict='PASS',created_utc=__import__('datetime').datetime.now(__import__('datetime').timezone.utc).isoformat(),external_evidence=str(OUT),production_files={p:sha(ROOT/p) for p in production},native_operations=['classify_pair','validate','transform','step','box','cylinder','cut'],native_build_manifest=manifest,native_runtime_audit=runtime,sdk_archives=archives,preservation_hashes=pins,geometry_matrix=matrix,invalid_and_integration_rejection=rejections,placement_negative_tests=negative,solver_results=rows,deck_audit=audit,performance=perf,screenshots=screenshots,default_regressions=dict(path=str(regroot),receipt=reg),existing_A_test='assembly-test-c.log: ASSEMBLY_PASS',existing_B_tests='cad251_native_placement: identity/X/Y/Z/general transforms and TET4/TET10 pass; placement_failures: 9 passed; C acceptance reuses real B solver paths',classification_tolerances=dict(length_m='max(1e-9, largest input extent * 1e-10, 4 * each input OCCT tolerance)',volume_m3='max(1e-18, largest input extent cubed * 1e-12)',small_positive_common='INCONCLUSIVE below volume threshold; OVERLAPPING above',within_length_tolerance='zero-volume common and native distance <= length tolerance is TOUCHING'),limitations=['Finite OCCT precision; no arbitrary-scale exactness guarantee','Malformed serialization yields INCONCLUSIVE; parsed invalid solid yields INVALID','Native Boolean failure test uses fault injection; timeout and pre-signalled cancellation execute real contained workers','Pair cache bounded to 512 files; safe misses when full; no expiry deletion','Pipeline primitive interference supports Box/Cylinder/Sphere; tube matrix uses genuine CAD BREP cut; unsupported primitive types reject explicitly','Earlier failed/partial diagnostic runs retained; sealed 28-regression run passed','No contact, ties, welding or interface mechanics implemented','Full historical numerical campaigns NOT RUN'])
destination=ROOT/'docs/architecture/evidence/cad251-interference/final-receipt.json';destination.parent.mkdir(parents=True,exist_ok=True);destination.write_text(json.dumps(receipt,indent=2))
print('INTERFERENCE_RECEIPT_PASS',destination,'max errors',max(r['error'] for r in rows),max(r['imbalance'] for r in rows),'performance',perf['peak_native_commit_bytes'],perf['cache_miss_seconds'],perf['cache_hit_seconds'])
