import ctypes as C,ctypes.wintypes as W,json,sys,os
from pathlib import Path
k=C.WinDLL('kernel32',use_last_error=True);k.OpenProcess.argtypes=[W.DWORD,W.BOOL,W.DWORD];k.OpenProcess.restype=C.c_void_p;k.CloseHandle.argtypes=[C.c_void_p]
class Memory(C.Structure):
    _fields_=[('cb',W.DWORD),('faults',W.DWORD)]+[(n,C.c_size_t) for n in ['peak_working_set','working_set','peak_paged','paged','peak_nonpaged','nonpaged','pagefile','peak_pagefile','private_commit']]
h=k.OpenProcess(0x410,False,int(sys.argv[1]));m=Memory();m.cb=C.sizeof(m)
ps=C.WinDLL('psapi');ps.GetProcessMemoryInfo.argtypes=[C.c_void_p,C.c_void_p,W.DWORD]
assert h and ps.GetProcessMemoryInfo(h,C.byref(m),m.cb)
k.CloseHandle(h)
class Entry(C.Structure):
    _fields_=[('size',W.DWORD),('usage',W.DWORD),('pid',W.DWORD),('heap',C.c_size_t),('module',W.DWORD),('threads',W.DWORD),('parent',W.DWORD),('priority',W.LONG),('flags',W.DWORD),('exe',W.WCHAR*260)]
k.CreateToolhelp32Snapshot.argtypes=[W.DWORD,W.DWORD];k.CreateToolhelp32Snapshot.restype=C.c_void_p
k.Process32FirstW.argtypes=[C.c_void_p,C.POINTER(Entry)];k.Process32NextW.argtypes=[C.c_void_p,C.POINTER(Entry)]
s=k.CreateToolhelp32Snapshot(2,0);entry=Entry();entry.size=C.sizeof(entry);processes=[]
more=k.Process32FirstW(s,C.byref(entry))
while more:
    processes.append(dict(pid=entry.pid,parent=entry.parent,exe=entry.exe));more=k.Process32NextW(s,C.byref(entry))
k.CloseHandle(s)
descendants=[];parents={int(sys.argv[1])}
while True:
    children=[p for p in processes if p['parent'] in parents and p['pid'] not in parents and p['pid']!=os.getpid()]
    if not children:break
    descendants.extend(children);parents.update(p['pid'] for p in children)
output_bytes=0
for directory in sys.argv[2:]:
    for path in Path(directory).rglob('*'):
        try:
            if path.is_file():output_bytes+=path.stat().st_size
        except FileNotFoundError:pass
print(json.dumps(dict(working_set=m.working_set,peak_working_set=m.peak_working_set,private_commit=m.private_commit,peak_commit=m.peak_pagefile,system_process_count=len(processes),owned_descendants=descendants,output_bytes=output_bytes)))
