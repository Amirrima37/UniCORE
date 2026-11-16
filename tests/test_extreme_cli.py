import subprocess,json
from pathlib import Path
root=Path(__file__).resolve().parents[1];directory=root/'.tools/extreme-cli';directory.mkdir(exist_ok=True)
valid='UNICORE_JOB 1 static_structural\n4 1\n0 0 0\n1 0 0\n0 1 0\n0 0 1\n4 0 1 2 3 1000 0\n'+'0 1 0\n'*12
cases={'empty':'','version':valid.replace('JOB 1','JOB 99'),'negative_count':valid.replace('4 1\n','-1 1\n',1),'bad_index':valid.replace('4 0 1 2 3','4 0 1 2 9'),'unsupported':valid.replace('static_structural','cfd')}
rows=[]
for name,content in cases.items():
 job=directory/(name+'.ucjob');job.write_text(content);out=directory/name
 r=subprocess.run([str(root/'bin/unicore_solver.exe'),'--job',str(job),'--output',str(out)],capture_output=True,text=True,timeout=10);assert r.returncode==2,(name,r.stderr)
 state=json.loads((out/'status.json').read_text());assert state['state']=='Failed';rows.append({'case':name,'exit':r.returncode,'error':state.get('error')})
unicode=directory/('unicode_'+''.join(chr(c) for c in [0x43f,0x443,0x442,0x44c])+' & spaces');unicode.mkdir(exist_ok=True);job=unicode/'model.ucjob';job.write_text(valid)
r=subprocess.run([str(root/'bin/unicore_solver.exe'),'--job',str(job),'--output',str(unicode/'output')],capture_output=True,text=True,timeout=10);assert r.returncode==0,r.stderr
assert json.loads((unicode/'output/results.json').read_text())['ok'];rows.append({'case':'Unicode and shell metacharacters in paths','exit':0})
(root/'docs/extreme-mode/cli-validation.json').write_text(json.dumps(rows,indent=2));print('CLI version, indices, counts, unsupported analyses and Unicode paths PASS')
