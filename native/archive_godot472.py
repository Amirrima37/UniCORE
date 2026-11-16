"""Archive the compiled profile objects in bounded Windows command batches."""
import os
import shutil
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
target = sys.argv[2]
archive = root / 'bin' / f'libgodot-cpp.windows.{target}.x86_64.a'
temporary = archive.with_suffix('.a.tmp')
staging = root / 'bin' / f'archive-objects-{target}'
staging.mkdir(exist_ok=True)
sources = [root / 'src', root / 'gen' / 'src']
objects = sorted(p for source in sources for p in source.rglob(f'*.windows.{target}.x86_64.o') if p.with_name(p.name.split('.windows.')[0] + '.cpp').exists())
if len(objects) < 25:
    raise SystemExit(f'Incomplete godot-cpp object set: {len(objects)}')
ar = Path('C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-gcc-ar.exe')
if temporary.exists():
    temporary.unlink()
for start in range(0, len(objects), 25):
    chunk = objects[start:start + 25]
    staged = []
    for source in chunk:
        destination = staging / ('_'.join(source.relative_to(root).parts))
        shutil.copy2(source, destination)
        staged.append(destination)
    subprocess.run([str(ar), 'rcs', str(temporary), *(str(p) for p in staged)], check=True)
subprocess.run(['C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-gcc-ranlib.exe', str(temporary)], check=True)
os.replace(temporary, archive)
print(f'Archived {len(objects)} objects: {archive}')
