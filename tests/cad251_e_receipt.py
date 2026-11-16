"""Publish only executed evidence; any missing mandatory gate yields PARTIAL."""
import os,sys,json,hashlib,struct,statistics,subprocess,time
from datetime import datetime,timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from development_paths import sdk_root
from cad251_e_deck_audit import audit
OUT=Path((ROOT/'final-acceptance-attempt.txt').read_text().strip())
def read(p):return json.loads(Path(p).read_text())
def sha(p):
    with Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def pointer(name):return Path((OUT/name).read_text().strip())
def marked(folder,marker,log='stdout.txt'):
    folder=Path(folder);text=(folder/log).read_text(errors='replace') if (folder/log).exists() else ''
    err=(folder/'stderr.txt').read_text(errors='replace') if (folder/'stderr.txt').exists() else ''
    return marker in text and 'SCRIPT ERROR:' not in text+err
def footprint():
    size=count=0;errors=[]
    for base,dirs,files in os.walk(ROOT,onerror=lambda e:errors.append(str(e))):
        dirs[:]=[d for d in dirs if not (Path(base)/d).is_junction() and not (Path(base)/d).is_symlink()]
        for name in files:
            try:size+=(Path(base)/name).stat().st_size;count+=1
            except OSError as e:errors.append(str(e))
    return dict(bytes=size,files=count,errors=errors,scope='stat only; inaccessible/reparse targets excluded; accessible lower bound')
production=['core/cae/analysis_participation.gd','core/cae/assembly_storage.gd','core/cae/assembly_model.gd','core/cae/cae_document.gd','core/cae/calculix_workbench.gd','core/cae/mesh_config.gd','scripts/engines/gmsh_study.py','scripts/engines/native_occt.py','scripts/engines/run_owned_geometry.py','ui/cae/cae_workspace.gd','ui/cae/cad_viewport.gd']
baseline=read(OUT/'baseline.json');closure=pointer('closure-current.txt');gui=pointer('gui-final-current.txt');storage=pointer('storage-final-current.txt');endurance=pointer('endurance-final-current.txt');cad24=pointer('CAD24-current.txt')
verification=read(OUT/'verification-current.json');native=read(OUT/'native-verification-current.json');lifecycle=read(OUT/'lifecycle-current.json');c_solve=pointer('C-solver-current.txt');regression=pointer('regressions-current.txt')
storage_rows=read(storage/'storage.json');d_rows=sum([read(Path(verification['directory'])/('solves-'+c+'.json')) for c in ['duplicate','translated','rotated','step','touching','reassigned']],[])
c_rows=sum([read(c_solve/('solves-'+c+'.json')) for c in ['rotated-disjoint','touching','step']],[])
participation=read(closure/'participation/participation.json');original_endurance=read(OUT/'endurance.json');endurance_rows=read(endurance/'workbench-endurance.json');cycles=endurance_rows['cycles']
life_rows=read(lifecycle['results']);hist23=read(closure/'historical/CAD/cad23/numerical.json');hist24=read(cad24/'CAD/cad24-completion/structural-numerical.json') if (cad24/'CAD/cad24-completion/structural-numerical.json').exists() else []
gui_events=read(gui/'gui.json');memory=read(endurance/'history-memory.json') if (endurance/'history-memory.json').exists() else {}
teardown=read(endurance/'teardown.json') if (endurance/'teardown.json').exists() else {}
screens=[]
for path in sorted(gui.glob('*.png')):
    with path.open('rb') as f:header=f.read(24)
    width,height=struct.unpack('>II',header[16:24]);assert (width,height) in [(1280,720),(1920,1080)]
    screens.append(dict(path=str(path),sha256=sha(path),width=width,height=height))
pins={p:sha(p) for p in baseline['pins']};manifest=read(sdk_root()/'build-manifest.json');dlls={name:sha(sdk_root()/'ucrt64/bin'/name) for name in manifest['dlls']}
checks={
 'analysis_participation_TET4_TET10':marked(closure/'participation','PARTICIPATION_GATE_PASS') and len(participation)==2,
 'canonical_storage_and_migration':marked(storage,'CANONICAL_STORAGE_GATE_PASS') and len(storage_rows)==5,
 'A_document_D_identity_and_24_solves':all(r['passed'] for r in read(verification['results'])) and len({r['job'] for r in d_rows})==24,
 'B_C_D_native_contracts':all(r['passed'] for r in read(native['results'])),
 'C_12_actual_solves_and_D_face_deck_audit':all(r['passed'] for r in read(c_solve/'checks.json')) and len({r['job'] for r in c_rows})==12,
 'lifecycle_10_and_recovery':len(life_rows)==10 and all(r['passed'] and r['details']['retry_succeeded'] and r['details']['reopened'] and not r['details']['alive_after'] for r in life_rows),
 'asynchronous_Workbench_20_cycles':len(cycles)==20 and marked(endurance,'WORKBENCH_ENDURANCE_20_PASS','endurance.stdout.txt') and all(r['heartbeat_frames']>0 and not r['resources']['owned_descendants'] and r['results_cleared'] for r in cycles),
 'memory_growth_investigated':bool(memory) and memory['before']['undo_depth']>0 and memory['after']['undo_depth']==0 and teardown.get('orphan_nodes')==0 and all(r.get('console_characters',131073)<=131072 and r.get('console_paragraphs',513)<=512 for r in cycles),
 'GUI_workflow_and_clean_teardown':marked(gui,'FINAL_WORKBENCH_GUI_PASS') and 'ERROR:' not in (gui/'stderr.txt').read_text(errors='replace') and 'Stray Node' not in (gui/'stdout.txt').read_text(errors='replace') and len(screens)>=32,
 'inspector_40_rebuild_cleanup':'INSPECTOR_LIFECYCLE_PASS' in (OUT/'inspector-lifecycle.stdout.txt').read_text() and not (OUT/'inspector-lifecycle.stderr.txt').read_text(),
 'default_28':read(regression/'receipt.json').get('passed') is True and len(read(regression/'results.json'))==28,
 'CAD23_historical_32':len(hist23)==32 and marked(closure/'CAD23-32','CAD23_NUMERICAL_PASS'),
 'CAD24_historical_six':len(hist24)==6 and marked(cad24,'CAD24_NUMERICAL_PASS'),
 'seven_binary_pins':pins==baseline['pins'] and len(pins)==7,
 '243_SDK_DLL_pins':len(dlls)==243 and dlls==baseline['sdk_manifest']['dlls'] and sha(sdk_root()/'unicore_occt_worker.exe')==baseline['sdk_manifest']['worker_sha256'],
}
checks['final_A_geometry_sharing']='ASSEMBLY_PASS' in (OUT/'A-final.stdout.txt').read_text() and not (OUT/'A-final.stderr.txt').read_text()
jobs={}
def add(path,bodies=None):
    path=str(path)
    if path.startswith('user://'):path=str(OUT/'profile/roaming/Godot/app_userdata/UniCORE'/path[7:])
    jobs[path]=bodies
for row in d_rows+c_rows:add(row['job'],2)
for row in original_endurance['cycles']:add(row['job'],row['bodies'])
for row in cycles:add(row['solver_job'],2)
for row in participation:add(row['job'],1)
for row in gui_events:
    if row.get('solve'):add(row['job'],2)
for row in hist23:add(row['solver_job'],1)
for row in hist24:add(row['solver_job'],1)
audits=[];audit_errors=[]
for job,bodies in jobs.items():
    try:audits.append(audit(job,bodies))
    except Exception as error:audit_errors.append(dict(job=job,error=repr(error)))
(OUT/'final-deck-audit.json').write_text(json.dumps(dict(audits=audits,errors=audit_errors),indent=2))
checks['actual_decks_DAT_equilibrium_and_independent_ownership']=not audit_errors and len(audits)==len(jobs)
# Protect executed engineering evidence through the existing retention protocol.
for job in jobs:
    path=Path(job).resolve()
    if path.is_relative_to(OUT.resolve()) and path.is_dir():(path/'PINNED').write_text('CAD 2.5.1-E measured engineering evidence\n')
status=subprocess.check_output(['git','status','--short','--untracked-files=all'],cwd=ROOT,text=True);(OUT/'git-status-after.txt').write_text(status)
receipt=dict(schema=1,checkpoint='CAD 2.5.1-E',verdict='PASS' if all(checks.values()) else 'PARTIAL',overall_CAD_2_5_1='PASS' if all(checks.values()) else 'PARTIAL',gates=checks,external_evidence=str(OUT),production_files={p:sha(ROOT/p) for p in production},preservation_hashes=pins,sdk_runtime_dll_hashes=dlls,sdk_worker_sha256=sha(sdk_root()/'unicore_occt_worker.exe'),baseline=str(OUT/'baseline.json'),storage=storage_rows,participation=participation,verification=verification,native_verification=native,C_solver_verification=str(c_solve),face_deck_audit=str(Path(verification['directory'])/'deck-audit.json'),lifecycle=lifecycle,gui=dict(directory=str(gui),screenshots=screens,events=gui_events,inspected_views=['visible-excluded','tet2-displacement','rejected-active-overlap','unresolved-warning']),endurance=dict(directory=str(endurance),data=endurance_rows,memory_investigation=memory,original_document_campaign=str(OUT/'endurance.json')),numerical=dict(D=d_rows,C=c_rows,CAD23=hist23,CAD24=hist24,deck_audit=str(OUT/'final-deck-audit.json'),audited_jobs=len(audits),audit_errors=audit_errors),regressions=dict(receipt=str(regression/'receipt.json'),passed=read(regression/'receipt.json')['passed']),repository_footprint=dict(before=baseline['footprint']),known_limitations=['Qualified independent-body linear static TET4/TET10 scope; one valid solid per definition; rigid placement only.','Ambiguous face identity blocks analysis and requires deliberate native review/reassignment.','Twenty-cycle measurements do not prove leak-free operation; Undo retains bounded engineering snapshots.','Repository footprint is an accessible lower bound; inaccessible legacy paths and reparse targets are excluded.'],resolved_failures=['Early lifecycle harness used Godot-only process tracking; replaced with Windows handles and rerun.','STEP preview wrote canonical geometry metadata through a compatibility view; replaced with validated document mutation.','Unattached imported-STEP topology pickers leaked; freed and repeated teardown verified.','Empty unresolved geometry caused camera fitting errors; null geometry is skipped.','Historical CAD24 ambiguous face names blocked safely; native review and explicit reassignment added to its runner.'],not_run=[])
target=ROOT/'docs/architecture/evidence/cad251-final-acceptance/final-receipt.json';target.parent.mkdir(parents=True,exist_ok=True)
receipt['created_utc']=datetime.now(timezone.utc).isoformat()
receipt['endurance']['teardown']=teardown
receipt['resolved_failures'].append('Per-frame progress grew the transient Workbench console; bounded paragraphs/characters and throttled updates qualified through a fresh 20-cycle run.')
# Keep repeated native face/interference trees outside the source repository.
# Summaries retain measured values/identities and hash the full external proof.
detailed=OUT/'detailed-final-results.json'
detailed.write_text(json.dumps(dict(D=d_rows,C=c_rows),indent=2))
receipt['numerical']['detailed_results']={'path':str(detailed),'sha256':sha(detailed)}
d_keys=['case','order','reopen','instance','part_id','definition','error','imbalance','moment_error','displacement_m','expected_m','force_N','reaction_N','moment_Nm','reaction_moment_Nm','job','completion']
receipt['numerical']['D']=[dict({k:row[k] for k in d_keys},definition_faces={k:ref['definition_face_id'] for k,ref in row['references'].items()},proof_file=str(Path(verification['directory'])/('solves-'+row['case']+'.json'))) for row in d_rows]
receipt['numerical']['C']=[dict({k:row[k] for k in ['case','order','reopen','instance','error','imbalance','job','completion']},classifications=[p['classification'] for p in row['interference']['pairs']],proof_file=str(c_solve/('solves-'+row['case']+'.json'))) for row in c_rows]
for _ in range(3):
    receipt['repository_footprint']['after']=footprint();target.write_text(json.dumps(receipt,indent=2),encoding='utf-8')
(OUT/'final-receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps(dict(verdict=receipt['verdict'],failed=[k for k,v in checks.items() if not v],audited_jobs=len(audits),audit_errors=audit_errors),indent=2))
