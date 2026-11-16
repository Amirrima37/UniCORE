"""Observed Windows peak working set for a subprocess handle (bytes)."""
import ctypes as C
from ctypes import wintypes as W
class Counters(C.Structure):
    _fields_=[('cb',W.DWORD),('faults',W.DWORD)]+[(name,C.c_size_t) for name in ['peak_working_set','working_set','peak_paged','paged','peak_nonpaged','nonpaged','pagefile','peak_pagefile']]
def peak_working_set(process):
    info=Counters();info.cb=C.sizeof(info)
    api=C.windll.psapi.GetProcessMemoryInfo;api.argtypes=[C.c_void_p,C.c_void_p,W.DWORD]
    return info.peak_working_set if api(C.c_void_p(int(process._handle)),C.byref(info),C.sizeof(info)) else 0
