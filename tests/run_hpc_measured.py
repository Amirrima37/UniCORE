"""Run a Windows native benchmark with process CPU and wall-time accounting."""
import ctypes,json,subprocess,sys,time
from ctypes import wintypes
from pathlib import Path
prefix=Path(sys.argv[1]);start=time.perf_counter()
with prefix.with_suffix('.csv').open('w') as log:
 p=subprocess.Popen(sys.argv[2:],stdout=log,stderr=subprocess.PIPE)
 _,errors=p.communicate(timeout=600)
 wall=time.perf_counter()-start
 creation,exit_time,kernel,user=(wintypes.FILETIME() for _ in range(4))
 get=ctypes.windll.kernel32.GetProcessTimes
 get.argtypes=[wintypes.HANDLE]+[ctypes.POINTER(wintypes.FILETIME)]*4
 if not get(wintypes.HANDLE(int(p._handle)),ctypes.byref(creation),ctypes.byref(exit_time),ctypes.byref(kernel),ctypes.byref(user)):raise ctypes.WinError()
 seconds=lambda t:((t.dwHighDateTime<<32)|t.dwLowDateTime)/1e7
 data={'wall_s':wall,'cpu_s':seconds(kernel)+seconds(user),'average_busy_cores':(seconds(kernel)+seconds(user))/wall,'exit_code':p.returncode,'stderr':errors.decode(errors='replace')}
 prefix.with_suffix('.json').write_text(json.dumps(data,indent=2));print(data)
 if p.returncode:raise SystemExit(p.returncode)
