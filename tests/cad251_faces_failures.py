import os,sys,json,base64,hashlib,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
OUT=Path((ROOT/'face-identity-attempt.txt').read_text().strip());os.environ['UNICORE_CAD_JOB_TEMP']=str(OUT/'failure-native')
from native_occt import run
from gmsh_study import cad_asset
rows=[]
def reject(name,call):
    try:call()
    except ValueError as error:rows.append(dict(case=name,passed=True,error=str(error)))
    else:raise AssertionError('Unsafe success: '+name)
p=json.loads((OUT/'source-part.json').read_text());raw=base64.b64decode(p['cad_base64'])
reject('real-native-operation-failure',lambda:run(raw,'unsupported-operation'))
# Real STEP reader failure, with units still present: remove topology entities
# referenced by the solid's closed shell, retaining the original source syntax.
source=(ROOT/'tests/fixtures/step/bar.step').read_bytes()
import re
broken=re.sub(rb'#[0-9]+\s*=\s*ADVANCED_FACE\b[^;]*;',b'',source,flags=re.S)
reject('invalid-step-native-reader',lambda:run(broken,'step'))
q=copy.deepcopy(p);q.update(cad_format='step',cad_base64=base64.b64encode(broken).decode(),cad_sha256=hashlib.sha256(broken).hexdigest())
reject('invalid-step-pipeline',lambda:cad_asset(q))
os.environ['UNICORE_OCCT_TIMEOUT_S']='0'
reject('real-native-timeout',lambda:run(raw))
os.environ.pop('UNICORE_OCCT_TIMEOUT_S')
cancel=OUT/'native-cancel';cancel.write_text('cancel');os.environ['UNICORE_NATIVE_CANCEL_FILE']=str(cancel)
reject('real-native-cancellation',lambda:run(raw))
os.environ.pop('UNICORE_NATIVE_CANCEL_FILE')
(OUT/'negative-native.json').write_text(json.dumps(rows,indent=2))
print('FACE_NATIVE_FAILURE_PASS',len(rows))
