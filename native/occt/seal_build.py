import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[2]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];SDK=sdk_root()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=dict(schema=1,worker_sha256=sha(SDK/'unicore_occt_worker.exe'),source_sha256=sha(ROOT/'native/occt/worker.cpp'),dlls={p.name:sha(p) for p in (SDK/'ucrt64/bin').glob('*.dll')},external_winpthread_sha256=sha(Path('D:/msys64/ucrt64/bin/libwinpthread-1.dll')))
(SDK/'build-manifest.json').write_text(json.dumps(manifest,indent=2))
print('Sealed native worker and',len(manifest['dlls']),'SDK DLLs')
