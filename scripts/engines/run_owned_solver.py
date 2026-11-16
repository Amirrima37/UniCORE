"""Bounded pinned CalculiX child; receipt follows actual wait and output checks."""
import sys,json,os
from pathlib import Path
from owned_execution import execute
job=Path(sys.argv[1]).resolve();executable=Path(sys.argv[2]).resolve()
from artifact_retention import begin,finish
begin(job)
receipt=execute(job,[str(executable),'-i','model'],float(sys.argv[3]) if len(sys.argv)>3 else 120,int(sys.argv[4]) if len(sys.argv)>4 else os.getppid(),{'model.dat':32*1024*1024,'model.frd':128*1024*1024})
if receipt['state']=='completed':
    log=(job/'stdout.txt').read_text(errors='replace')+(job/'stderr.txt').read_text(errors='replace')
    if '*ERROR' in log or 'Job finished' not in log or not (job/'model.dat').exists() or not (job/'model.frd').exists():receipt['state']='failed'
if receipt['error']:(job/'launcher-error.txt').write_text(receipt['error'])
tmp=job/'receipt.tmp';tmp.write_text(json.dumps(receipt));tmp.replace(job/'receipt.json')
finish(job)
raise SystemExit(0 if receipt['state']=='completed' else 1)
