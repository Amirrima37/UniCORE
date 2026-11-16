import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[2]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
import json,hashlib,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];SDK=sdk_root();OUT=output_dir('CAD/cad24-completion')
records=json.loads((OUT/'runtime-packages.json').read_text())
core={'opencascade-7.8.1-2.pkg.tar.zst':'mingw-w64-ucrt-x86_64-opencascade-7.8.1-2-any.pkg.tar.zst','json.pkg.tar.zst':'mingw-w64-ucrt-x86_64-nlohmann-json-3.12.0-1-any.pkg.tar.zst','tbb.pkg.tar.zst':'mingw-w64-ucrt-x86_64-tbb-2022.1.0-2-any.pkg.tar.zst','gcc.pkg.tar.zst':'mingw-w64-ucrt-x86_64-gcc-15.1.0-1-any.pkg.tar.zst','gcc-libs.pkg.tar.zst':'mingw-w64-ucrt-x86_64-gcc-libs-15.1.0-1-any.pkg.tar.zst'}
for archive,name in core.items():records.append(dict(filename=name,local_archive=archive,url='https://repo.msys2.org/mingw/ucrt64/'+name,sha256=hashlib.sha256((SDK/archive).read_bytes()).hexdigest()))
lock=dict(schema=1,source='Official MSYS2 HTTPS repository',occt='7.8.1-2',compiler='MSYS2 UCRT GCC 15.1.0-1',license='LGPL-2.1-or-later WITH OCCT-exception-1.0',packages=records,prerequisites='Existing MSYS2 UCRT binutils, C runtime import libraries and C headers; D:/msys64/usr/bin/tar.exe with zstd. Exact package inventory in evidence.',signature_verification='HTTPS origin and locked SHA-256; package PGP signatures were not verified')
(ROOT/'native/occt/sdk-lock.json').write_text(json.dumps(lock,indent=2));(OUT/'sdk-provenance.json').write_text(json.dumps(lock,indent=2))
used=[SDK/'unicore_occt_worker.exe',*list((SDK/'ucrt64/bin').glob('libTK*.dll')),SDK/'ucrt64/bin/libtbb12.dll',SDK/'ucrt64/bin/libstdc++-6.dll',SDK/'ucrt64/bin/libgcc_s_seh-1.dll',Path('D:/msys64/ucrt64/bin/libwinpthread-1.dll')]
(OUT/'native-binary-hashes.json').write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in used},indent=2))
p=subprocess.run(['D:/msys64/usr/bin/pacman.exe','-Q'],capture_output=True);(OUT/'msys2-installed-packages.txt').write_bytes(p.stdout+p.stderr)
print('Locked',len(records),'SDK packages')
