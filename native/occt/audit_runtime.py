import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[2]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
import pathlib,subprocess,re,json
ROOT=pathlib.Path(__file__).resolve().parents[2]
roots=[sdk_root(),sdk_root()/'ucrt64/bin',pathlib.Path('D:/msys64/ucrt64/bin'),pathlib.Path('C:/Windows/System32')]
todo=[roots[0]/'unicore_occt_worker.exe'];seen=set();missing=set()
while todo:
    p=todo.pop()
    if p.name.lower() in seen:continue
    seen.add(p.name.lower())
    s=subprocess.check_output(['D:/msys64/ucrt64/bin/objdump.exe','-p',str(p)],text=True,errors='replace')
    for n in re.findall(r'DLL Name: (.*)',s):
        n=n.strip()
        if n.lower().startswith('api-'):continue
        found=next((r/n for r in roots if (r/n).exists()),None)
        if found and found.parent!=roots[-1]:todo.append(found)
        elif not found:missing.add(n)
print(json.dumps(dict(missing=sorted(missing),modules=sorted(seen)),indent=2))
