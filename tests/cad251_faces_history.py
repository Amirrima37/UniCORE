import os,sys,json,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts/engines'))
OUT=Path((ROOT/'face-identity-attempt.txt').read_text().strip());os.environ['UNICORE_CAD_JOB_TEMP']=str(OUT/'history-native')
Path(os.environ["UNICORE_CAD_JOB_TEMP"]).mkdir(parents=True,exist_ok=True)
from cad_model import evaluate
base=dict(id='bar',type='Box',dimensions=[.1,.4,.1])
tool=dict(id='cap',type='Box',dimensions=[.04,.06,.04],position=[0,.21,0])
graph=dict(schema=1,units='m',root='union',nodes=[base,tool,dict(id='union',type='Union',base='bar',tool='cap')])
first=evaluate(dict(model=graph,part_id='history',quality=8))
edited=copy.deepcopy(graph);edited['nodes'][1]['position'][1]=.23
second=evaluate(dict(model=edited,part_id='history',quality=8))
assert first['ok'] and second['ok']
preserved=set(first['part']['cad_faces'])&set(second['part']['cad_safe_continuations'])
assert preserved
for name,value in [('original',first),('edited',second)]:
    (OUT/('history-'+name+'.json')).write_text(json.dumps(value))
print('FACE_HISTORY_PASS',len(preserved),'native preserved faces')
