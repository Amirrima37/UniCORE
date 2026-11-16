"""Probe an externally launched Windows descendant without reusing a PID handle."""
import ctypes as C
import ctypes.wintypes as W
import json
import sys
k = C.WinDLL('kernel32', use_last_error=True)
k.OpenProcess.argtypes = [W.DWORD, W.BOOL, W.DWORD]
k.OpenProcess.restype = C.c_void_p
k.WaitForSingleObject.argtypes = [C.c_void_p, W.DWORD]
k.CloseHandle.argtypes = [C.c_void_p]
h = k.OpenProcess(0x100000, False, int(sys.argv[1]))
alive = bool(h and k.WaitForSingleObject(h, 0) == 258)
if h:
    k.CloseHandle(h)
print(json.dumps(alive))
