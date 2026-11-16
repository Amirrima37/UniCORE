import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Independent DAT/deck audit, physical stress sampling and analytical references."""
import json,math,hashlib,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=output_dir('CAD/cad22')
rows=json.loads((OUT/'numerical.json').read_text());audit=[]
def sha(p):
    with Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def det(a,b,c):return sum(a[i]*(b[(i+1)%3]*c[(i+2)%3]-b[(i+2)%3]*c[(i+1)%3]) for i in range(3))
def sub(a,b):return [x-y for x,y in zip(a,b)]
def contains(points,point):
    a,b,c=[sub(points[i],points[0]) for i in [1,2,3]];r=sub(point,points[0]);d=det(a,b,c)
    weights=[det(r,b,c)/d,det(a,r,c)/d,det(a,b,r)/d];weights.append(1-sum(weights))
    return min(weights)>=-1e-9 and max(weights)<=1+1e-9
def parse_dat(path):
    result={'u':{},'rf':{},'s':{}};section=None
    for line in path.read_text().splitlines():
        lower=line.lower()
        if 'displacements' in lower:section='u';continue
        if 'forces' in lower:section='rf';continue
        if 'stresses' in lower:section='s';continue
        tokens=line.split()
        if not section or not tokens or not tokens[0].isdigit():continue
        key=int(tokens[0])-1;values=[float(x.replace('D','E')) for x in tokens[2 if section=='s' else 1:]]
        assert all(math.isfinite(x) for x in values) and len(values)==(6 if section=='s' else 3)
        assert key not in result[section];result[section][key]=values
    return result
def mises(s):return math.sqrt(.5*((s[0]-s[1])**2+(s[1]-s[2])**2+(s[2]-s[0])**2)+3*sum(x*x for x in s[3:]))
for row in rows:
    job=Path(row['solver_job']);model=json.loads((job/'canonical-model.json').read_text());dat=parse_dat(job/'model.dat')
    assert sha(job/'model.inp')==row['proof']['input_sha256'] and sha(job/'model.dat')==row['proof']['dat_sha256']
    assert len(dat['u'])==len(dat['rf'])==row['nodes'] and len(dat['s'])==row['tet4']
    applied=[math.fsum(float(load[2]) for load in model['loads'] if int(load[1])==axis) for axis in range(3)]
    fixed={int(c[0]) for c in model['constraints']};reaction=[math.fsum(dat['rf'][i][axis] for i in fixed) for axis in range(3)]
    imbalance=math.sqrt(sum((r+f)**2 for r,f in zip(reaction,applied)))/1000
    assert abs(math.sqrt(sum(f*f for f in applied))-1000)<1e-8 and imbalance<1e-4
    loaded={int(load[0]) for load in model['loads']};axis=0 if row['case']=='bending' else 1
    mean=abs(math.fsum(dat['u'][i][axis] for i in loaded)/len(loaded));assert abs(mean/row['tip_mean_m']-1)<1e-10
    volume=math.fsum(det(*[sub(model['nodes'][int(cell[j])],model['nodes'][int(cell[0])]) for j in [1,2,3]])/6 for cell in model['elements'])
    assert abs(volume/row['quality']['mesh_volume']-1)<1e-10
    E=float(model['material']['E']);length=.2 if row['case']=='axial-cylinder' else 1
    area=math.pi*.1**2 if row['case']=='axial-cylinder' else .01-math.pi*.02**2 if row['case']=='step-hole' else .01
    reference=1000*length**3/(3*E*(.1**4/12)) if row['case']=='bending' else 1000*length/(E*area)
    assert abs(reference/row['reference_m']-1)<1e-12
    stress_sample=None
    if row['case']=='step-hole':
        point=[.087,.487,.083]
        for eid,cell in enumerate(model['elements']):
            if contains([model['nodes'][int(i)] for i in cell],point):stress_sample=dict(point_m=point,element=eid,von_mises_Pa=mises(dat['s'][eid]),association='containing TET4 integration-point constant stress');break
        assert stress_sample is not None
    # Identical decks can have different execution receipts/log timestamps.
    # Keep each run immutable while retaining every original hash assertion.
    dest=OUT/'solver-jobs'/(row['case']+'-'+str(row['level'])+'-'+row['proof']['input_sha256'][:12]+'-'+sha(job/'receipt.json')[:12]);dest.mkdir(parents=True,exist_ok=True)
    for name in ['model.inp','model.dat','canonical-model.json','receipt.json','stdout.txt','stderr.txt']:
        if not (dest/name).exists():shutil.copyfile(job/name,dest/name)
        assert sha(job/name)==sha(dest/name)
    h=(row['quality']['cad_volume']/row['tet4'])**(1/3);previous=[r for r in audit if r['case']==row['case']]
    error=abs(mean/reference-1);rate=None
    if previous and row['case']!='axial-bar':
        old=previous[-1];rate=math.log(old['relative_error']/error)/math.log(old['effective_h_m']/h)
    audit.append(dict(case=row['case'],level=row['level'],outcome='PASS',analytical_reference_m=reference,tip_mean_m=mean,relative_error=error,applied_force_N=applied,reaction_force_N=reaction,normalized_reaction_imbalance=imbalance,independent_tet_volume_m3=volume,sample=stress_sample,effective_h_m=h,observed_error_rate=rate,artifacts=str(dest.relative_to(OUT))))
(OUT/'independent-audit.json').write_text(json.dumps(audit,indent=2))
print('CAD22_INDEPENDENT_PASS',len(audit),'real DAT/deck/reference audits')
