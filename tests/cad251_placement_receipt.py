import sys,os,json,hashlib,base64,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
OUT=Path(os.environ['UNICORE_PLACEMENT_OUT'])
os.environ['UNICORE_CAD_JOB_TEMP']=str(OUT/'axis-native')
from native_occt import run
from instance_placement import place,matrix,point,close
p=json.loads((OUT/'axis-instance.json').read_text());raw=base64.b64decode(p['cad_base64']);source_hash=hashlib.sha256(raw).hexdigest()
before,_=run(raw);placed,after=place(raw,p,before['validation'])
# Independent Rodrigues reference for the arbitrary-axis document command.
axis=[x/math.sqrt(14) for x in [1,2,3]];c=math.cos(.7);s=math.sin(.7)
v=before['validation']['centroid'];dot=sum(a*b for a,b in zip(axis,v))
reference=[v[i]*c+(axis[(i+1)%3]*v[(i+2)%3]-axis[(i+2)%3]*v[(i+1)%3])*s+axis[i]*dot*(1-c) for i in range(3)]
assert close(reference,after['centroid'])
m=matrix(p)
for j in range(3):
    v=[float(i==j) for i in range(3)];dot=axis[j]
    expected=[v[i]*c+(axis[(i+1)%3]*v[(i+2)%3]-axis[(i+2)%3]*v[(i+1)%3])*s+axis[i]*dot*(1-c) for i in range(3)]
    assert max(abs(m[4*i+j]-expected[i]) for i in range(3))<2e-7 # Godot Basis uses real_t float.

assert hashlib.sha256(raw).hexdigest()==source_hash==p['cad_sha256']
rows=json.loads((OUT/'solves.json').read_text())+json.loads((OUT/'solves-step.json').read_text())
assert len(rows)==24 and all(r['error']<1e-4 and r['imbalance']<1e-5 and r['completion']['state']=='completed' for r in rows)
assert 'PLACEMENT_GUI_PASS' in (OUT/'gui.log').read_text()
assert 'FINAL_SCHEMA_AXIS_PASS' in (OUT/'final-smoke.log').read_text()
negative=json.loads((OUT/'negative.json').read_text());assert len(negative)==9 and all(r['passed'] for r in negative)
audit=json.loads((OUT/'audit.json').read_text());assert len(audit['decks'])==12 and len(audit['preservation_hashes'])==7
production=['core/cae/assembly_model.gd','core/cae/cae_document.gd','scripts/engines/instance_placement.py','scripts/engines/gmsh_study.py','scripts/engines/cad_model.py','ui/cae/cae_workspace.gd','ui/cae/cad_viewport.gd']
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
receipt=dict(schema=1,checkpoint='CAD 2.5.1-B',verdict='PASS',external_evidence=str(OUT),production_files={p:sha(ROOT/p) for p in production},native_worker_rebuilt=False,native_operations=['box','validate','step','transform'],native_placement=json.loads((OUT/'placement.json').read_text()),arbitrary_axis_validation=after,source_unchanged_sha256=source_hash,solves=rows,negative_tests=negative,deck_audit=audit['decks'],preservation_hashes=audit['preservation_hashes'],screenshots={str(OUT/('workbench-'+str(w)+'.png')):sha(OUT/('workbench-'+str(w)+'.png')) for w in [1280,1920]},stale_checks='gui.log: stale geometry and pending boundaries rejected',persistence='all 3 scenarios, both orders, regenerated and solved after reopening; final-schema smoke passed',force_convention='global vectors; rigid placement never rotates assigned force',face_identity='bijective area/centroid/rotated inertia matching; transformed bounds and full face coverage checked on Gmsh import; ambiguity rejects',tolerances=dict(displacement_relative=1e-4,reaction_relative=1e-5,deck_force_absolute_N=1e-6,deck_moment='max(1e-6 Nm, 1e-8 * maximum expected moment component), accounting for decimal export precision'),limitations=['Scaling intentionally unsupported','Symmetric or indistinguishable face descriptors block placement; no enumeration fallback','Existing conservative overlap bounds gate retained','Compatibility parts/template geometry snapshots remain duplicated','Negative worker-failure, invalid-output and Gmsh-import cases use injected faults; timeout executes a real worker','Full historical regression campaign excluded by scope'])
target=ROOT/'docs/architecture/evidence/cad251-native-placement/final-receipt.json';target.parent.mkdir(parents=True,exist_ok=True);target.write_text(json.dumps(receipt,indent=2))
print('RECEIPT_PASS',target,'max errors',max(r['error'] for r in rows),max(r['imbalance'] for r in rows))
