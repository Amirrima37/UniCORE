import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
"""Record bounded Godot 4.7.2 UniCORE startup and clean shutdown cycles."""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

root = Path(__file__).resolve().parents[1]
exe = Path(r'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe')
parser = argparse.ArgumentParser()
parser.add_argument('--output', default=str(godot_environment_root()/'startup-cycles'))
args = parser.parse_args()
out = root / args.output
if (out / 'results.json').exists():
    raise SystemExit(f'Existing receipt would be overwritten: {out / "results.json"}')
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env['APPDATA'] = str(godot_environment_root()/'roaming')
env['LOCALAPPDATA'] = str(godot_environment_root()/'local')
env['UNICORE_PYTHON'] = sys.executable
rows = []
for number in range(1, 6):
    command = [str(exe), '--headless', '--path', str(root), '--quit-after', '5']
    start = time.monotonic()
    try:
        result = subprocess.run(command, cwd=root, env=env, capture_output=True, timeout=45)
        code = result.returncode
        output = result.stdout + result.stderr
    except subprocess.TimeoutExpired as exc:
        code = None
        output = (exc.stdout or b'') + (exc.stderr or b'')
    (out / f'cycle-{number}.log').write_bytes(output)
    decoded = output.decode('utf-8', errors='replace')
    row = {'cycle': number, 'command': command, 'exit_code': code,
           'seconds': round(time.monotonic() - start, 3),
           'shell_ready': '[UniCORE] Shell ready.' in decoded,
           'script_error': 'SCRIPT ERROR:' in decoded,
           'access_violation': '0xC0000005' in decoded or code in (0xC0000005, 0xC0000005 - 0x100000000),
           'log': f'cycle-{number}.log'}
    rows.append(row)
    (out / 'results.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
    print(json.dumps(row), flush=True)
sys.exit(0 if all(r['exit_code'] == 0 and r['shell_ready'] and
                  not r['script_error'] and not r['access_violation'] for r in rows) else 1)
