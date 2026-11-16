"""Summarize repeated HPC samples without hiding variability."""
import csv,json,statistics
from pathlib import Path
out={}
for name in ['before','after']:
 rows=json.loads(Path(f'docs/hpc-optimization/hpc21-{name}.json').read_text())
 out[name]={}
 for t in sorted({r['threads'] for r in rows}):
  sample=[r for r in rows if r['threads']==t]
  out[name][t]={k:{'median':statistics.median(r[k] for r in sample),'min':min(r[k] for r in sample),'max':max(r[k] for r in sample)} for k in ['wall_s','assembly_ms','solve_ms','peak_working_set_bytes']}
path=Path('docs/hpc-optimization/hpc21-paired.csv')
if path.exists():
 rows=list(csv.DictReader(path.open()));out['paired']={}
 for t in sorted({int(r['threads']) for r in rows}):
  out['paired'][t]={}
  for method in ['serial_scatter','row_owned']:
   sample=[r for r in rows if int(r['threads'])==t and r['method']==method]
   out['paired'][t][method]={k:{'median':statistics.median(float(r[k]) for r in sample),'min':min(float(r[k]) for r in sample),'max':max(float(r[k]) for r in sample)} for k in ['integration_ms','scatter_ms','total_ms']}
Path('docs/hpc-optimization/hpc21-summary.json').write_text(json.dumps(out,indent=2))
for t,row in out.get('paired',{}).items():print(t,[(k,round(v['total_ms']['median'],1),round(v['scatter_ms']['median'],1)) for k,v in row.items()])
