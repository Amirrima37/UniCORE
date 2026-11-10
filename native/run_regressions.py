"""Run explicit physics scripts, preserving logs, timeouts and actual exit codes."""
import argparse, json, subprocess, time, re
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument("--godot", required=True)
parser.add_argument("--output", default=".tools/regression")
parser.add_argument("--all-suites", action="store_true")
parser.add_argument("--project-root", help="Optional staged Godot project to validate")
args = parser.parse_args()
root = Path(args.project_root).resolve() if args.project_root else Path(__file__).resolve().parent.parent
out = root/args.output
out.mkdir(parents=True, exist_ok=True)
manifest = json.loads((root/"tests/native_regression_manifest.json").read_text())
scripts = manifest["scripts"]
if args.all_suites:
    scripts = sorted(set(scripts) | {str(p.relative_to(root)).replace(chr(92), "/") for p in (root/"tests").glob("*_suite.gd")})
results = []
for script in scripts:
    start = time.perf_counter()
    try:
        result = subprocess.run([args.godot,"--headless","--path",str(root),"-s","res://"+script], capture_output=True, timeout=manifest["timeout_seconds"])
        text = (result.stdout+result.stderr).decode("utf-8",errors="replace")
        # Record script diagnostics separately: negative validation tests can emit them intentionally.
        passed = result.returncode == 0 and "SCRIPT ERROR:" not in text
        if Path(script).name.startswith("test_native_"):
            passed = passed and (re.search(r"checks=\d+ failures=0 native=", text) is not None or re.search(r": 0 failures", text) is not None or "Background solve, result overlay/probes and stale-result checks passed" in text)
        entry = {"script":script,"exit_code":result.returncode,"passed":passed,"script_error":"SCRIPT ERROR:" in text}
    except subprocess.TimeoutExpired as error:
        text = ((error.stdout or b"")+(error.stderr or b"")).decode("utf-8",errors="replace")
        entry = {"script":script,"passed":False,"timeout":True}
    entry["seconds"] = round(time.perf_counter()-start,3)
    (out/(Path(script).stem+".log")).write_text(text,encoding="utf-8")
    results.append(entry)
    print(json.dumps(entry),flush=True)
    (out/"results.json").write_text(json.dumps(results,indent=2)+"\n")
raise SystemExit(0 if all(item["passed"] for item in results) else 1)
