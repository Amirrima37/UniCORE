import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[2]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Resolve official dated MSYS2 packages into an isolated project-local prefix."""
import re,datetime,subprocess,os,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];SDK=sdk_root()
index=(SDK/'index.html').read_text();packages={}
for line in index.splitlines():
    m=re.search(r'href="([^"]+\.pkg.tar.zst)".*?</a>\s+(\d\d-\w+-\d{4})',line)
    if not m:continue
    file,date=m.groups();date=datetime.datetime.strptime(date,'%d-%b-%Y')
    if date>datetime.datetime(2025,5,26):continue
    name=file.removesuffix('-any.pkg.tar.zst').rsplit('-',2)[0]
    if name not in packages or date>packages[name][0]:packages[name]=(date,file)
env=os.environ.copy();env['PATH']='D:/msys64/usr/bin;'+env.get('PATH','')
pending=['mingw-w64-ucrt-x86_64-'+n for n in ['ffmpeg4.4','freeimage','freetype','openvr']]
seen={'mingw-w64-ucrt-x86_64-gcc-libs','mingw-w64-ucrt-x86_64-tbb','mingw-w64-ucrt-x86_64-libwinpthread','mingw-w64-ucrt-x86_64-winpthreads'};records=[]
while pending:
    name=pending.pop()
    if name=='mingw-w64-ucrt-x86_64-omp':name='mingw-w64-ucrt-x86_64-llvm-openmp'
    if name=='mingw-w64-ucrt-x86_64-libjpeg':name='mingw-w64-ucrt-x86_64-libjpeg-turbo'
    if name=='mingw-w64-ucrt-x86_64-vulkan':name='mingw-w64-ucrt-x86_64-vulkan-loader'
    if name in seen:continue
    seen.add(name)
    if name not in packages:raise RuntimeError('No dated official package for '+name)
    file=packages[name][1];archive=SDK/file;url='https://repo.msys2.org/mingw/ucrt64/'+file
    if not archive.exists():subprocess.run(['curl.exe','-L','--fail','--max-time','180',url,'-o',str(archive)],check=True)
    info=subprocess.check_output(['D:/msys64/usr/bin/tar.exe','--force-local','-xOf',str(archive),'.PKGINFO'],env=env,text=True)
    subprocess.run(['D:/msys64/usr/bin/tar.exe','--force-local','-xf',str(archive),'-C',str(SDK)],env=env,check=True)
    (SDK/(name+'.PKGINFO')).write_text(info)
    pending.extend(re.sub(r'[<>=].*','',x) for x in re.findall(r'^depend = (.+)$',info,re.M))
    records.append(dict(package=name,filename=file,url=url,sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),pkginfo=info))
    (ROOT/'docs/architecture/evidence/cad24-completion/runtime-packages.json').write_text(json.dumps(records,indent=2))
    print(name,flush=True)
