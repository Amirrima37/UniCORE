"""Local Windows debug-event capture. No installation or registry changes. 40s cap."""
import ctypes as C, ctypes.wintypes as W, subprocess, time, json, struct
from pathlib import Path
out=Path('docs/architecture/evidence/godot472-valid-minimal');out.mkdir(exist_ok=True)
k=C.WinDLL('kernel32',use_last_error=True);dbg=C.WinDLL('dbghelp',use_last_error=True)
P=C.c_void_p;D=W.DWORD
k.WaitForDebugEvent.argtypes=[P,D];k.ContinueDebugEvent.argtypes=[D,D,D]
k.OpenProcess.argtypes=[D,W.BOOL,D];k.OpenProcess.restype=P
k.OpenThread.argtypes=[D,W.BOOL,D];k.OpenThread.restype=P
k.GetThreadContext.argtypes=[P,P];k.ReadProcessMemory.argtypes=[P,P,P,C.c_size_t,P]
k.GetFinalPathNameByHandleW.argtypes=[P,W.LPWSTR,D,D]
k.CreateFileW.argtypes=[W.LPCWSTR,D,D,P,D,D,P];k.CreateFileW.restype=P
k.CloseHandle.argtypes=[P]
dbg.MiniDumpWriteDump.argtypes=[P,D,P,D,P,P,P]
log=open(out/'debuggee.log','wb')
proc=subprocess.Popen([r'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe','--headless','--path','.tools/crash-minimal','--quit'],creationflags=2,stdout=log,stderr=log)
events=[];modules=[];start=time.monotonic();fault=None
def u64(buffer,offset):return struct.unpack_from('<Q',buffer,offset)[0]
def read(handle,address,count):
    b=C.create_string_buffer(count);done=C.c_size_t()
    if k.ReadProcessMemory(handle,P(address),b,count,C.byref(done)):return b.raw[:done.value]
    return b''
while time.monotonic()-start<25:
    event=C.create_string_buffer(1024)
    if not k.WaitForDebugEvent(event,100):continue
    code,pid,tid=struct.unpack_from('<III',event)
    status=0x10002
    if code in (3,6):
        base=u64(event,40 if code==3 else 24);file=u64(event,16)
        name=C.create_unicode_buffer(4096)
        k.GetFinalPathNameByHandleW(P(file),name,4096,0)
        modules.append(dict(base=hex(base),path=name.value))
        if file:k.CloseHandle(P(file))
    if code==1:
        exception=struct.unpack_from('<I',event,16)[0];first=struct.unpack_from('<I',event,168)[0]
        events.append(dict(exception=hex(exception),first_chance=first,tid=tid,address=hex(u64(event,32))))
        status=0x80010001
        if exception==0x80000003:status=0x10002
        if exception==0xc0000005:
            process=k.OpenProcess(0x1f0fff,False,pid);thread=k.OpenThread(0x1fffff,False,tid)
            context_storage=C.create_string_buffer(1250)
            aligned=(C.addressof(context_storage)+15)&~15
            C.c_uint32.from_address(aligned+48).value=0x10001f
            context_ok=bool(k.GetThreadContext(thread,P(aligned)))
            context=C.string_at(aligned,1232)
            fault=dict(pid=pid,tid=tid,first_chance=first,exception=hex(exception),address=hex(u64(event,32)),context_ok=context_ok,rip=hex(u64(context,248)),rsp=hex(u64(context,152)))
            fault['access_type']=u64(event,48);fault['access_address']=hex(u64(event,56));fault['instruction_bytes']=read(process,u64(context,248),32).hex();fault['registers']={name:hex(u64(context,offset)) for name,offset in [('rax',120),('rcx',128),('rdx',136),('rbx',144),('rsp',152),('rbp',160),('rsi',168),('rdi',176),('r8',184),('r9',192),('r10',200),('r11',208),('r12',216),('r13',224),('r14',232),('r15',240),('rip',248)]}
            # A suspended-process minidump preserves modules and all thread stacks.
            dump=k.CreateFileW(str((out/'app-shell.dmp').resolve()),0x40000000,0,None,2,0,None)
            fault['dump_written']=bool(dbg.MiniDumpWriteDump(process,pid,dump,0x1000,None,None,None))
            fault['dump_error']=C.get_last_error();k.CloseHandle(dump)
            dbg.SymInitialize.argtypes=[P,W.LPCSTR,W.BOOL];dbg.SymInitialize.restype=W.BOOL
            dbg.SymFunctionTableAccess64.argtypes=[P,C.c_ulonglong];dbg.SymFunctionTableAccess64.restype=P
            dbg.SymGetModuleBase64.argtypes=[P,C.c_ulonglong];dbg.SymGetModuleBase64.restype=C.c_ulonglong
            dbg.StackWalk64.argtypes=[D,P,P,P,P,P,P,P,P]
            dbg.SymInitialize(process,None,True)
            frame=C.create_string_buffer(1024)
            for offset,value in [(0,u64(context,248)),(32,u64(context,160)),(48,u64(context,152))]:
                struct.pack_into('<Q',frame,offset,value);struct.pack_into('<I',frame,offset+12,3)
            stack=[]
            for _ in range(32):
                if not dbg.StackWalk64(0x8664,process,thread,frame,P(aligned),None,C.cast(dbg.SymFunctionTableAccess64,P),C.cast(dbg.SymGetModuleBase64,P),None):break
                address=u64(frame,0)
                if not address:break
                module=dbg.SymGetModuleBase64(process,address)
                stack.append(dict(pc=hex(address),module_base=hex(module),offset=hex(address-module)))
            fault['stack']=stack
            k.CloseHandle(thread);k.CloseHandle(process)
            status=0x80010001
    k.ContinueDebugEvent(pid,tid,status)
    if code==5:
        exit_code=struct.unpack_from('<I',event,16)[0]
        events.append(dict(exit=exit_code,hex=hex(exit_code)));break
else:
    proc.kill();events.append(dict(timeout=True))
# Preserve evidence even if Windows has not completed debug-process teardown.
try:proc.wait(timeout=5)
except subprocess.TimeoutExpired:events.append(dict(teardown_timeout=True))
log.close()
(out/'debug-events.json').write_text(json.dumps(dict(events=events,modules=modules,fault=fault,seconds=time.monotonic()-start),indent=2))
print(json.dumps(fault),flush=True)






