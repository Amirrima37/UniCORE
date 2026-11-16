import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Bounded Godot 4.7 editor import and parser scan; preserves raw diagnostics."""
import os
import subprocess
import sys
import time
from pathlib import Path

root = Path(__file__).resolve().parents[1]
exe = Path(r'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe')
out = godot_environment_root()
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
for key, suffix in (('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local')):
    dest = out / suffix
    dest.mkdir(exist_ok=True)
    env[key] = str(dest)
command = [str(exe), '--headless', '--editor', '--path', str(root), '--quit']
started = time.monotonic()
with (out / 'editor-scan.log').open('wb') as log:
    try:
        result = subprocess.run(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
        code = result.returncode
    except subprocess.TimeoutExpired:
        code = 'TIMEOUT'
print(f'exit={code} elapsed={time.monotonic()-started:.3f}s log={out / "editor-scan.log"}')
sys.exit(code if isinstance(code, int) else 124)
