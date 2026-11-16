import json,statistics
from pathlib import Path
rows=[]
for f in ['hpc22-original','hpc22-internal','hpc22-passive']:
 data=json.loads(Path('docs/hpc-optimization/'+f+'.json').read_text())
 for label in dict.fromkeys(d['label'] for d in data):
  sample=[d for d in data if d['label']==label]
  metrics={k:statistics.median(d[k] for d in sample) for k,v in sample[0].items() if isinstance(v,(float,int)) and not isinstance(v,bool)}
  rows.append(dict(source=f,label=label,n=len(sample),median=metrics,wall_min=min(d['wall_s'] for d in sample),wall_max=max(d['wall_s'] for d in sample)))
Path('docs/hpc-optimization/hpc22-summary.json').write_text(json.dumps(rows,indent=2))
for row in rows:
 m=row['median'];print(row['label'],row['n'],{k:round(m[k],3) for k in m if k in ['wall_s','cpu_s','busy_cores','preparation_ms','assembly_ms','solve_ms','post_ms','serialization_ms','parse_and_model_ms','model_in_parse_ms','integration_ms','scatter_ms','csr_ms','constraint_ms','pcg_ms','other_busy_cores']},'peak MiB',m['peak_working_set_bytes']/1048576)
