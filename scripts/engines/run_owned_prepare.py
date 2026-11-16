import sys,json,os
from pathlib import Path
from owned_execution import execute
job=Path(sys.argv[1]).resolve()
receipt=execute(job,[sys.executable,str(Path(__file__).with_name('quadratic_prepare.py')),str(job)],120,int(sys.argv[2]) if len(sys.argv)>2 else os.getppid(),{'model.inp':64*1024*1024,'canonical-model.json':128*1024*1024})
(job/'prepare-receipt.json').write_text(json.dumps(receipt))
raise SystemExit(0 if receipt['state']=='completed' else 1)
