"""Seal measured face-identity acceptance and a separate milestone audit."""
import json,hashlib,struct,statistics,zipfile
from pathlib import Path
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[1];OUT=Path((ROOT/'face-identity-attempt.txt').read_text().strip())
def read(name):return json.loads((OUT/name).read_text())
def sha(path):
    with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
cases=['duplicate','translated','rotated','step','touching','reassigned']
rows=[]
for case in cases:
    current=read('solves-'+case+'.json');assert len(current)==8
    assert 'FACE_SOLVES_PASS' in (OUT/(case+'.log')).read_text()
    for order in [1,2]:
        before=[r for r in current if r['order']==order and not r['reopen']];after=[r for r in current if r['order']==order and r['reopen']]
        assert [r['instance'] for r in before]==[r['instance'] for r in after]
        assert len({r['instance'] for r in before})==2 and len({r['definition'] for r in before})==1
    rows+=current
assert len(rows)==48
assert all(r['error']<1e-4 and r['imbalance']<1e-5 and r['moment_error']<1e-5 and r['completion']['state']=='completed' and r['completion']['exit_code']==0 for r in rows)
for r in rows:
    assert r['resolution']['instance_uuid']==r['instance']
    for key,ref in r['references'].items():
        assert ref['instance_uuid']==r['instance'] and ref['definition_uuid']==r['definition'] and ref['state']=='resolved' and ref['coordinate_system']=='global' and ref['source_face']
        assert ref['definition_face_id'] in r['resolution']['world_faces'] and r['resolution']['mesh_surfaces'][ref['definition_face_id']]
unit=read('unit.json');assert len(unit)>=40 and all(r['passed'] for r in unit)
assert 'FACE_UNIT_PASS' in (OUT/'unit-final.log').read_text()
negative=read('negative-document.json');assert len(negative)==11 and 'FACE_NEGATIVE_PASS' in (OUT/'negative.log').read_text()
failures=read('negative-native.json');assert len(failures)==5 and all(r['passed'] for r in failures)
assert read('symmetric.json')['strong_verified'] and read('partition.json')['verified']
assert read('partition.json')['gmsh_surfaces']==7 and read('partition.json')['native_faces']==6
audit=read('deck-audit.json');assert len(audit)==24 and all(r['no_coupling'] for r in audit)
compatibility=read('compatibility.json');assert len(compatibility)==6 and all(r['passed'] for r in compatibility)
assert 'FACE_COMPATIBILITY_PASS' in (OUT/'compatibility-final.stdout.txt').read_text()
assert 'ASSEMBLY_PASS' in (ROOT/'assembly-test-d-final.log').read_text()
regroot=OUT/'default-regressions-final-source';reg=json.loads((regroot/'receipt.json').read_text());assert reg['passed'] and reg['recorded']==28
regrows=json.loads((regroot/'results.json').read_text());assert len(regrows)==28 and all(r['passed'] for r in regrows)
assert 'FACE_GUI_PASS' in (OUT/'gui-acceptance.log').read_text()
picks=read('gui-picks.json');assert sum(bool(r.get('ray_pick')) for r in picks)==5 and sum(bool(r.get('native_preview_reused')) for r in picks)==2
screens={}
for name in ['instance-selected-0','instance-selected-1','rotated-step-selected','ambiguous-unresolved','explicit-reassignment','tet1-result','tet2-result','reopened-reassignment']:
    for width in [1280,1920]:
        path=OUT/(name+'-'+str(width)+'.png');dimensions=struct.unpack('>II',path.read_bytes()[16:24]);assert dimensions==(width,720 if width==1280 else 1080)
        screens[str(path)]=dict(sha256=sha(path),dimensions=dimensions)
baseline=json.loads((ROOT/'docs/architecture/evidence/cad251-interference/final-receipt.json').read_text())
pins={path:sha(path) for path in baseline['preservation_hashes']};assert pins==baseline['preservation_hashes'] and len(pins)==7
sdk=Path('D:/PROJECT/SDK/OCCT');manifest=json.loads((sdk/'build-manifest.json').read_text());assert manifest==baseline['native_build_manifest']
assert sha(sdk/'unicore_occt_worker.exe')==manifest['worker_sha256'] and sha(ROOT/'native/occt/worker.cpp')==manifest['source_sha256']
for name,expected in manifest['dlls'].items():assert sha(sdk/'ucrt64/bin'/name)==expected
# Lossless, verified external solver archives. Originals remain untouched.
archives=[];archive_root=OUT/'solver-archives';archive_root.mkdir(exist_ok=True)
for job in sorted({r['job'] for r in rows}):
    directory=Path(job);destination=archive_root/(directory.name+'.zip');hashes={}
    with zipfile.ZipFile(destination,'w',compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(directory.rglob('*')):
            if path.is_file() and not path.is_symlink():
                name=path.relative_to(directory).as_posix();hashes[name]=sha(path);archive.write(path,name)
    with zipfile.ZipFile(destination) as archive:
        for name,expected in hashes.items():assert hashlib.sha256(archive.read(name)).hexdigest()==expected
    archives.append(dict(original=job,archive=str(destination),sha256=sha(destination),files=hashes,restore='Extract to an empty job directory and verify each per-file SHA-256. Original job directories have been retained.'))
production=['core/cae/assembly_boundaries.gd','core/cae/assembly_model.gd','core/cae/cae_document.gd','core/cae/calculix_workbench.gd','scripts/engines/face_identity.py','scripts/engines/instance_placement.py','scripts/engines/gmsh_study.py','scripts/engines/cad_model.py','scripts/engines/mesh_config.py','ui/cae/cad_viewport.gd','ui/cae/cae_workspace.gd']
perf=read('reassignment-performance.json');times=perf['document_mutation_microseconds'];resolution=[r['resolution']['resolution_seconds'] for r in rows]
evidence={name:dict(path=str(OUT/name),sha256=sha(OUT/name)) for name in ['unit.json','negative-document.json','negative-native.json','native.json','partition.json','symmetric.json','history-original.json','history-edited.json','deck-audit.json','compatibility.json','gui-picks.json']+['solves-'+c+'.json' for c in cases]}
summary=[]
for r in rows:
    item={k:v for k,v in r.items() if k!='resolution'}
    item['resolution_summary']={k:r['resolution'][k] for k in ['instance_uuid','definition_uuid','source_sha256','placed_sha256','geometry_revision','transformation_revision','mesh_surfaces','strategy','resolution_seconds']}
    summary.append(item)
receipt=dict(schema=1,checkpoint='CAD 2.5.1-D',verdict='PASS',overall_CAD_2_5_1_verdict='PARTIAL',created_utc=datetime.now(timezone.utc).isoformat(),external_evidence=str(OUT),production_files={p:sha(ROOT/p) for p in production},boundary_contract=dict(schema=1,owner='instance_uuid',geometry=['definition_uuid','geometry_revision','source_sha256'],face='definition_face_id + immutable source_face descriptor anchor',placement='transformation_revision + verified native rigid transport',force_coordinates='global',new_instances='conditions cleared; explicit assignment required',unresolved='original reference retained, solving blocked, explicit assign/clear required'),acceptance_matrix={c:'PASS: TET4/TET10, two instances, regenerated and solved before/after reopen' for c in cases},unit_tests=unit,negative_document_tests=negative,negative_native_tests=failures,solver_results=summary,solver_archives=archives,deck_audit=audit,native_evidence=evidence,gui_picks=picks,screenshots=screens,performance=dict(face_resolution_seconds=dict(min=min(resolution),median=statistics.median(resolution),max=max(resolution)),reassignment_document_microseconds=dict(min=min(times),median=statistics.median(times),max=max(times),samples=times),unchanged_assignment_native_preview_reuse=True),regressions=dict(path=str(regroot),receipt=reg,results=regrows),compatibility=compatibility,preservation_hashes=pins,sdk_runtime_dll_hashes=manifest['dlls'],native_worker_sha256=manifest['worker_sha256'],native_worker_rebuilt=False,milestone_audit=dict(A='Reusable definitions/instances and compatibility operations revalidated; denormalized geometry snapshots remain duplicated',B='Native placement, STEP, TET4/TET10 and failure tests revalidated',C='Native interference matrix and all three TET4/TET10 solver cases rerun; overlap rejection retained',D='Persistent qualified references, anchored provenance, explicit review/reassignment, picking, stale gates, save/reopen, undo/redo and measured GUI/solver acceptance pass',outstanding=['Original CAD 2.5.1 report includes explicit analysis participation; current visibility remains display-only and all parts participate','Canonical source geometry remains duplicated in compatibility parts/templates; storage de-duplication is incomplete','Original broad assembly lifecycle/endurance and complete historical numerical campaigns were not repeated in this focused checkpoint'],recommended_next='CAD 2.5.1 acceptance closure: agree remaining participation/storage requirements and qualify the remaining lifecycle/endurance coverage; do not start CAD 2.5.2'),limitations=['Correspondence is uniquely validated geometric equivalence at native tolerances, not an arbitrary-scale mathematical identity proof','Only actual unchanged native graph history preserves conditions through topology edits; unknown/modified faces become unresolved','One-to-many planar Gmsh partitions are verified by area/centroid/inertia/bounds and adjacency; unproven curved subdivisions reject safely','Legacy opaque face strings are bootstrapped only with unique source descriptors and immediately anchored; ambiguity requires review','Single active viewport face selection; sequential per-instance highlights are captured','Native timeout/cancellation tests are pre-signalled contained-worker tests, not a long-duration leak/endurance claim','Full historical numerical/GUI endurance campaigns NOT RUN'])
destination=ROOT/'docs/architecture/evidence/cad251-face-identity/final-receipt.json';destination.parent.mkdir(parents=True,exist_ok=True);destination.write_text(json.dumps(receipt,indent=2))
print('FACE_RECEIPT_PASS',destination,'maximum_errors',max(r['error'] for r in rows),max(r['imbalance'] for r in rows),max(r['moment_error'] for r in rows),'performance',statistics.median(resolution),statistics.median(times))
