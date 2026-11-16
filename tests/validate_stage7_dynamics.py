"""Bounded sequential Newmark acceptance, with analytic and independent SciPy references."""
import os
os.environ['OPENBLAS_NUM_THREADS']='1';os.environ['OMP_NUM_THREADS']='1'
import argparse,hashlib,json,math,subprocess,sys,time
from pathlib import Path
import numpy as np
import scipy,scipy.linalg as la
from scipy.integrate import solve_ivp
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--output',required=True);parser.add_argument('--phase',choices=['numerical','builds','regression','imports','provenance'],default='numerical');args=parser.parse_args()
OUT=ROOT/args.output;OUT.mkdir(parents=True,exist_ok=True)
if (OUT/'results.json').exists():raise SystemExit('Use a fresh output directory to preserve evidence.')
rows=[];checks=0
def save(): (OUT/'results.json').write_text(json.dumps(dict(assertions=checks,numpy=np.__version__,scipy=scipy.__version__,rows=rows),indent=2))
def check(ok,label):
    global checks
    checks+=1
    if not ok:raise AssertionError(label)
def run(name,cmd,expected=0,timeout=80):
    start=time.perf_counter()
    try:
        p=subprocess.run(list(map(str,cmd)),cwd=ROOT,capture_output=True,timeout=timeout);text=(p.stdout+p.stderr).decode('utf8','replace');row=dict(name=name,command=list(map(str,cmd)),exit_code=p.returncode)
    except subprocess.TimeoutExpired as e:
        text=((e.stdout or b'')+(e.stderr or b'')).decode('utf8','replace');row=dict(name=name,command=list(map(str,cmd)),timeout=True)
    (OUT/(name+'.log')).write_text(text,encoding='utf8');row.update(seconds=time.perf_counter()-start,expected_exit=expected,log=str((OUT/(name+'.log')).relative_to(ROOT)));rows.append(row);save();print(json.dumps(row),flush=True)
    check(row.get('exit_code')==expected,(name,text[-1000:]));check('SCRIPT ERROR:' not in text and 'script is gone' not in text,'no script/lifecycle error');return text,row
def unit(kind,dt,steps,name=None):
    text,row=run(name or kind,[OUT/'dynamics_test.exe',kind,dt,steps]);data=json.loads(text);f=data['frames'];t=np.array([x['time'] for x in f]);u=np.array([x['u'] for x in f]);v=np.array([x['v'] for x in f]);a=np.array([x['a'] for x in f]);check(data['effective_system_setups']==1,'one effective setup');check(data['max_equilibrium_residual']<1e-8,'unit equilibrium');check(data['max_energy_balance']<1e-10,'unit discrete energy balance');check(all(x['dissipation']>=0 for x in f),'nonnegative damping dissipation');return data,t,u,v,a,row
def independent_matrices(d):
    x=np.array(d['nodes']);cells=d['cells'];N=3*len(x);K=np.zeros((N,N));M=K.copy();total=0
    E,nu,rho=d['E'],d['nu'],d['rho'];mu=E/(2*(1+nu));lam=E*nu/((1+nu)*(1-2*nu));D=np.zeros((6,6));D[:3,:3]=lam;np.fill_diagonal(D[:3,:3],lam+2*mu);D[3:,3:]=np.eye(3)*mu
    for tet in cells:
        p=x[tet];V=np.linalg.det((p[1:]-p[0]).T)/6;check(V>0,'positive independent FEM volume');total+=V*rho;g=np.linalg.inv(np.column_stack((np.ones(4),p)))[1:,:].T;B=np.zeros((6,12))
        for i,(gx,gy,gz) in enumerate(g):
            j=3*i;B[0,j]=gx;B[1,j+1]=gy;B[2,j+2]=gz;B[3,j:j+2]=[gy,gx];B[4,j+1:j+3]=[gz,gy];B[5,j]=gz;B[5,j+2]=gx
        dofs=(3*np.array(tet)[:,None]+np.arange(3)).ravel();K[np.ix_(dofs,dofs)]+=V*B.T@D@B;M[np.ix_(dofs,dofs)]+=np.kron(np.ones((4,4))+np.eye(4),np.eye(3))*rho*V/20
    active=np.flatnonzero(~np.array(d['fixed']).ravel());return K[np.ix_(active,active)],M[np.ix_(active,active)],active,total
def cylinder(density=1):
    archived=json.loads((ROOT/'docs/workbench-2/stage7-checkpoint1/numerical-verified/stage6-cylinder-meshes.json').read_text());mesh=next(x for x in archived if x['density']==density);nodes=mesh['nodes'];fixed=np.zeros((len(nodes),3),bool);fixed[mesh['bottom']]=True
    return dict(nodes=nodes,cells=mesh['elements'],fixed=fixed.tolist(),E=2e9,nu=.25,rho=7800.,u=np.zeros(3*len(nodes)),v=np.zeros(3*len(nodes)))
def job(name,d,dt,steps,outputs=None,alpha=0,betaR=0,loads=None,limit=2000,wall=45):
    if outputs is None:outputs=list(range(steps+1))
    lines=['UNICORE_JOB 3 transient_structural',f"{len(d['nodes'])} {len(d['cells'])}"]
    lines+=[' '.join(format(float(x),'.17g') for x in p) for p in d['nodes']]
    lines+=['4 '+' '.join(map(str,c))+f" {d['E']:.17g} {d['nu']:.17g} {d['rho']:.17g}" for c in d['cells']]
    lines += [f'{int(flag)} 0 {u:.17g} {v:.17g}' for flag,u,v in zip(np.array(d['fixed']).flat,d['u'],d['v'])]
    lines += [f'DYNAMICS {dt:.17g} {steps} {alpha:.17g} {betaR:.17g} {limit} 1e-11 {wall:.17g}',f'LOADS {len(loads or [])}']
    lines += [' '.join(map(str,l)) for l in loads or []]
    lines += ['OUTPUTS '+str(len(outputs)),' '.join(map(str,outputs))]
    p=OUT/(name+'.ucjob');p.write_text('\n'.join(lines));return p
def load_verified(directory,path):
    status=json.loads((directory/'status.json').read_text());r=json.loads((directory/'results.json').read_text())
    check(status.get('state')=='Completed' and r.get('ok') and r.get('complete') and r.get('converged'),'complete successful native result')
    check(r.get('dynamic_schema')==1 and r['job_sha256']==hashlib.sha256(path.read_bytes()).hexdigest(),'dynamic schema and exact-byte provenance')
    frames=r['frames'];check(len(frames)>=2 and frames[-1]['step']==r['steps'],'complete final output')
    check(len(frames)==r['frame_count']==len(r['output_steps']) and [f['step'] for f in frames]==r['output_steps'],'requested output completeness')
    last=-1
    for f in frames:
        check(f['step']>last and f['time_s']==f['step']*r['time_step_s'],'strict output correspondence');last=f['step']
        for k in ['displacement_flat','velocity_flat','acceleration_flat']:check(len(f[k])==len(r['nodes'])*3 and np.all(np.isfinite(f[k])),'complete finite frame')
    return r
def solve(name,d,dt,steps,**kwargs):
    binary=kwargs.pop('binary','unicore_solver.exe');p=job(name,d,dt,steps,**kwargs);dest=OUT/name;text,row=run(name,[ROOT/'bin'/binary,'--job',p,'--output',dest,'--threads','1','--memory-mb','256']);r=load_verified(dest,p)
    check(r['nodes']==d['nodes'] and r['elements']==d['cells'],'original FEM correspondence');check(r['effective_system_setups']==1,'cached effective system');check(r['max_equilibrium_residual']<=1e-8,'all-step dynamic equilibrium')
    fixed=np.array(d['fixed']).ravel()
    for f in r['frames']:
        for key in ['displacement_flat','velocity_flat','acceleration_flat']:check(np.all(np.array(f[key])[fixed]==0),'exact constrained states')
    row.update(assembly_ms=r['assembly_ms'],setup_ms=r['effective_setup_ms'],integration_ms=r['integration_ms'],peak_working_set_bytes=r['peak_working_set_bytes'],max_equilibrium_residual=r['max_equilibrium_residual'],max_energy_balance_J=r['max_energy_balance_J'],linear_iterations=r['linear_iterations']);save();return r,row,p
def modal_initial(d):
    K,M,active,mass=independent_matrices(d);eigen,phi=la.eigh(K,M);u=np.zeros(3*len(d['nodes']));u[active]=phi[:,0]*1e-5;d=dict(d,u=u)
    return d,K,M,active,mass,eigen,phi
def frames_arrays(r):
    f=r['frames'];return np.array([x['time_s'] for x in f]),*[np.array([x[k] for x in f]) for k in ['displacement_flat','velocity_flat','acceleration_flat']]
try:
    if args.phase=='numerical':
        cxx='C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe';run('unit-build',[cxx,'-std=c++17','-O2','-static','-ffp-contract=off','-Inative/src','native/tests/dynamics_test.cpp','-o',OUT/'dynamics_test.exe']);run('unit-smoke',[OUT/'dynamics_test.exe'])
        for kind in ['free','damped','step','constant','sine','velocity','ramp']:
            data,t,u,v,a,row=unit(kind,.005,800);c=1.04 if kind=='damped' else 0
            if kind=='damped':
                decay=.26;wd=math.sqrt(4-decay**2);b=(.2+decay*.1)/wd;g=.1*np.cos(wd*t)+b*np.sin(wd*t);ue=np.exp(-decay*t)*g;ve=np.exp(-decay*t)*(-decay*g-.1*wd*np.sin(wd*t)+b*wd*np.cos(wd*t));force=np.zeros_like(t)
            elif kind in ['step','constant']:ue=.25*(1-np.cos(2*t));ve=.5*np.sin(2*t);force=np.full_like(t,2)
            elif kind=='sine':ue=(np.sin(1.3*t)-.65*np.sin(2*t))/4.62;ve=1.3*(np.cos(1.3*t)-np.cos(2*t))/4.62;force=np.sin(1.3*t)
            elif kind=='ramp':
                force=2*np.clip((t-.2)/.5,0,1);ref=solve_ivp(lambda t,y:[y[1],np.clip((t-.2)/.5,0,1)-4*y[0]],[0,4],[0,0],t_eval=t,method='DOP853',rtol=1e-12,atol=1e-14,max_step=.01);check(ref.success,'ramp reference');ue,ve=ref.y
            else:
                u0,v0=(0,.3) if kind=='velocity' else (.1,.2);ue=u0*np.cos(2*t)+v0/2*np.sin(2*t);ve=-2*u0*np.sin(2*t)+v0*np.cos(2*t);force=np.zeros_like(t)
            ae=(force-c*ve-8*ue)/2;errors=[float(np.max(np.abs(q[:,0]-e))) for q,e in [(u,ue),(v,ve),(a,ae)]];check(all(x<y for x,y in zip(errors,[1e-4,5e-4,2e-3])),'SDOF analytical errors');row['analytical_max_errors_u_v_a']=errors;save()
            mechanical=u[:,0]**2*4+v[:,0]**2;reported=np.array([f['kinetic']+f['elastic'] for f in data['frames']]);check(np.max(abs(mechanical-reported))<1e-12,'independent SDOF energy')
            vm=(v[1:,0]+v[:-1,0])/2;dd=np.r_[0,np.cumsum(np.diff(t)*c*vm**2)];ww=np.r_[0,np.cumsum((force[1:]+force[:-1])/2*np.diff(u[:,0]))];check(np.max(abs(dd-np.array([f['dissipation'] for f in data['frames']])))<1e-10,'independent damping quadrature');check(np.max(abs(ww-np.array([f['work'] for f in data['frames']])))<1e-10,'independent external work')
        phase_errors=[];temporal=[]
        for h in [.04,.02,.01]:
            data,t,u,v,a,row=unit('phase',h,round(4/h),'phase-'+str(h));phase=np.unwrap(np.angle(u[:,0]/.1-1j*v[:,0]/.2));phase_error=abs(phase[-1]-2*t[-1]);errors=np.array([np.max(abs(u[:,0]-.1*np.cos(2*t)))/.1,np.max(abs(v[:,0]+.2*np.sin(2*t)))/.2,np.max(abs(a[:,0]+.4*np.cos(2*t)))/.4]);phase_errors.append(phase_error);temporal.append(errors);row.update(phase_error_rad=phase_error,normalized_u_v_a_errors=errors.tolist());save()
        check(phase_errors[-1]<1e-3,'fine phase error');check(all(3.5<a/b<4.5 for a,b in zip(phase_errors,phase_errors[1:])),'phase convergence order');check(np.all((np.array(temporal[:-1])/np.array(temporal[1:])>3.5)&(np.array(temporal[:-1])/np.array(temporal[1:])<4.5)),'u/v/a temporal convergence')
        data,t,u,v,a,row=unit('coupled',.001,1000);M=np.array([[2,.3],[.3,1]]);K=np.array([[30,-10],[-10,20]]);C=.2*M+.01*K
        def force(t):return np.array([np.sin(2.3*t),2*np.clip((t-.2)/.5,0,1)])
        def ode(t,y):return np.r_[y[2:],la.solve(M,force(t)-C@y[2:]-K@y[:2],assume_a='pos')]
        ref=solve_ivp(ode,[0,1],[.1,-.03,.2,.1],t_eval=t,rtol=1e-12,atol=1e-14,method='DOP853',max_step=.002);check(ref.success,'coupled independent DOP853');ae=np.array([ode(x,y)[2:] for x,y in zip(t,ref.y.T)]);errors=[float(np.max(abs(u-ref.y[:2].T))),float(np.max(abs(v-ref.y[2:].T))),float(np.max(abs(a-ae)))];check(all(x<y for x,y in zip(errors,[2e-5,1e-4,1e-3])),'coupled reference errors');row['reference_errors_u_v_a']=errors;save()
        data,t,u,v,a,row=unit('phase',1,100,'large-step-stability');check(np.max(abs(u[:,0]))<=.1*(1+1e-10),'large step bounded energy, no accuracy claim')
        modal_fixture=ROOT/'docs/workbench-2/stage7-checkpoint1/numerical-verified/stage6-cylinder-1.ucjob';run('native-modal-reference',[ROOT/'bin/unicore_solver.exe','--job',modal_fixture,'--output',OUT/'native-modal-reference','--threads','1','--memory-mb','256']);modal_result=json.loads((OUT/'native-modal-reference/results.json').read_text())
        d,K,M,active,mass,eigen,phi=modal_initial(cylinder());omega=math.sqrt(eigen[0]);f=omega/(2*math.pi);check(abs(modal_result['modes'][0]['frequency_Hz']/f-1)<1e-7,'accepted native modal solver vs independent spectrum');T=20/f;errors=[];phase_errors=[]
        for steps in [500,1000,2000]:
            stride=max(1,steps//1000);r,row,path=solve('cylinder-time-'+str(steps),d,T/steps,steps,outputs=list(range(0,steps+1,stride)));t,u,v,a=frames_arrays(r);check(abs(r['total_mass_kg']/mass-1)<1e-12,'FEM integrated mass');amp=1e-5;exact_u=np.cos(omega*t)[:,None]*phi[:,0][None,:]*amp;exact_v=-omega*np.sin(omega*t)[:,None]*phi[:,0][None,:]*amp;exact_a=-eigen[0]*exact_u
            e=[float(np.max(abs(x[:,active]-y))/np.max(abs(y))) for x,y in [(u,exact_u),(v,exact_v),(a,exact_a)]];errors.append(e);q=u[:,active]@M@phi[:,0]/amp;qd=v[:,active]@M@phi[:,0]/amp;phase=np.unwrap(np.angle(q-1j*qd/omega));phase_errors.append(abs(phase[-1]-omega*T));estimated=float(np.polyfit(t,phase,1)[0]/(2*math.pi));expected_newmark=math.atan(omega*(T/steps)/2)/(math.pi*(T/steps));check(abs(estimated/expected_newmark-1)<1e-6,'discrete modal frequency');check(r['max_energy_balance_J']<1e-6*(.5*eigen[0]*amp**2),'FEM undamped energy');row.update(temporal_normalized_u_v_a_errors=e,phase_error_rad=phase_errors[-1],modal_Hz=f,estimated_Hz=estimated,expected_discrete_Hz=expected_newmark);save()
            check(np.max(np.abs((M@a[:,active].T+K@u[:,active].T)))<1e-7,'independent FEM equilibrium absolute defect')
            energies=.5*np.einsum('ij,ij->i',v[:,active]@M,v[:,active])+.5*np.einsum('ij,ij->i',u[:,active]@K,u[:,active]);check(np.max(abs(energies/energies[0]-1))<1e-6,'independent FEM mechanical energy');check(np.max(abs(energies-np.array([x['kinetic_energy_J']+x['elastic_energy_J'] for x in r['frames']])))<1e-12,'reported FEM energies')
        check(np.all(np.array(errors[2])<np.array(errors[1])) and np.all(np.array(errors[1])<np.array(errors[0])),'FEM time refinement');check(all(3.5<a/b<4.5 for a,b in zip(phase_errors,phase_errors[1:])),'FEM phase convergence')
        signal=q-np.mean(q);freq=np.fft.rfftfreq(len(q),t[1]-t[0]);peak=freq[np.argmax(np.abs(np.fft.rfft(signal))[1:])+1];resolution=freq[1]-freq[0];check(abs(peak-f)<resolution,'modal FFT within one finite-duration bin');rows[-1].update(fft_peak_Hz=float(peak),fft_resolution_Hz=float(resolution));save()
        for density in [1,2]:
            dd,KK,MM,aa,mm,ev,pp=modal_initial(cylinder(density));r,row,path=solve('spatial-'+str(density),dd,.1/math.sqrt(ev[0]),100);row['first_discrete_spatial_frequency_Hz']=math.sqrt(ev[0])/(2*math.pi);save()
        r,row,path=solve('repeat',d,T/2000,2000,outputs=list(range(0,2001,2)));original=json.loads((OUT/'cylinder-time-2000/results.json').read_text());check(r['frames']==original['frames'],'repeatable time history')
        r,row,path=solve('FEM-damped-forced',d,T/500,500,alpha=10,betaR=1e-6,loads=[[int(active[0]),'sine',1,0,0,omega*.6,0]]);check(r['frames'][-1]['damping_dissipation_J']>0,'FEM positive physical damping');check(r['max_energy_balance_J']<1e-8,'FEM forced discrete work balance')
        t,u,v,a=frames_arrays(r);C=10*M+1e-6*K;vm=(v[1:,active]+v[:-1,active])/2;dd=np.r_[0,np.cumsum(np.diff(t)*np.einsum('ij,ij->i',vm@C,vm))];force=np.zeros((len(t),len(active)));force[:,0]=np.sin(omega*.6*t);ww=np.r_[0,np.cumsum(np.einsum('ij,ij->i',(force[1:]+force[:-1])/2,np.diff(u[:,active],axis=0)))];check(np.max(abs(dd-np.array([f['damping_dissipation_J'] for f in r['frames']])))<1e-10,'independent FEM damping work');check(np.max(abs(ww-np.array([f['external_work_J'] for f in r['frames']])))<1e-10,'independent FEM external work')
        zero,row,zero_path=solve('zero-initial-unforced',cylinder(),1e-5,10);check(all(np.all(np.array(frame[k])==0) for frame in zero['frames'] for k in ['displacement_flat','velocity_flat','acceleration_flat']),'zero initial equilibrium stays zero')
        source=job('invalid-source',d,T/100,100,outputs=[0,100]).read_text()
        cases={'density-zero':source.replace('2000000000 0.25 7800','2000000000 0.25 0'),'density-negative':source.replace('2000000000 0.25 7800','2000000000 0.25 -1'),'elastic-invalid':source.replace('2000000000 0.25 7800','-1 0.25 7800'),'nonfinite-initial':source.replace('\n1 0 0 0','\n1 0 nan 0',1),'support-motion':source.replace('\n1 0 0 0','\n1 0.01 0 0',1),'trailing':source+'\nBAD','malformed-load':source.replace('LOADS 0','LOADS 1\n0 triangle 1 0 0 0 0'),'bad-version':source.replace('JOB 3','JOB 2')}
        cases.update({'nonfinite-velocity':source.replace('\n1 0 0 0','\n1 0 0 inf',1),'output-order':source.replace('0 100','100 0'),'excessive-output':source.replace('OUTPUTS 2','OUTPUTS 1002'),'moving-initial-support':source.replace('\n1 0 0 0','\n1 0 0.1 0',1)})
        for label,params in [('dt-zero',{'dt':0}),('dt-negative',{'dt':-1}),('excessive-steps',{'steps':20001}),('negative-damping',{'alpha':-1}),('nonfinite-damping',{'betaR':float('nan')}),('nonconvergence',{'limit':1}),('wall-limit',{'wall':1e-12})]:
            p=job(label,d,params.pop('dt',T/100),params.pop('steps',100),outputs=[0,100],**params);cases[label]=p.read_text()
        for label,text in cases.items():
            p=OUT/(label+'.ucjob');p.write_text(text);run(label,[ROOT/'bin/unicore_solver.exe','--job',p,'--output',OUT/label,'--threads','1','--memory-mb','256'],2);check(not (OUT/label/'results.json').exists(),'failure does not publish partial result')
        # Cancel an integration already running, then recover with a new valid job.
        dd=modal_initial(cylinder(3))[0];p=job('cancel-running',dd,1e-5,20000,outputs=[0,20000]);dest=OUT/'cancel-running';dest.mkdir(exist_ok=True);cmd=[str(ROOT/'bin/unicore_solver.exe'),'--job',str(p),'--output',str(dest),'--threads','1','--memory-mb','256'];start=time.perf_counter()
        with (OUT/'cancel-running.log').open('wb') as log:
            proc=subprocess.Popen(cmd,stdout=log,stderr=log,cwd=ROOT)
            try:
                deadline=time.perf_counter()+10;observed=False
                while time.perf_counter()<deadline and proc.poll() is None:
                    try:s=json.loads((dest/'status.json').read_text())
                    except (OSError,ValueError):s={}
                    if s.get('phase')==4:observed=True;break
                    time.sleep(.02)
                check(observed,'observe actual integration');(dest/'cancel.request').write_text('cancel');exit_code=proc.wait(timeout=10)
            finally:
                if proc.poll() is None:proc.kill();proc.wait(timeout=5)
        rows.append(dict(name='cancel-running',command=cmd,exit_code=exit_code,expected_exit=3,seconds=time.perf_counter()-start));check(exit_code==3 and not (dest/'running.lock').exists() and not (dest/'results.json').exists(),'cancel clean exit and no successful history');save()
        solve('recovery',d,T/100,100,outputs=[0,100])
        # Negative result-consumer controls: atomic completion, schema and shapes
        # must all pass. Corrupt files are retained in separate diagnostic folders.
        for label,mutate in [('incomplete',lambda x:x['frames'].pop()),('truncated-field',lambda x:x['frames'][0]['velocity_flat'].pop()),('nonfinite-field',lambda x:x['frames'][0]['displacement_flat'].__setitem__(0,None))]:
            dest=OUT/('output-'+label);dest.mkdir();bad=json.loads(json.dumps(original));mutate(bad);(dest/'results.json').write_text(json.dumps(bad));(dest/'status.json').write_text('{"state":"Completed"}');accepted=False
            try:load_verified(dest,OUT/'cylinder-time-2000.ucjob');accepted=True
            except (AssertionError,TypeError,ValueError):pass
            check(not accepted,'corrupt/incomplete result rejected: '+label)
    elif args.phase=='builds':
        previous=None
        for label,flags,binary in [('release',[],'unicore_solver.exe'),('debug',['-Debug'],'unicore_solver_debug.exe'),('serial',['-NoOpenMP'],'unicore_solver_noomp.exe'),('debug-serial',['-Debug','-NoOpenMP'],'unicore_solver_debug_noomp.exe')]:
            text,row=run('build-'+label,['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','native/extreme/build.ps1',*flags],timeout=180);row['binary_sha256']=hashlib.sha256((ROOT/'bin'/binary).read_bytes()).hexdigest();save();d=modal_initial(cylinder())[0];r,row,p=solve('dynamic-'+label,d,1e-5,100,alpha=2,betaR=1e-6,binary=binary)
            fields=np.array([[f[k] for k in ['displacement_flat','velocity_flat','acceleration_flat']] for f in r['frames']]);check(previous is None or np.allclose(fields,previous,rtol=1e-8,atol=1e-10),'cross-build dynamic histories');previous=fields
            for kind,index in [('structural',0),('thermal',1)]:
                archive=ROOT/f'docs/workbench-2/stage6-final/native-jobs/{index}';run(kind+'-'+label,[ROOT/'bin'/binary,'--job',archive/'model.ucjob','--output',OUT/(kind+'-'+label),'--threads','1','--memory-mb','256']);new=json.loads((OUT/(kind+'-'+label)/'results.json').read_text());old=json.loads((archive/'results.json').read_text())
                for key in (['displacement_flat','reactions_flat','stress'] if index==0 else ['temperature','heat_flux','heat_reactions']):check(np.allclose(new[key],old[key],rtol=1e-10,atol=1e-9),'legacy fields preserved')
            fixture=ROOT/'docs/workbench-2/stage7-checkpoint1/builds-verified/modal-release.ucjob';run('modal-'+label,[ROOT/'bin'/binary,'--job',fixture,'--output',OUT/('modal-'+label),'--threads','1','--memory-mb','256']);result=json.loads((OUT/('modal-'+label)/'results.json').read_text());old=json.loads((fixture.parent/'modal-release/results.json').read_text());check(np.allclose([m['frequency_Hz'] for m in result['modes']],[m['frequency_Hz'] for m in old['modes']],rtol=1e-7,atol=0),'modal compatibility')
            restart=ROOT/'docs/workbench-2/stage6-final/restart';run('thermal-restart-'+label,[ROOT/'bin'/binary,'--job',restart/'cylinder.ucjob','--output',OUT/('thermal-restart-'+label),'--restart',restart/'paused/checkpoint.ucstate','--threads','1','--memory-mb','256']);new=json.loads((OUT/('thermal-restart-'+label)/'results.json').read_text());old=json.loads((restart/'reference/results.json').read_text());check(np.max(abs(np.array(new['temperature'])-old['temperature']))<1e-7,'thermal checkpoint compatibility')
    elif args.phase=='imports':
        os.environ['APPDATA']=str(ROOT/'.tools/cae-appdata');source='res://docs/workbench-2/stage7-checkpoint2/numerical-final'
        run('workbench-import-rejection',[ROOT/'.tools/godot/Godot_v4.0-stable_win64.exe','--headless','--path',ROOT,'-s','res://tests/test_stage7_dynamic_import_rejection.gd','--',source],timeout=30)
    elif args.phase=='provenance':
        d=modal_initial(cylinder(3))[0];p=job('input-edit',d,1e-5,1000,outputs=[0,1000]);original=p.read_bytes();(OUT/'original-snapshot.ucjob').write_bytes(original);dest=OUT/'input-edit';dest.mkdir();cmd=[str(ROOT/'bin/unicore_solver.exe'),'--job',str(p),'--output',str(dest),'--threads','1','--memory-mb','256'];start=time.perf_counter()
        with (OUT/'input-edit.log').open('wb') as log:
            proc=subprocess.Popen(cmd,stdout=log,stderr=log,cwd=ROOT)
            try:
                observed=False;deadline=time.perf_counter()+10
                while time.perf_counter()<deadline and proc.poll() is None:
                    try:s=json.loads((dest/'status.json').read_text())
                    except (OSError,ValueError):s={}
                    if s.get('phase')==4:observed=True;break
                    time.sleep(.02)
                check(observed,'edit during actual integration');p.write_bytes(original.replace(b'2000000000',b'8000000000'));code=proc.wait(timeout=65)
            finally:
                if proc.poll() is None:proc.kill();proc.wait(timeout=5)
        rows.append(dict(name='input-edit',command=cmd,exit_code=code,expected_exit=0,seconds=time.perf_counter()-start));save();check(code==0,'immutable snapshot solve completes');result=json.loads((dest/'results.json').read_text());check(result['job_sha256']==hashlib.sha256(original).hexdigest() and result['job_sha256']!=hashlib.sha256(p.read_bytes()).hexdigest(),'dynamic proof follows actual parsed bytes, rejects changed source');check(result['materials'][0]['E_Pa']==2e9,'original material retained')
    else:
        os.environ['APPDATA']=str(ROOT/'.tools/cae-appdata');run('default-manifest',[sys.executable,'native/run_regressions.py','--godot',ROOT/'.tools/godot/Godot_v4.0-stable_win64.exe','--output',str(OUT.relative_to(ROOT)/'default')],timeout=600)
        for test in ['structural_solver_test','hex8_test','thermal_radiation_test','modal_test','dynamics_test']:
            cxx='C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe';run(test+'-build',[cxx,'-std=c++17','-O2','-static','-ffp-contract=off','-Inative/src','native/tests/'+test+'.cpp','-o',OUT/(test+'.exe')]);run(test,[OUT/(test+'.exe')])
    save();print('Dynamics',args.phase,'PASS assertions=',checks)
except Exception as e:
    save();(OUT/'failure.txt').write_text(repr(e));raise
