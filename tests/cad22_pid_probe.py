"""Independent Windows liveness probe for a child owned by a Python launcher."""
import ctypes as C,sys
k=C.WinDLL('kernel32',use_last_error=True);k.OpenProcess.argtypes=[C.c_ulong,C.c_int,C.c_ulong];k.OpenProcess.restype=C.c_void_p
k.WaitForSingleObject.argtypes=[C.c_void_p,C.c_ulong];k.CloseHandle.argtypes=[C.c_void_p]
handle=k.OpenProcess(0x100000,False,int(sys.argv[1]))
if not handle:raise SystemExit(1)
status=k.WaitForSingleObject(handle,0);k.CloseHandle(handle)
raise SystemExit(0 if status==258 else 1)
