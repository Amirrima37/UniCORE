"""Reuse established assertions with fresh HPC24 evidence and 10-second case caps."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
for name in ['test_extreme_cli','test_extreme_checkpoint','test_extreme_configurations','test_hpc23_options']:
 p=root/'tests'/(name+'.py');s=p.read_text()
 for old,new in [('docs/extreme-mode/cli-validation.json','docs/hpc-optimization/hpc24-cli.json'),('docs/extreme-mode/restart.json','docs/hpc-optimization/hpc24-restart.json'),('docs/extreme-mode/configurations.json','docs/hpc-optimization/hpc24-configurations.json'),('.tools/extreme-cli','.tools/hpc24-cli'),('.tools/extreme-checkpoint','.tools/hpc24-checkpoint'),('.tools/extreme-config','.tools/hpc24-config'),('.tools/hpc23-options','.tools/hpc24-options'),('hpc23-options.json','hpc24-options.json'),('timeout=30','timeout=10'),('timeout=60','timeout=10')]:s=s.replace(old,new)
 if name=='test_hpc23_options':s=s.replace('hpc23-checkpoint-','hpc24-checkpoint-').replace('hpc23-options-validation.json','hpc24-options-validation.json').replace('hpc23-cancellation.json','hpc24-cancellation.json')
 exec(compile(s,str(p),'exec'),{'__file__':str(p),'__name__':'__main__'})
