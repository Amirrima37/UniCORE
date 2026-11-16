import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Run existing engineering acceptance logic under Godot 4.7.2 with new receipts."""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', default=str(godot_environment_root()/'engineering'))
args = parser.parse_args()
out = root / args.output
if (out / 'results.json').exists():
    raise SystemExit(f'Existing receipt would be overwritten: {out / "results.json"}')
out.mkdir(parents=True, exist_ok=True)
exe = Path(r'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe')
env = os.environ.copy()
env['APPDATA'] = str(godot_environment_root()/'roaming')
env['LOCALAPPDATA'] = str(godot_environment_root()/'local')
env['UNICORE_PYTHON'] = sys.executable
steps = [
    ('calculix-adapter', [str(exe), '--headless', '--path', str(root), '-s', 'res://tests/test_calculix_adapter.gd']),
    ('calculix-patch', [str(exe), '--headless', '--path', str(root), '-s', 'res://tests/test_godot472_calculix_numerical.gd']),
    ('calculix-process', [sys.executable, 'tests/test_godot472_calculix_process.py']),
    ('gmsh-repeatability', [sys.executable, 'tests/test_godot472_gmsh_repeatability.py']),
    ('extreme-comparison', [sys.executable, 'tests/compare_godot472_calculix_extreme.py']),
    ('bar-cantilever', [str(exe), '--headless', '--path', str(root), '-s', 'res://tests/benchmark_godot472_calculix_gmsh.gd']),
    ('step-occ', [sys.executable, 'tests/test_step_gmsh_real.py']),
]
rows = []
for name, command in steps:
    started = time.monotonic()
    try:
        result = subprocess.run(command, cwd=root, env=env, capture_output=True, timeout=180)
        stdout, stderr = result.stdout, result.stderr
        code = result.returncode
        state = 'completed'
    except subprocess.TimeoutExpired as exc:
        stdout, stderr = exc.stdout or b'', exc.stderr or b''
        code = None
        state = 'timeout'
    (out / f'{name}.stdout.txt').write_bytes(stdout)
    (out / f'{name}.stderr.txt').write_bytes(stderr)
    text = (stdout + stderr).decode('utf-8', errors='replace')
    row = dict(name=name, command=command, exit_code=code, state=state,
               passed=code == 0 and 'SCRIPT ERROR:' not in text,
               seconds=round(time.monotonic() - started, 3))
    rows.append(row)
    (out / 'results.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
    print(json.dumps(row), flush=True)
sys.exit(0 if all(row['passed'] for row in rows) else 1)
