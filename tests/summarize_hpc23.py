"""Aggregate every HPC 2.3 sample, including failures and resource skips."""
import json,statistics
from pathlib import Path
base=Path('docs/hpc-optimization');summary=[];tables=[]
for name in ['baseline','small','large','diagnostic']:
 p=base/('hpc23-'+name+'.json')
 if not p.exists():continue
 rows=json.loads(p.read_text());groups={}
 for r in rows:
  requested=r.get('method',r.get('label',''));actual=r.get('selected_preconditioner',requested)
  display=requested+(' -> '+actual+' (fallback)' if r.get('preconditioner_fallback') else '')
  if 'threads' in r:display+=' / '+str(r['threads'])+' threads'
  key=(r.get('workload','baseline'),display)
  groups.setdefault(key,[]).append(r)
 table=['|Workload / DOF|Method|n|Iterations|Setup ms|PCG ms|Solve ms|Wall s [min-max]|Peak MiB|Precond. MiB|','|---|---|---:|---:|---:|---:|---:|---:|---:|---:|']
 for (workload,method),sample in groups.items():
  good=[r for r in sample if r.get('exit_code',0)==0 and not r.get('skipped')]
  rec=dict(source=name,workload=workload,method=method,n=len(good),failures=[r for r in sample if r not in good])
  if good:
   rec['median']={k:statistics.median(r[k] for r in good if k in r) for k,v in good[0].items() if isinstance(v,(int,float)) and not isinstance(v,bool)}
   rec['wall_min']=min(r['wall_s'] for r in good);rec['wall_max']=max(r['wall_s'] for r in good)
   for key in ['analytic_max_error','relative_solution_difference','relative_residual']:
    if key in good[0]:rec['maximum_'+key]=max(r[key] for r in good)
   m=rec['median'];setup=m.get('linear_preconditioner_ms',0);pcg=m.get('linear_pcg_ms',m.get('pcg_ms',0))
   table.append(f"|{workload} / {int(m.get('dof',107811))}|{method}|{len(good)}|{m.get('iterations',0):g}|{setup:.3f}|{pcg:.3f}|{m['solve_ms']:.3f}|{m['wall_s']:.3f} [{rec['wall_min']:.3f}-{rec['wall_max']:.3f}]|{m['peak_working_set_bytes']/1048576:.2f}|{m.get('preconditioner_bytes',0)/1048576:.3f}|")
  else:table.append(f'|{workload} / {sample[0].get("dof", "")}|{method}|0|resource skip / failed||||||')
  summary.append(rec)
 tables+=['### '+name.capitalize()+' measurements','\n'.join(table),'']
(base/'hpc23-summary.json').write_text(json.dumps(summary,indent=2));(base/'hpc23-tables.md').write_text('\n\n'.join(tables))
print('\n'.join(str((r['workload'],r['method'],r['n'],round(r.get('median',{}).get('wall_s',0),3))) for r in summary))
