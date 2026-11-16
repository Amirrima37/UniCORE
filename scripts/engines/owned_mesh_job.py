"""Windows process containment for Gmsh volume workers."""
import ctypes as C,ctypes.wintypes as W
P=C.c_void_p
def resume_owned_process(pid):
    """Resume only threads belonging to our CREATE_SUSPENDED child (Win32 APIs)."""
    class ENTRY(C.Structure):
        _fields_=[('size',W.DWORD),('usage',W.DWORD),('thread',W.DWORD),('owner',W.DWORD),('priority',W.LONG),('delta',W.LONG),('flags',W.DWORD)]
    k=C.WinDLL('kernel32',use_last_error=True)
    k.CreateToolhelp32Snapshot.argtypes=[W.DWORD,W.DWORD];k.CreateToolhelp32Snapshot.restype=P
    k.Thread32First.argtypes=[P,C.POINTER(ENTRY)];k.Thread32Next.argtypes=[P,C.POINTER(ENTRY)]
    k.OpenThread.argtypes=[W.DWORD,W.BOOL,W.DWORD];k.OpenThread.restype=P
    k.ResumeThread.argtypes=[P];k.CloseHandle.argtypes=[P]
    snapshot=k.CreateToolhelp32Snapshot(4,0);found=False
    if snapshot==P(-1).value:raise OSError('Cannot enumerate suspended child threads')
    try:
        entry=ENTRY();entry.size=C.sizeof(entry);more=k.Thread32First(snapshot,C.byref(entry))
        while more:
            if entry.owner==pid:
                handle=k.OpenThread(2,False,entry.thread)
                if not handle:raise OSError('Cannot resume owned child thread')
                try:
                    if k.ResumeThread(handle)==-1:raise OSError('Cannot resume owned child')
                    found=True
                finally:k.CloseHandle(handle)
            more=k.Thread32Next(snapshot,C.byref(entry))
    finally:k.CloseHandle(snapshot)
    if not found:raise OSError('Suspended owned process disappeared')
class BASIC(C.Structure):
    _fields_=[('ProcessTime',C.c_int64),('JobTime',C.c_int64),('Flags',W.DWORD),('MinWorking',C.c_size_t),('MaxWorking',C.c_size_t),('ActiveLimit',W.DWORD),('Affinity',C.c_size_t),('Priority',W.DWORD),('Scheduling',W.DWORD)]
class IO(C.Structure):_fields_=[(name,C.c_uint64) for name in ['ReadOp','WriteOp','OtherOp','ReadBytes','WriteBytes','OtherBytes']]
class EXT(C.Structure):_fields_=[('Basic',BASIC),('IO',IO),('ProcessMemory',C.c_size_t),('JobMemory',C.c_size_t),('PeakProcess',C.c_size_t),('PeakJob',C.c_size_t)]
class Job:
    def __init__(self,memory_mb,parent):
        self.k=C.WinDLL('kernel32',use_last_error=True);k=self.k
        k.CreateJobObjectW.argtypes=[P,W.LPCWSTR];k.CreateJobObjectW.restype=P;k.SetInformationJobObject.argtypes=[P,C.c_int,P,W.DWORD]
        k.AssignProcessToJobObject.argtypes=[P,P];k.QueryInformationJobObject.argtypes=[P,C.c_int,P,W.DWORD,P]
        k.OpenProcess.argtypes=[W.DWORD,W.BOOL,W.DWORD];k.OpenProcess.restype=P;k.WaitForSingleObject.argtypes=[P,W.DWORD];k.CloseHandle.argtypes=[P]
        self.handle=k.CreateJobObjectW(None,None);self.parent=k.OpenProcess(0x100000,False,parent)
        limits=EXT();limits.Basic.Flags=0x2000|0x100;limits.ProcessMemory=memory_mb*1024*1024
        if not self.handle or not self.parent or not k.SetInformationJobObject(self.handle,9,C.byref(limits),C.sizeof(limits)):self.close();raise OSError('Cannot establish owned Gmsh Job Object/owner monitor')
    def assign(self,process):
        if not self.k.AssignProcessToJobObject(self.handle,P(int(process._handle))):raise OSError('Cannot contain Gmsh child')
    def owner_alive(self):return self.k.WaitForSingleObject(self.parent,0)==258
    def peak(self):
        info=EXT();self.k.QueryInformationJobObject(self.handle,9,C.byref(info),C.sizeof(info),None);return info.PeakProcess
    def close(self):
        if self.parent:self.k.CloseHandle(self.parent);self.parent=None
        if self.handle:self.k.CloseHandle(self.handle);self.handle=None
