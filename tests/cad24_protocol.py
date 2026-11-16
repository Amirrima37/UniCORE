import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
import sys,json,os,time,hashlib,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
from native_occt import SDK,EXE,run,verify_installation
from owned_execution import execute
OUT=output_dir('CAD/cad24-completion');fixtures=OUT/'fixtures';fixtures.mkdir(exist_ok=True)
os.environ['PATH']=str(SDK/'ucrt64/bin')+';D:/msys64/ucrt64/bin;'+os.environ.get('PATH','')
verify_installation();factory=execute(fixtures,[str(SDK/'make_occt_fixtures.exe')],30,os.getpid())
assert factory['state']=='completed',factory
rows=[]
for name in ['inverted.brep','open-shell.brep']:
    result,_=run((fixtures/name).read_bytes())
    assert result['validation']['status'] in ['INVALID','UNSUPPORTED'],result
    rows.append(dict(case=name,outcome='CORRECT_REJECTION',native=result))
_,box=run(action='box',dimensions=[.1,.2,.1])
for name in ['unknown-schema','traversal','wrong-hash','oversize-request','oversize-brep','open-shell-step','empty-brep']:
    job=OUT/'protocol'/(name+'-'+str(time.time_ns()));job.mkdir(parents=True)
    raw=(fixtures/'open-shell.step').read_bytes() if name=='open-shell-step' else b'' if name=='empty-brep' else box
    (job/'input.brep').write_bytes(raw)
    q=dict(schema=1,units='m',action='step' if name=='open-shell-step' else 'validate',input='input.brep',input_hashes=[hashlib.sha256(raw).hexdigest()],operation_id=str(uuid.uuid4()),feature_id='fixture')
    if name=='unknown-schema':q['schema']=999
    if name=='traversal':q['input']='../outside.brep'
    if name=='wrong-hash':q['input_hashes']=['0'*64]
    if name=='oversize-request':q['padding']='X'*(1024*1024)
    if name=='oversize-brep':
        with (job/'input.brep').open('wb') as f:f.seek(64*1024*1024);f.write(b'X')
    (job/'request.json').write_text(json.dumps(q))
    receipt=execute(job,[str(EXE),'request.json'],30,os.getpid(),{'response.json':16*1024*1024,'output.brep':64*1024*1024})
    result=json.loads((job/'response.json').read_text())
    assert receipt['exit_code']!=0 and result.get('ok') is False and not (job/'output.brep').exists(),(name,result)
    rows.append(dict(case=name,outcome='CORRECT_REJECTION',native=result,process=receipt,job=str(job)))
    if name=='oversize-brep':(job/'input.brep').unlink() # Generated 64 MiB+1 zero-padding fixture; generator and rejection retained.
(OUT/'protocol-and-invalid-geometry.json').write_text(json.dumps(dict(factory=factory,fixtures={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in fixtures.glob('*') if p.suffix in ['.step','.brep']},cases=rows),indent=2))
print('CAD24_PROTOCOL_PASS')
