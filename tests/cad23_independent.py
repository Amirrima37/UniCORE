import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Independent deck/DAT audit: no production parser, interpolation or Jacobian imports."""
import json,math,hashlib,shutil
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad23')
rows=json.loads((OUT/'numerical.json').read_text());audit=[]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def det(m):return sum(m[0][i]*(m[1][(i+1)%3]*m[2][(i+2)%3]-m[1][(i+2)%3]*m[2][(i+1)%3]) for i in range(3))
def solve(a,b):
    a=[list(r)+[v] for r,v in zip(a,b)];n=len(b)
    for j in range(n):
        k=max(range(j,n),key=lambda i:abs(a[i][j]));a[j],a[k]=a[k],a[j]
        v=a[j][j];assert abs(v)>1e-25;a[j]=[x/v for x in a[j]]
        for i in range(n):
            if i!=j:
                v=a[i][j];a[i]=[x-v*y for x,y in zip(a[i],a[j])]
    return [r[-1] for r in a]
def shape(r):
    x,y,z=r;t=1-x-y-z
    return [t*(2*t-1),x*(2*x-1),y*(2*y-1),z*(2*z-1),4*t*x,4*x*y,4*t*y,4*t*z,4*x*z,4*y*z]
def gradients(r):
    x,y,z=r;t=1-x-y-z
    return [[1-4*t]*3,[4*x-1,0,0],[0,4*y-1,0],[0,0,4*z-1],[4*(t-x),-4*x,-4*x],[4*y,4*x,0],[-4*y,4*(t-y),-4*y],[-4*z,-4*z,4*(t-z)],[4*z,0,4*x],[0,4*z,4*y]]
def jac(p,r):return [[sum((p[i][k]-p[0][k])*g[j] for i,g in enumerate(gradients(r))) for j in range(3)] for k in range(3)]
def locate(p,point):
    m=[[p[j][k]-p[0][k] for j in [1,2,3]] for k in range(3)];r=solve(m,[point[k]-p[0][k] for k in range(3)])
    if min(*r,1-sum(r))<-.2:return None
    if len(p)==10:
        for _ in range(12):
            n=shape(r);res=[sum(n[i]*v[k] for i,v in enumerate(p))-point[k] for k in range(3)]
            if max(abs(x) for x in res)<1e-12:break
            step=solve(jac(p,r),res);r=[x-d for x,d in zip(r,step)]
    return r if min(*r,1-sum(r))>=-1e-8 else None
def parse(path):
    d={'u':{},'rf':{},'s':{},'u_roundoff':{},'s_roundoff':{}};section=None
    for line in path.read_text().splitlines():
        low=line.lower()
        if 'displacements' in low:section='u';continue
        if 'forces' in low:section='rf';continue
        if 'stresses' in low:section='s';continue
        t=line.split()
        if not section or not t or not t[0].isdigit():continue
        key=(int(t[0])-1,int(t[1])-1) if section=='s' else int(t[0])-1
        values=[float(x.replace('D','E')) for x in t[2 if section=='s' else 1:]]
        assert len(values)==(6 if section=='s' else 3) and all(math.isfinite(x) for x in values) and key not in d[section]
        d[section][key]=values
        if section in ['u','s']:
            rounding=[]
            for token,value in zip(t[2 if section=='s' else 1:],values):
                mantissa,_,exponent=token.upper().replace('D','E').partition('E');decimals=len(mantissa.partition('.')[2])
                rounding.append(.5*10**(int(exponent or 0)-decimals) if value else 0.)
            d[section+'_roundoff'][key]=rounding
    return d
def mises(s):return math.sqrt(.5*sum((s[i]-s[(i+1)%3])**2 for i in range(3))+3*sum(x*x for x in s[3:]))
# Independent tensor-product Gauss-Legendre integration after Duffy mapping.
G=[(.06943184420297371,.1739274225687269),(.33000947820757187,.3260725774312731),(.6699905217924281,.3260725774312731),(.9305681557970262,.1739274225687269)]
def volume(p):
    if len(p)==4:return det([[p[j][k]-p[0][k] for j in [1,2,3]] for k in range(3)])/6
    return math.fsum(wu*wv*ww*(1-u)**2*(1-v)*det(jac(p,[u,(1-u)*v,(1-u)*(1-v)*w])) for u,wu in G for v,wv in G for w,ww in G)
def volume_batch(nodes,cells):
    points=np.asarray(nodes,dtype=float)[np.asarray(cells,dtype=int)];p=points-points[:,0:1,:]
    if len(cells[0])==4:return float(np.linalg.det(p[:,1:4,:]).sum()/6)
    total=0.
    for u,wu in G:
        for v,wv in G:
            for w,ww in G:
                g=np.asarray(gradients([u,(1-u)*v,(1-u)*(1-v)*w]));j=np.einsum('eik,ij->ekj',p,g)
                total+=float(np.linalg.det(j).sum())*wu*wv*ww*(1-u)**2*(1-v)
    return total
def surface_integral(nodes,faces):
    area=0.;first=np.zeros(3)
    for face in faces:
        p=np.asarray(nodes)[list(map(int,face))]
        if len(face)==3:
            ds=np.linalg.norm(np.cross(p[1]-p[0],p[2]-p[0]))/2;area+=ds;first+=ds*p.mean(axis=0);continue
        for u,wu in G:
            for s,ws in G:
                v=(1-u)*s;t=1-u-v;n=np.asarray([t*(2*t-1),u*(2*u-1),v*(2*v-1),4*t*u,4*u*v,4*v*t])
                g=np.asarray([[1-4*t,1-4*t],[4*u-1,0],[0,4*v-1],[4*(t-u),-4*u],[4*v,4*u],[-4*v,4*(t-v)]])
                j=(p-p[0]).T@g;ds=wu*ws*(1-u)*np.linalg.norm(np.cross(j[:,0],j[:,1]));area+=ds;first+=ds*(n@p)
    return area,first
for row in rows:
    job=Path(row['solver_job']);model=json.loads((job/'canonical-model.json').read_text());d=parse(job/'model.dat');order=row['order'];nodes=model['nodes'];cells=model['elements']
    assert sha(job/'model.inp')==row['proof']['input_sha256'] and sha(job/'model.dat')==row['proof']['dat_sha256']
    assert len(d['u'])==len(d['rf'])==len(nodes) and len(d['s'])==len(cells)*(4 if order==2 else 1)
    # Audit actual exported deck coordinates, full element order, loads and supports.
    section='';decknodes={};deckcells={};deckloads=[];fixed=set()
    for line in (job/'model.inp').read_text().splitlines():
        if line.startswith('*'):section=line.upper().split(',')[0];continue
        if not line.strip():continue
        t=line.split(',')
        if section=='*NODE':decknodes[int(t[0])-1]=list(map(float,t[1:]))
        if section=='*ELEMENT':deckcells[int(t[0])-1]=[int(x)-1 for x in t[1:]]
        if section=='*CLOAD':deckloads.append((int(t[0])-1,int(t[1])-1,float(t[2])))
        if section=='*BOUNDARY':fixed.add(int(t[0])-1)
    assert list(deckcells.values())==cells and len(decknodes)==len(nodes)
    coordinate_error=max(abs(decknodes[i][k]-p[k]) for i,p in enumerate(nodes) for k in range(3));assert coordinate_error<1e-14
    applied=[math.fsum(v for i,k,v in deckloads if k==axis) for axis in range(3)]
    reaction=[math.fsum(d['rf'][i][k] for i in fixed) for k in range(3)];imbalance=math.dist(reaction,[-x for x in applied])/1000
    assert abs(math.dist(applied,[0,0,0])-1000)<1e-8 and imbalance<1e-4
    if order==2:
        boundary=model['quadratic_boundary'];assert fixed==set(map(int,boundary['groups'][boundary['support']]))
        tipids=list(map(int,boundary['groups'][boundary['load_face']]))
        assert 'TYPE=C3D10' in (job/'model.inp').read_text()
    else:tipids=list({int(i) for i,k,v in deckloads})
    if order==2:loadfaces=boundary['faces'][boundary['load_face']]
    else:
        # Load corners identify the selected physical exterior face in these
        # planar cases; recover its triangles independently from C3D4 cells.
        selected=set(tipids);loadfaces=[]
        for cell in cells:
            for indices in [(0,1,2),(0,1,3),(0,2,3),(1,2,3)]:
                face=[int(cell[i]) for i in indices]
                if set(face)<=selected:loadfaces.append(face)
    loaded_area,loaded_first=surface_integral(nodes,loadfaces)
    actual_moment=sum((np.cross(decknodes[i],np.eye(3)[k]*v) for i,k,v in deckloads),np.zeros(3));expected_moment=np.cross(loaded_first/loaded_area,applied)
    moment_error=float(np.linalg.norm(actual_moment-expected_moment))/1000
    assert moment_error<(1e-10 if order==2 else 1e-7),(row['case'],order,'moment',moment_error)
    axis=0 if row['case']=='bending' else 1;tip=abs(math.fsum(d['u'][i][axis] for i in tipids)/len(tipids));assert abs(tip/row['tip_mean_m']-1)<1e-10
    vol=volume_batch(nodes,cells);assert abs(vol/row['quality']['mesh_volume']-1)<1e-9
    E=model['material']['E'];nu=model['material']['nu'];L=.2 if row['case']=='axial-cylinder' else 1;area=math.pi*.1**2 if row['case']=='axial-cylinder' else .01-math.pi*.02**2 if row['case']=='step-hole' else .01
    kinematic_error=0.;kinematic_bound_ratio=0.
    for eid in sorted({0,len(cells)//2,len(cells)-1}):
        ids=list(map(int,cells[eid]));p=np.asarray(nodes)[ids];u=np.asarray([d['u'][i] for i in ids]);A=.5854101966249685;B=.1381966011250105
        locations=[[B,B,B],[A,B,B],[B,A,B],[B,B,A]] if order==2 else [[.25,.25,.25]]
        for ip,r in enumerate(locations):
            g=np.asarray(gradients(r) if order==2 else [[-1,-1,-1],[1,0,0],[0,1,0],[0,0,1]])
            j=(p-p[0]).T@g;h=u.T@g@np.linalg.inv(j);eps=(h+h.T)/2;mu=E/(2*(1+nu));lam=E*nu/((1+nu)*(1-2*nu));s=2*mu*eps+lam*np.trace(eps)*np.eye(3)
            calculated=np.asarray([s[0,0],s[1,1],s[2,2],s[0,1],s[0,2],s[1,2]]);actual=np.asarray(d['s'][(eid,ip)])
            kinematic_error=max(kinematic_error,float(np.linalg.norm(calculated-actual)/max(100.,np.linalg.norm(actual))))
            # Propagate the actual DAT decimal quantization, especially important
            # when differentiating bending displacements near the neutral axis.
            ub=np.asarray([d['u_roundoff'][i] for i in ids]);hb=ub.T@np.abs(g@np.linalg.inv(j))
            sb=np.asarray([2*mu*hb[i,i]+abs(lam)*np.trace(hb) for i in range(3)]+[mu*(hb[a,b]+hb[b,a]) for a,b in [(0,1),(0,2),(1,2)]])+np.asarray(d['s_roundoff'][(eid,ip)])
            budget=float(np.linalg.norm(sb))+1e-8*max(1.,np.linalg.norm(actual));difference=float(np.linalg.norm(calculated-actual))
            assert difference<=budget,(row['case'],order,row['level'],eid,ip,difference,budget)
            kinematic_bound_ratio=max(kinematic_bound_ratio,difference/budget)
    reference=1000*L**3/(3*E*(.1**4/12)) if row['case']=='bending' else 1000*L/(E*area);assert abs(reference/row['reference_m']-1)<1e-12
    shear=1000*L/((5/6)*(E/(2*(1+nu)))*area) if row['case']=='bending' else 0
    stress_sample=None
    if row['case'] in ['step-hole','axial-bar']:
        point=[.087,.487,.083] if row['case']=='step-hole' else [.047,.487,.043]
        for eid,c in enumerate(cells):
            r=locate([nodes[int(i)] for i in c],point)
            if r is None:continue
            tensor=d['s'][(eid,0)]
            if order==2:
                A=.5854101966249685;B=.1381966011250105;locations=[[1,B,B,B],[1,A,B,B],[1,B,A,B],[1,B,B,A]]
                coef=[solve(locations,[d['s'][(eid,i)][k] for i in range(4)]) for k in range(6)]
                tensor=[sum(a*b for a,b in zip(c,[1,*r])) for c in coef]
            stress_sample=dict(point_m=point,element=eid,tensor_Pa=tensor,von_mises_Pa=mises(tensor),association='linear reconstruction of 4 integration-point tensors' if order==2 else 'constant single integration-point tensor')
            break
        assert stress_sample is not None
        if row['case']=='axial-bar':assert abs(stress_sample['tensor_Pa'][1]/100000-1)<1e-5
    dest=OUT/'solver-jobs'/(row['case']+'-o'+str(order)+'-'+str(row['level'])+'-'+row['proof']['input_sha256'][:12]+'-'+job.name);dest.mkdir(parents=True,exist_ok=True)
    for name in ['model.inp','model.dat','canonical-model.json','receipt.json','stdout.txt','stderr.txt']:
        if not (dest/name).exists():shutil.copyfile(job/name,dest/name)
        assert sha(job/name)==sha(dest/name)
    previous=[r for r in audit if r['case']==row['case'] and r['order']==order];h=(row['quality']['cad_volume']/len(cells))**(1/3);error=abs(tip/reference-1)
    rate=math.log(previous[-1]['relative_error']/error)/math.log(previous[-1]['effective_h_m']/h) if previous and row['case']!='axial-bar' else None
    audit.append(dict(case=row['case'],order=order,level=row['level'],outcome='PASS',reference_m=reference,timoshenko_shear_m=shear,tip_m=tip,relative_error=error,reaction_relative_imbalance=imbalance,applied_force_N=applied,reaction_force_N=reaction,applied_moment_Nm=actual_moment.tolist(),independent_surface_moment_Nm=expected_moment.tolist(),moment_error_per_force_m=moment_error,loaded_area_m2=loaded_area,independent_quadratic_volume_m3=vol,deck_coordinate_max_error_m=coordinate_error,kinematic_stress_relative_error=kinematic_error,kinematic_DAT_rounding_budget_fraction=kinematic_bound_ratio,sample=stress_sample,effective_h_m=h,observed_error_rate=rate,artifacts=str(dest.relative_to(OUT))))
    (OUT/'independent-audit.json').write_text(json.dumps(audit,indent=2))
assert len(audit)==32
print('CAD23_INDEPENDENT_PASS',len(audit),'independent actual deck/DAT/volume/reference audits')
