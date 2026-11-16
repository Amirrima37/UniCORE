"""Sequential native modal acceptance with independently assembled SciPy references.
Run each invocation in a new --output directory; earlier failures are never erased.
"""
import os
os.environ['OPENBLAS_NUM_THREADS']='1'
os.environ['OMP_NUM_THREADS']='1'
import argparse, hashlib, json, math, subprocess, sys, time
from pathlib import Path
import numpy as np
import scipy, scipy.linalg, scipy.sparse as sp, scipy.sparse.linalg as sla
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--output',required=True);parser.add_argument('--phase',choices=['numerical','builds','regression','materials','provenance'],default='numerical');args=parser.parse_args()
OUT=ROOT/args.output;OUT.mkdir(parents=True,exist_ok=True)
if (OUT/'results.json').exists():raise SystemExit('Choose a fresh --output directory; existing evidence is preserved.')
rows=[];checks=0
def check(ok,label):
    global checks
    checks+=1
    if not ok:raise AssertionError(label)
def command(name,cmd,expected=0,timeout=80):
    start=time.perf_counter()
    try:
        p=subprocess.run(list(map(str,cmd)),cwd=ROOT,capture_output=True,timeout=timeout)
        text=(p.stdout+p.stderr).decode('utf8','replace');row=dict(name=name,command=list(map(str,cmd)),exit_code=p.returncode)
    except subprocess.TimeoutExpired as e:
        text=((e.stdout or b'')+(e.stderr or b'')).decode('utf8','replace');row=dict(name=name,command=list(map(str,cmd)),timeout=True)
    (OUT/(name+'.log')).write_text(text,encoding='utf8');row.update(seconds=time.perf_counter()-start,log=str((OUT/(name+'.log')).relative_to(ROOT)),expected_exit=expected)
    rows.append(row);save();print(json.dumps(row),flush=True)
    check(row.get('exit_code')==expected,(name,text))
    check('SCRIPT ERROR:' not in text and 'script is gone' not in text,'no unexpected engine script/lifecycle error')
    return row
def save():
    (OUT/'results.json').write_text(json.dumps(dict(assertions=checks,numpy=np.__version__,scipy=scipy.__version__,rows=rows),indent=2))
def beam(cross,layers,rod=False):
    nodes=np.array([[(x/cross-.5)*.05,y/layers,(z/cross-.5)*.05] for y in range(layers+1) for z in range(cross+1) for x in range(cross+1)])
    def node(x,y,z):return y*(cross+1)**2+z*(cross+1)+x
    cells=[]
    for y in range(layers):
        for z in range(cross):
            for x in range(cross):
                v=[node(x,y,z),node(x+1,y,z),node(x+1,y+1,z),node(x,y+1,z),node(x,y,z+1),node(x+1,y,z+1),node(x+1,y+1,z+1),node(x,y+1,z+1)]
                for ids in [[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6],[0,5,1,6]]:
                    tet=[v[i] for i in ids]
                    if np.linalg.det((nodes[tet[1:]]-nodes[tet[0]]).T)<0:tet[1],tet[2]=tet[2],tet[1]
                    cells.append(tet)
    fixed=np.zeros((len(nodes),3),bool);fixed[nodes[:,1]==0]=True
    if rod:fixed[:,0]=True;fixed[:,2]=True
    return dict(nodes=nodes,cells=np.array(cells),fixed=fixed,E=2e9,nu=0. if rod else .3,rho=1000.)
def material(d,key,index):
    value=d[key];return float(value if np.isscalar(value) else value[index])
def job(name,d,modes=2,iterations=300,tolerance=1e-7,seconds=45):
    nodes=d['nodes'];cells=d['cells'];lines=['UNICORE_JOB 2 modal_structural',f'{len(nodes)} {len(cells)}']
    lines+=[' '.join(format(x,'.17g') for x in v) for v in nodes]
    lines+=['4 '+' '.join(map(str,t))+f" {material(d,'E',i):.17g} {material(d,'nu',i):.17g} {material(d,'rho',i):.17g}" for i,t in enumerate(cells)]
    lines += [f'{int(v)} 0' for v in d['fixed'].flat]
    lines += [f'MODAL {modes} {iterations} {tolerance:.17g} {seconds:.17g}']
    p=OUT/(name+'.ucjob');p.write_text('\n'.join(lines));return p
def reference(d):
    nodes,cells=d['nodes'],d['cells'];N=3*len(nodes);ii=[];jj=[];ks=[];ms=[];volume=0
    total_mass=0
    for index,tet in enumerate(cells):
        E,nu,rho=[material(d,key,index) for key in ['E','nu','rho']];mu=E/(2*(1+nu));lam=E*nu/((1+nu)*(1-2*nu));D=np.zeros((6,6));D[:3,:3]=lam;np.fill_diagonal(D[:3,:3],lam+2*mu);D[3:,3:]=np.eye(3)*mu
        p=nodes[tet];V=np.linalg.det((p[1:]-p[0]).T)/6;check(V>0,'positive independent TET4 volume');volume+=V
        gradient=np.linalg.inv(np.column_stack((np.ones(4),p)))[1:,:].T;B=np.zeros((6,12))
        for a,(x,y,z) in enumerate(gradient):
            b=3*a;B[0,b]=x;B[1,b+1]=y;B[2,b+2]=z;B[3,b:b+2]=[y,x];B[4,b+1:b+3]=[z,y];B[5,b]=z;B[5,b+2]=x
        localK=B.T@D@B*V;localM=np.kron(np.ones((4,4))+np.eye(4),np.eye(3))*rho*V/20;total_mass+=V*rho
        dofs=(3*tet[:,None]+np.arange(3)).ravel();ii.extend(np.repeat(dofs,12));jj.extend(np.tile(dofs,12));ks.extend(localK.flat);ms.extend(localM.flat)
    K=sp.coo_matrix((ks,(ii,jj)),shape=(N,N)).tocsr();M=sp.coo_matrix((ms,(ii,jj)),shape=(N,N)).tocsr();active=np.flatnonzero(~d['fixed'].ravel())
    return K[active][:,active],M[active][:,active],active,total_mass
def solve(name,d,binary='unicore_solver.exe',modes=2,verify=True):
    p=job(name,d,modes);dest=OUT/name
    row=command(name,[ROOT/'bin'/binary,'--job',p,'--output',dest,'--threads','1','--memory-mb','256'])
    r=json.loads((dest/'results.json').read_text());check(r['converged'] and len(r['modes'])==modes,'complete modal schema')
    check(r['job_sha256']==hashlib.sha256(p.read_bytes()).hexdigest(),'SHA-256 exact job identity')
    check(r['nodes']==d['nodes'].tolist() and r['elements']==d['cells'].tolist(),'original mesh correspondence')
    for mode in r['modes']:
        check(mode['generalized_residual']<1e-7 and mode['frequency_Hz']>0,'finite converged physical eigenpair')
        check(abs(mode['frequency_Hz']*2*math.pi-mode['angular_frequency_rad_s'])<1e-9*mode['angular_frequency_rad_s'],'frequency units')
        check(np.all(np.array(mode['displacement_flat'])[d['fixed'].ravel()]==0),'exact eliminated constraints')
    if verify:
        K,M,active,mass=reference(d);check(abs(r['total_mass_kg']/mass-1)<1e-11,'total integrated physical mass')
        phi=np.array([x['displacement_flat'] for x in r['modes']]).T[active];lam=np.array([x['eigenvalue_rad2_s2'] for x in r['modes']])
        ortho=np.max(np.abs(phi.T@M@phi-np.eye(modes)));check(ortho<1e-8,'independent mass orthogonality')
        residuals=[]
        for j in range(modes):
            a=K@phi[:,j];b=lam[j]*(M@phi[:,j]);error=np.linalg.norm(a-b)/(np.linalg.norm(a)+np.linalg.norm(b));residuals.append(float(error));check(error<1.01e-7,'independent eigenpair residual')
            check(abs(phi[:,j]@a/lam[j]-1)<1e-7,'independent modal energy')
        if len(active)<650:exact,v=scipy.linalg.eigh(K.toarray(),M.toarray(),subset_by_index=[0,modes-1])
        else:exact,v=sla.eigsh(K,k=modes,M=M,sigma=0,which='LM',tol=1e-11,v0=np.linspace(.1,1,len(active)));idx=np.argsort(exact);exact=exact[idx];v=v[:,idx]
        diff=float(np.max(np.abs(lam/exact-1)));check(diff<1e-7,'independent LAPACK/ARPACK FEM spectrum')
        singular=np.linalg.svd(v.T@M@phi,compute_uv=False);check(np.min(singular)>1-1e-7,'independent invariant modal subspace')
        row.update(independent_spectrum_relative_error=diff,mass_orthogonality_error=float(ortho),independent_residuals=residuals)
    row.update(frequencies_Hz=[x['frequency_Hz'] for x in r['modes']],nodes=len(d['nodes']),elements=len(d['cells']),active_dofs=r['active_dof_count'],stiffness_nnz=r['stiffness_nnz'],mass_nnz=r['mass_nnz'],assembly_ms=r['assembly_ms'],solve_ms=r['solve_ms'],peak_working_set_bytes=r['peak_working_set_bytes'],eigen_iterations=r['iterations'],linear_iterations=r['linear_iterations'])
    save();return r

try:
    if args.phase=='numerical':
        cxx='C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe'
        command('matrix-build',[cxx,'-std=c++17','-O2','-static','-ffp-contract=off','-Inative/src','native/tests/modal_test.cpp','-o',OUT/'modal_test.exe'])
        command('matrix-tests',[OUT/'modal_test.exe'])
        os.environ['APPDATA']=str(ROOT/'.tools/cae-appdata')
        command('stage6-mesher-export',[ROOT/'.tools/godot/Godot_v4.0-stable_win64.exe','--headless','--path',ROOT,'-s','res://tests/export_stage7_modal_meshes.gd'],timeout=30)
        base=beam(1,4);r=solve('small-independent',base,modes=3)
        for label,updates,factor in [('E4',{'E':base['E']*4},2.),('rho4',{'rho':base['rho']*4},.5),('size2',{'nodes':base['nodes']*2},.5)]:
            d=dict(base,**updates);scaled=solve(label,d,modes=3);check(np.max(np.abs(np.array([x['frequency_Hz'] for x in scaled['modes']])/np.array([x['frequency_Hz'] for x in r['modes']])-factor))<1e-7,'physical frequency scaling')
        repeat=solve('repeat',base,modes=3);check([x['displacement_flat'] for x in repeat['modes']]==[x['displacement_flat'] for x in r['modes']],'repeatable FEM normalization')
        solve('maximum-mode-count',base,modes=12)
        errors=[];eb=1.875104068711961**2/(2*math.pi)*math.sqrt(2e9*.05**2/(12*1000))
        for cross,layers in [(1,10),(2,20),(3,30)]:
            d=beam(cross,layers);r=solve(f'cantilever-{cross}-{layers}',d);error=max(abs(x['frequency_Hz']/eb-1) for x in r['modes']);errors.append(error);rows[-1].update(Euler_Bernoulli_Hz=eb,EB_max_relative_error=error);save()
        check(errors[2]<errors[1]<errors[0],'cantilever refinement toward slender beam reference')
        errors=[];exact=math.sqrt(2e9/1000)/4
        for layers in [4,8,16]:
            d=beam(1,layers,True);r=solve(f'longitudinal-{layers}',d,modes=1);error=abs(r['modes'][0]['frequency_Hz']/exact-1);errors.append(error);rows[-1].update(longitudinal_exact_Hz=exact,continuum_relative_error=error);save()
        check(errors[2]<errors[1]<errors[0] and errors[-1]<.002,'longitudinal continuum convergence and fine-grid error')
        # Use a retained actual Stage 6 numerical mesh, not a recreated cylinder.
        fixture=ROOT/'.tools/stage7-modal-meshes.json';archive=json.loads(fixture.read_text());(OUT/'stage6-cylinder-meshes.json').write_text(json.dumps(archive))
        cylinder_frequencies=[]
        for mesh in archive:
            nodes=np.array(mesh['nodes']);fixed=np.zeros((len(nodes),3),bool);fixed[mesh['bottom']]=True
            cylinder=dict(nodes=nodes,cells=np.array(mesh['elements']),fixed=fixed,E=2e9,nu=.25,rho=7800.)
            result=solve('stage6-cylinder-'+str(mesh['density']),cylinder,modes=3);cylinder_frequencies.append(np.array([x['frequency_Hz'] for x in result['modes']]));rows[-1]['source_fixture']=str(fixture);save()
        check(np.max(np.abs(cylinder_frequencies[2]-cylinder_frequencies[1]))<np.max(np.abs(cylinder_frequencies[1]-cylinder_frequencies[0])),'cylinder refinement increments decrease')
        repeat=solve('stage6-cylinder-repeat',cylinder,modes=3);check([x['displacement_flat'] for x in repeat['modes']]==[x['displacement_flat'] for x in result['modes']],'cylinder repeatability')
        invalid=job('invalid-base',base,modes=2).read_text()
        cases={'zero-density':invalid.replace('2000000000 0.29999999999999999 1000','2000000000 0.29999999999999999 0'),
               'negative-density':invalid.replace('2000000000 0.29999999999999999 1000','2000000000 0.29999999999999999 -1'),
               'nan-density':invalid.replace('2000000000 0.29999999999999999 1000','2000000000 0.29999999999999999 nan'),
               'nonzero-prescribed':invalid.replace('\n1 0','\n1 0.001',1),
               'free-free':invalid.replace('\n1 0','\n0 0'),
               'mode-limit':invalid.replace('MODAL 2 300','MODAL 13 300'),
               'nonconvergence':invalid.replace('MODAL 2 300','MODAL 2 1'),
               'trailing':invalid+'\nGARBAGE',
               'version-mismatch':invalid.replace('JOB 2','JOB 1')}
        cases.update({'infinite-density':invalid.replace('2000000000 0.29999999999999999 1000','2000000000 0.29999999999999999 inf'),
                      'zero-modes':invalid.replace('MODAL 2 300','MODAL 0 300'),
                      'fractional-modes':invalid.replace('MODAL 2 300','MODAL 2.5 300'),
                      'invalid-fixed-flag':invalid.replace('\n1 0','\n2 0',1),
                      'invalid-E':invalid.replace('2000000000 0.29999999999999999 1000','0 0.29999999999999999 1000'),
                      'zero-wall-bound':invalid.rsplit(' ',1)[0]+' 0',
                      'expired-wall-bound':invalid.rsplit(' ',1)[0]+' 0.000000000001',
                      'size-limit':'UNICORE_JOB 2 modal_structural\n2001 1\n',
                      'modal-hex8':'UNICORE_JOB 2 modal_structural\n8 1\n0 0 0\n1 0 0\n1 1 0\n0 1 0\n0 0 1\n1 0 1\n1 1 1\n0 1 1\n8 0 1 2 3 4 5 6 7 2000000000 0.3 1000\n'+('1 0\n'*12)+('0 0\n'*12)+'MODAL 2 300 1e-7 30'})
        for name,text in cases.items():
            check(text!=invalid,'negative fixture really changed input');p=OUT/(name+'.ucjob');p.write_text(text);command(name,[ROOT/'bin/unicore_solver.exe','--job',p,'--output',OUT/name,'--threads','1','--memory-mb','256'],2)
        p=job('cancelled',base);dest=OUT/'cancelled';dest.mkdir(exist_ok=True);(dest/'cancel.request').write_text('cancel')
        command('cancelled',[ROOT/'bin/unicore_solver.exe','--job',p,'--output',dest],3)
        p=job('running-cancel',beam(3,30),modes=8);dest=OUT/'running-cancel';dest.mkdir(exist_ok=True)
        cmd=[str(ROOT/'bin/unicore_solver.exe'),'--job',str(p),'--output',str(dest),'--threads','1','--memory-mb','256'];start=time.perf_counter()
        with (OUT/'running-cancel.log').open('wb') as log:
            proc=subprocess.Popen(cmd,cwd=ROOT,stdout=log,stderr=log)
            try:
                deadline=time.perf_counter()+10;observed=False
                while time.perf_counter()<deadline and proc.poll() is None:
                    try:status=json.loads((dest/'status.json').read_text())
                    except (OSError,ValueError):status={}
                    if status.get('phase')==4:observed=True;break
                    time.sleep(.02)
                check(observed,'observe running eigensolver before cancellation');(dest/'cancel.request').write_text('cancel');code=proc.wait(timeout=10)
            finally:
                if proc.poll() is None:proc.kill();proc.wait(timeout=5)
        rows.append(dict(name='running-cancel',command=cmd,exit_code=code,expected_exit=3,seconds=time.perf_counter()-start));save()
        check(code==3 and not (dest/'running.lock').exists() and not (dest/'results.json').exists(),'cooperative cancellation, clean process and ownership release')
        solve('recovery',base,modes=2)
    elif args.phase=='builds':
        cxx='C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe';command('compiler',[cxx,'--version'])
        baseline_frequencies=None
        for label,flags,binary in [('release',[],'unicore_solver.exe'),('debug',['-Debug'],'unicore_solver_debug.exe'),('serial',['-NoOpenMP'],'unicore_solver_noomp.exe'),('debug-serial',['-Debug','-NoOpenMP'],'unicore_solver_debug_noomp.exe')]:
            row=command('build-'+label,['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','native/extreme/build.ps1',*flags],timeout=180);row.update(binary_sha256=hashlib.sha256((ROOT/'bin'/binary).read_bytes()).hexdigest());save()
            r=solve('modal-'+label,beam(1,4),binary,modes=3)
            frequencies=np.array([x['frequency_Hz'] for x in r['modes']])
            if baseline_frequencies is None:baseline_frequencies=frequencies
            check(np.max(np.abs(frequencies/baseline_frequencies-1))<1e-7,'build configuration frequency equivalence')
            for kind,fixture in [('structural',ROOT/'docs/workbench-2/stage6-final/native-jobs/0/model.ucjob'),('thermal',ROOT/'docs/workbench-2/stage6-final/native-jobs/1/model.ucjob')]:
                command(kind+'-'+label,[ROOT/'bin'/binary,'--job',fixture,'--output',OUT/(kind+'-'+label),'--threads','1','--memory-mb','256'])
                r=json.loads((OUT/(kind+'-'+label)/'results.json').read_text());check(r['ok'] and r['relative_residual']<1e-7,'legacy solve')
                old=json.loads((fixture.parent/'results.json').read_text())
                for key in (['displacement_flat','reactions_flat','stress','strain','von_mises'] if kind=='structural' else ['temperature','heat_flux','heat_reactions']):check(np.allclose(r[key],old[key],rtol=1e-10,atol=1e-9),'legacy fields match archived Stage 6 outputs: '+key)
            restart=ROOT/'docs/workbench-2/stage6-final/restart'
            command('legacy-restart-'+label,[ROOT/'bin'/binary,'--job',restart/'cylinder.ucjob','--output',OUT/('legacy-restart-'+label),'--restart',restart/'paused/checkpoint.ucstate','--threads','1','--memory-mb','256'])
            expected=json.loads((restart/'reference/results.json').read_text());r=json.loads((OUT/('legacy-restart-'+label)/'results.json').read_text());check(np.max(np.abs(np.array(r['temperature'])-expected['temperature']))<1e-7,'unchanged thermal restart')
    elif args.phase=='provenance':
        d=beam(3,30);p=job('edit-during-solve',d);original=p.read_bytes();(OUT/'original-snapshot.ucjob').write_bytes(original);dest=OUT/'edit-during-solve';dest.mkdir(exist_ok=True)
        cmd=[str(ROOT/'bin/unicore_solver.exe'),'--job',str(p),'--output',str(dest),'--threads','1','--memory-mb','256'];start=time.perf_counter()
        with (OUT/'edit-during-solve.log').open('wb') as log:
            proc=subprocess.Popen(cmd,cwd=ROOT,stdout=log,stderr=log)
            try:
                deadline=time.perf_counter()+10;observed=False
                while time.perf_counter()<deadline and proc.poll() is None:
                    try:status=json.loads((dest/'status.json').read_text())
                    except (OSError,ValueError):status={}
                    if status.get('phase')==4:observed=True;break
                    time.sleep(.02)
                check(observed,'input edit occurs during eigensolve');p.write_bytes(original.replace(b'2000000000',b'8000000000'));code=proc.wait(timeout=60)
            finally:
                if proc.poll() is None:proc.kill();proc.wait(timeout=5)
        rows.append(dict(name='edit-during-solve',command=cmd,exit_code=code,expected_exit=0,seconds=time.perf_counter()-start));save();check(code==0,'snapshot solve exits normally')
        result=json.loads((dest/'results.json').read_text());proof=result['job_sha256'];check(proof==hashlib.sha256(original).hexdigest(),'proof describes bytes actually parsed');check(proof!=hashlib.sha256(p.read_bytes()).hexdigest(),'changed job fails current-file identity check');check(result['materials'][0]['E_Pa']==2e9,'result retains parsed original material')
        # Explicitly verify LF input as well as the Windows CRLF fixtures.
        p=job('LF-input',beam(1,4));p.write_bytes(p.read_bytes().replace(b'\r\n',b'\n'));command('LF-input',[ROOT/'bin/unicore_solver.exe','--job',p,'--output',OUT/'LF-input'])
        result=json.loads((OUT/'LF-input/results.json').read_text());check(result['job_sha256']==hashlib.sha256(p.read_bytes()).hexdigest(),'LF byte identity')
    elif args.phase=='materials':
        d=beam(1,4);count=len(d['cells']);d.update(E=[2e9 if i<count//2 else 1e9 for i in range(count)],rho=[1000. if i<count//2 else 4000. for i in range(count)],nu=[.25 if i<count//2 else .3 for i in range(count)])
        solve('heterogeneous-material-mapping',d,modes=3)
        for name,d in [('inverted',beam(1,4)),('all-constrained',beam(1,4))]:
            if name=='inverted':d['cells'][0,[0,1]]=d['cells'][0,[1,0]]
            else:d['fixed'][:]=True
            p=job(name,d);command(name,[ROOT/'bin/unicore_solver.exe','--job',p,'--output',OUT/name],2)
    else:
        os.environ['APPDATA']=str(ROOT/'.tools/cae-appdata')
        command('default-manifest',[sys.executable,'native/run_regressions.py','--godot',ROOT/'.tools/godot/Godot_v4.0-stable_win64.exe','--output',str(OUT.relative_to(ROOT)/'default')],timeout=600)
        for test in ['structural_solver_test','hex8_test','thermal_radiation_test']:
            cxx='C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe';command(test+'-build',[cxx,'-std=c++17','-O2','-static','-ffp-contract=off','-Inative/src','native/tests/'+test+'.cpp','-o',OUT/(test+'.exe')]);command(test,[OUT/(test+'.exe')])
    save();print('Stage 7',args.phase,'PASS assertions=',checks)
except Exception as e:
    save();(OUT/'failure.txt').write_text(repr(e));raise
