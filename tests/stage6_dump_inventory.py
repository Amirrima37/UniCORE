"""Read existing AMD64 minidumps without loading executables or creating dumps.
Stack candidates are raw stack words inside loaded modules, NOT unwound frames.
"""
import hashlib, json, mmap, os, struct
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'docs/workbench-2/stage6-final';out.mkdir(exist_ok=True)
rows=[]
for path in sorted((Path(os.environ['LOCALAPPDATA'])/'CrashDumps').glob('*Godot*.dmp')):
    with path.open('rb') as f, mmap.mmap(f.fileno(),0,access=mmap.ACCESS_READ) as b:
        def u32(p):return struct.unpack_from('<I',b,p)[0]
        def u64(p):return struct.unpack_from('<Q',b,p)[0]
        streams={u32( u32(12)+12*i):(u32(u32(12)+12*i+4),u32(u32(12)+12*i+8)) for i in range(u32(8))}
        ranges=[]
        if 9 in streams:
            ml=streams[9][1];data_rva=u64(ml+8)
            for i in range(u64(ml)):
                p=ml+16+16*i;addr,size=u64(p),u64(p+8)
                ranges.append((addr,size,data_rva));data_rva+=size
        def memory(addr,size):
            for start,length,rva in ranges:
                if start<=addr and addr+size<=start+length:return b[rva+addr-start:rva+addr-start+size]
            return b''
        def string(p):return b[p+4:p+4+u32(p)].decode('utf-16-le','replace')
        mods=[]
        m=streams[4][1]
        for i in range(u32(m)):
            p=m+4+108*i
            cvsize,cvrva=u32(p+76),u32(p+80)
            mods.append(dict(base=u64(p),size=u32(p+8),timestamp=u32(p+16),path=string(u32(p+20)),codeview=b[cvrva:cvrva+cvsize].hex()))
        def mapped(a):
            for mod in mods:
                if mod['base']<=a<mod['base']+mod['size']:return Path(mod['path']).name+'+'+hex(a-mod['base'])
            return None
        e=streams[6][1];ctx=u32(e+164)
        regs={k:hex(u64(ctx+p)) for k,p in [('rax',120),('rcx',128),('rdx',136),('rsp',152),('rbp',160),('rip',248)]}
        row=dict(path=str(path),bytes=path.stat().st_size,sha256=hashlib.file_digest(f,'sha256').hexdigest(),thread=u32(e),exception=hex(u32(e+8)),exception_address=hex(u64(e+24)),site=mapped(u64(e+24)),parameters=[hex(u64(e+40+8*i)) for i in range(min(u32(e+32),15))],registers=regs,modules=mods)
        row['instruction_bytes']=memory(u64(e+24)-8,24).hex()
        row['rcx_plus_20_bytes']=memory(int(regs['rcx'],16)+32,8).hex()
        row['rax_plus_68_readable_in_dump']=bool(memory(int(regs['rax'],16)+104,8))
        t=streams[3][1];candidates=[]
        for i in range(u32(t)):
            p=t+4+48*i
            if u32(p)!=row['thread']:continue
            start,size,rva=u64(p+24),u32(p+32),u32(p+36)
            offset=max(0,int(regs['rsp'],16)-start)
            for j in range(offset,min(size,offset+2048)-7,8):
                word=memory(start+j,8) if not rva else b[rva+j:rva+j+8]
                if len(word)!=8:continue
                val=struct.unpack('<Q',word)[0];name=mapped(val)
                if name:candidates.append(dict(stack_offset=hex(j-offset),address=hex(val),module_offset=name))
        row['raw_stack_module_candidates_not_unwound']=candidates
        rows.append(row)
exe=root/'.tools/godot/Godot_v4.0-stable_win64.exe'
data=exe.read_bytes();pe=struct.unpack_from('<I',data,60)[0]
identity=dict(path=str(exe),bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),pe_timestamp=struct.unpack_from('<I',data,pe+8)[0],image_size=struct.unpack_from('<I',data,pe+24+56)[0])
(out/'dump-inventory.json').write_text(json.dumps(dict(current_executable=identity,dumps=rows),indent=2))
print(json.dumps(dict(current_executable=identity,dumps=[{k:v for k,v in r.items() if k not in ['modules','raw_stack_module_candidates_not_unwound']} for r in rows]),indent=2))
