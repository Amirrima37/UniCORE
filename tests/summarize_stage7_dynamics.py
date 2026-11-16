"""Collect final Checkpoint 2 receipts and verify the preserved modal baseline."""
import hashlib,json,re,subprocess,os,math
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'docs/workbench-2/stage7-checkpoint2';receipts=[];summary={}
for phase in ['numerical-final','builds-final','regression-final','imports-final','provenance-final']:
    if (out/phase/'failure.txt').exists():raise RuntimeError('Failed phase: '+phase)
    data=json.loads((out/phase/'results.json').read_text());summary[phase]={'assertions':data['assertions'],'operations':len(data['rows'])}
    for r in data['rows']:
        if r.get('exit_code')!=r['expected_exit']:raise RuntimeError('Unexpected outcome '+r['name'])
        r=dict(r,phase=phase)
        if r.get('log'):
            log=(root/r['log']).read_text(encoding='utf8');r['assertion_banners']=[s for s in log.splitlines() if re.search(r'PASS|Passed|checks=|failures=',s)];r['diagnostics']=[s for s in log.splitlines() if 'ERROR:' in s or 'WARNING:' in s]
        receipts.append(r)
manifest=json.loads((out/'regression-final/default/results.json').read_text());assert len(manifest)==28 and all(r['passed'] for r in manifest)
summary['default_manifest']={'passed':28,'total':28}
for r in manifest:
    r=dict(r);r['command']=[str(root/'.tools/godot/Godot_v4.0-stable_win64.exe'),'--headless','--path',str(root),'-s','res://'+r['script']];r['APPDATA']=str(root/'.tools/cae-appdata');path=out/'regression-final/default'/(Path(r['script']).stem+'.log');r['log']=str(path.relative_to(root));text=path.read_text(encoding='utf8');r['diagnostics']=[s for s in text.splitlines() if 'ERROR:' in s or 'WARNING:' in s];r['assertion_banners']=[s for s in text.splitlines() if re.search(r'PASS|Passed|checks=|failures=',s)];receipts.append(r)
extra=json.loads((out/'lifecycle-extra/results.json').read_text())
assert all(r['exit_code']==r['expected_exit'] for r in extra)
summary['lifecycle_extra']={'operations':len(extra),'all_expected_rejections':True};receipts.extend(extra)
baseline=json.loads((out/'baseline.json').read_text())['sha256'];preserved={}
for path in ['native/src/kernels/modal_solver.hpp','native/src/math/symmetric_modes.hpp','native/extreme/modal_output.hpp']:
    current=hashlib.sha256((root/path).read_bytes()).hexdigest();assert current==baseline[path];preserved[path]=current
summary['unchanged_modal_sources']=preserved
summary['source_sha256']={path:hashlib.sha256((root/path).read_bytes()).hexdigest() for path in ['native/src/math/newmark.hpp','native/src/kernels/transient_structural.hpp','native/extreme/dynamic_output.hpp','native/extreme/main.cpp','native/extreme/CMakeLists.txt']}
# Independent mass-weighted projection of already computed spatial histories.
os.environ['OPENBLAS_NUM_THREADS']='1'
import numpy as np
observations=[];numerical=json.loads((out/'numerical-final/results.json').read_text())['rows']
for density in [1,2]:
    name=f'spatial-{density}';reference=next(r for r in numerical if r['name']==name)['first_discrete_spatial_frequency_Hz'];r=json.loads((out/'numerical-final'/name/'results.json').read_text());x=np.array(r['nodes']);M=np.zeros((3*len(x),3*len(x)))
    for tet,material in zip(r['elements'],r['materials']):
        p=x[tet];volume=np.linalg.det((p[1:]-p[0]).T)/6;dofs=(3*np.array(tet)[:,None]+np.arange(3)).ravel();M[np.ix_(dofs,dofs)]+=np.kron(np.ones((4,4))+np.eye(4),np.eye(3))*volume*material['density_kg_m3']/20
    active=r['active_dof_ids'];M=M[np.ix_(active,active)];u=np.array([f['displacement_flat'] for f in r['frames']])[:,active];v=np.array([f['velocity_flat'] for f in r['frames']])[:,active];times=np.array([f['time_s'] for f in r['frames']]);q=u@M@u[0]/(u[0]@M@u[0]);qd=v@M@u[0]/(u[0]@M@u[0]);phase=np.unwrap(np.angle(q-1j*qd/(2*math.pi*reference)));measured=np.polyfit(times,phase,1)[0]/(2*math.pi);expected=math.atan(math.pi*reference*r['time_step_s'])/(math.pi*r['time_step_s']);assert abs(measured/expected-1)<1e-6
    observations.append(dict(density=density,nodes=len(x),tets=len(r['elements']),mass_kg=r['total_mass_kg'],independent_FEM_frequency_Hz=reference,transient_projected_frequency_Hz=measured,expected_Newmark_frequency_Hz=expected))
(out/'spatial-observations.json').write_text(json.dumps(observations,indent=2))
summary.update(verdict='PASS — native constrained TET4 transient structural scope',structural_restart='DEFERRED',workbench_dynamic_ui='DEFERRED',historical_Godot_crash='UNRESOLVED')
(out/'all-final-receipts.json').write_text(json.dumps(receipts,indent=2));(out/'summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False))
print(json.dumps(summary,indent=2,ensure_ascii=False))
