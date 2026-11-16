import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Seal measured CAD24 evidence. Missing/failed required runs prevent PASS."""
import datetime, hashlib, json, struct, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = output_dir('CAD/cad24-completion')

def read(path):
    return json.loads(path.read_bytes())

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

production = '''native/build_occt.ps1 native/occt/worker.cpp native/occt/setup_sdk.py native/occt/provision_runtime.py native/occt/audit_runtime.py native/occt/seal_build.py native/occt/lock_sdk.py native/occt/sdk-lock.json scripts/engines/native_occt.py scripts/engines/process_memory.py scripts/engines/native_graph.py scripts/engines/artifact_retention.py scripts/engines/cad_model.py scripts/engines/gmsh_study.py scripts/engines/owned_mesh_job.py scripts/engines/owned_execution.py scripts/engines/run_owned_geometry.py scripts/engines/run_owned_mesh.py scripts/engines/run_owned_solver.py core/cae/cae_document.gd core/cae/cad_model.gd core/cae/cad_geometry_job.gd core/cae/calculix_workbench.gd ui/cae/cae_workspace.gd ui/cae/cad_boolean_panel.gd ui/cae/cad_validation_panel.gd'''.split()
tests = [p.relative_to(ROOT).as_posix() for p in (ROOT/'tests').glob('*cad24*') if p.is_file() and p.suffix in ['.gd','.py']]
tests += ['native/occt/make_fixtures.cpp','tests/cad22_independent.py']
required = '''native matrix-extra protocol history boundary numerical gui deck-audit endurance gui-endurance failure cancel-cut cancel-step timeout owner-exit retention scan regressions cad21-geometry cad21-integration cad21-lifecycle cad21-preservation cad22-validation cad22-numerical cad22-persistence cad22-independent cad22-lifecycle cad23-unit cad23-numerical cad23-persistence cad23-independent cad23-lifecycle cad23-shutdown cad23-gui'''.split()
campaign = {name:read(OUT/(name+'-latest.json')) for name in required}
baseline = read(OUT/'baseline.json')
pins = {name:dict(before=value,after=sha(Path(name))) for name,value in baseline['hashes'].items() if Path(name).is_absolute()}
regressions = read(OUT/'default-regressions/receipt.json')
images = []
for path in sorted((OUT/'screenshots').glob('*.png')):
    width,height = struct.unpack('>II',path.read_bytes()[16:24])
    images.append(dict(path=path.relative_to(ROOT).as_posix(),width=width,height=height,sha256=sha(path)))
endurance=read(OUT/'endurance.json'); gui=read(OUT/'gui-endurance.json')
history=read(OUT/'persistent-history.json'); numerical=read(OUT/'structural-numerical.json')
gates = dict(runtime_dependencies=not read(OUT/'runtime-audit-release.json')['missing'],all_required_campaigns=all(r['outcome']=='PASS' and r['exit_code']==0 for r in campaign.values()),pinned_binaries_unchanged=all(v['before']==v['after'] for v in pins.values()),default_28=regressions['passed'] and regressions['recorded']==28 and regressions['expected']==28,real_structural_cases=len(numerical)==6,native_cycles=endurance['iterations']==100,gui_cycles=gui['iterations']==60 and gui['exit_code']==0,gui_resolutions={(i['width'],i['height']) for i in images}=={(1280,720),(1920,1080)},serialized_reordering=history['serialized_native_face_reordering_verified'],transitive_provenance=history['transitive_edit_versioning'])
failed_attempts=[]
for path in OUT.glob('*/receipt.json'):
    try:
        r=read(path)
        if isinstance(r,dict) and r.get('outcome')=='FAIL':failed_attempts.append(dict(path=path.relative_to(ROOT).as_posix(),receipt=r))
    except (ValueError,OSError):pass
preserved=read(ROOT/'docs/architecture/evidence/cad23/numerical.json')
(OUT/'preserved-cad23-numerical.json').write_text(json.dumps(preserved,indent=2))
gates['preserved_32_numerical_cases']=len(preserved)==32
gates['native_observed_orphans_zero']=all(row['orphan_count']==0 for row in endurance['rows'])
gates['native_endurance_exits_zero']=all(all(code==0 for code in row['native_exits']) for row in endurance['rows'])
gates['fault_observed_orphans_zero']=all(not read(OUT/('fault-'+mode+'.json'))['observed_native_pids_still_alive'] for mode in ['terminate-cut','cancel-cut','cancel-step','timeout','owner-exit'])
receipt=dict(preserved_cad23_numerical='docs/architecture/evidence/cad24-completion/preserved-cad23-numerical.json',schema=1,checkpoint='CAD 2.4 completion',created_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),verdict='PASS' if all(gates.values()) else 'PARTIAL',gates=gates,baseline=baseline,current_branch=subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),current_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),dirty_tree_preserved=True,baseline_inventory='docs/architecture/evidence/cad24-completion/working-tree-before.txt',source_baseline_limitation='Only four production files were hashed at recovery start; all final production sources are sealed below. The older PARTIAL report lacked pre-edit source hashes.',production_files={name:sha(ROOT/name) for name in production},test_files={name:sha(ROOT/name) for name in tests},pinned_binaries=pins,native_build=read(sdk_root()/'build-manifest.json'),sdk_provenance='docs/architecture/evidence/cad24-completion/sdk-provenance.json',runtime_audit='docs/architecture/evidence/cad24-completion/runtime-audit-release.json',actual_native_apis=['BRepCheck_Analyzer','TopExp_Explorer','TopTools_IndexedMapOfShape','BRepGProp::VolumeProperties','BRepGProp::SurfaceProperties','BRepTools::Read/Write','BRepAlgoAPI_Fuse/Cut/Common','Modified','Generated','IsDeleted','BRepBuilderAPI_Transform','BRepBuilderAPI_GTransform','STEPControl_Reader'],architecture='Owned isolated executable; no TopoDS objects or native pointers cross into Gmsh or Godot. SHA-256 checked metre BREP handoff with complete unique descriptor mapping.',campaign=campaign,regressions=regressions,numerical_cases=numerical,independent_force_moment_audit='docs/architecture/evidence/cad24-completion/independent-deck-audit.json',geometry_matrix=['docs/architecture/evidence/cad24-completion/native-qualification.json','docs/architecture/evidence/cad24-completion/geometry-extra-matrix.json','docs/architecture/evidence/cad24-completion/protocol-and-invalid-geometry.json'],history=history,screenshots=images,endurance=endurance,gui_endurance=gui,lifecycle={mode:read(OUT/('fault-'+mode+'.json')) for mode in ['terminate-cut','cancel-cut','cancel-step','timeout','owner-exit']},retention=read(OUT/'retention.json'),failed_campaign_attempts=failed_attempts,limitations=['Supported CAE domain is one closed positive-volume solid; assemblies/contact are outside scope.','Native validation is not a guarantee against every geometric self-intersection or a guarantee of mesh success.','Modified, generated, split, merged, transformed or ambiguous faces require explicit boundary review; preservation is restricted to verified unchanged provenance.','Curved nonuniform STEP example is explicitly rejected because computed affine volume misses the invariant by 0.8615%; planar nonuniform scaling is qualified.','Coarse thin pipe meshing fails and refined settings succeed. Tiny-feature and nested-cut coarse meshing failures are retained and reported, not relabelled geometry successes.','60-cycle GUI memory and archive growth is measured; no unlimited leak-free claim. The historical Godot access violation is unresolved.','Retention applies to registered completed jobs; active, grace-period, historical, pinned and explicitly archived data are excluded. It is not an operating-system disk quota.','Crash isolation uses injected TerminateProcess(77); it does not reproduce a specific OCCT segmentation fault.','MSYS2 package PGP signatures were not verified; official HTTPS provenance and exact archive SHA-256 locks are retained.'])
(OUT/'final-receipt.json').write_text(json.dumps(receipt,indent=2))
(OUT/'working-tree-final.txt').write_text(subprocess.check_output(['git','status','--porcelain=v1'],cwd=ROOT,text=True))
print(receipt['verdict'],json.dumps(gates))
