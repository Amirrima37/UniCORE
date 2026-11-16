import sys,os,json,base64,copy,uuid
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
OUT=Path((ROOT/'interference-attempt.txt').read_text())
os.environ['UNICORE_CAD_JOB_TEMP']=str(OUT/'rejection-native');os.environ['UNICORE_INTERFERENCE_CACHE_ROOT']=str(OUT/'pair-cache')
from assembly_interference import classify
from gmsh_study import mesh_study
p=json.loads((OUT/'source-part.json').read_text());raw=base64.b64decode(p['cad_base64'])
# Reverse the top-level orientation of this actual OCCT ASCII BREP. Its topology
# still parses, but its signed material volume must fail native solid validation.
assert raw.endswith(b'+1 0 ')
invalid=raw[:-5]+b'-1 0 '
r=classify(invalid,raw,use_cache=False);assert r['classification']=='INVALID',r
rows=[dict(case='reversed-invalid-solid',result=r)]
q=copy.deepcopy(p);q['id']=str(uuid.uuid4());q['instance_uuid']=str(uuid.uuid4());q['position']=[.05,0,0]
def blocked(label):
    try:mesh_study(ROOT,dict(parts=[p,q]),.05)
    except ValueError as error:
        assert label in str(error) and q['instance_uuid'] in str(error),error
        rows.append(dict(case=label,error=str(error)))
    else:raise AssertionError('Unsafe assembly accepted')
blocked('OVERLAPPING')
with patch('assembly_interference.classify',return_value=dict(classification='INCONCLUSIVE',diagnostic='Injected Boolean uncertainty',native_calls=1,cache_hit=False)):
    blocked('INCONCLUSIVE')
(OUT/'rejection.json').write_text(json.dumps(rows,indent=2))
print('INTERFERENCE_REJECTION_PASS')
