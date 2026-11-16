"""Run explicit physics scripts, preserving logs, timeouts and actual exit codes."""
import argparse, json, subprocess, time, re, os, tempfile
from datetime import datetime, timezone
from pathlib import Path
import sys
sys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))
from development_paths import sdk_root, godot_environment_root, test_output_root, output_dir
parser = argparse.ArgumentParser()
parser.add_argument("--godot", required=True)
parser.add_argument("--output", help="Explicit output directory; defaults to UNICORE_TEST_OUTPUT_ROOT or a unique temporary workspace")
parser.add_argument("--all-suites", action="store_true")
parser.add_argument("--project-root", help="Optional staged Godot project to validate")
args = parser.parse_args()
root = Path(args.project_root).resolve() if args.project_root else Path(__file__).resolve().parent.parent
out = root/args.output if args.output else Path(tempfile.mkdtemp(prefix="unicore-regressions-", dir=output_dir("NATIVE")))
out.mkdir(parents=True, exist_ok=True)
env=os.environ.copy()
env.update(APPDATA=str(out/"profile/roaming"),LOCALAPPDATA=str(out/"profile/local"))
print(json.dumps({"output_root":str(out.resolve())}),flush=True)
manifest = json.loads((root/"tests/native_regression_manifest.json").read_text())
scripts = manifest["scripts"]
if args.all_suites:
    scripts = sorted(set(scripts) | {str(p.relative_to(root)).replace(chr(92), "/") for p in (root/"tests").glob("*_suite.gd")})
results = []
for script in scripts:
    start = time.perf_counter()
    started = datetime.now(timezone.utc).isoformat()
    stdout = stderr = b""
    try:
        result = subprocess.run([args.godot,"--headless","--path",str(root),"-s","res://"+script], capture_output=True, timeout=manifest["timeout_seconds"],env=env)
        text = (result.stdout+result.stderr).decode("utf-8",errors="replace")
        stdout, stderr = result.stdout, result.stderr
        # Record script diagnostics separately: negative validation tests can emit them intentionally.
        # Negative syntax-validation suites intentionally compile anonymous invalid scripts.
        expected = manifest.get("expected_anonymous_parse_errors", {}).get(script, 0)
        pattern = r"SCRIPT ERROR: Parse Error:[^\n]*\n\s*at: GDScript::reload \(gdscript://[^\n]*\)"
        anonymous = re.findall(pattern,text)
        diagnostics = text
        if expected and len(anonymous)==expected and re.search(r"Test Results: \d+ Passed, 0 Failed",text):
            diagnostics=re.sub(pattern,"",text)
        passed = result.returncode == 0 and "SCRIPT ERROR:" not in diagnostics
        explicit_failure = bool(re.search(r"(?:failures\s*[=:]\s*[1-9]\d*|[1-9]\d*\s+Failed\b|\bFailed\s*:\s*[1-9]\d*|^\s*FAIL\s*[:!])", diagnostics, re.I | re.M))
        passed = passed and not explicit_failure
        if Path(script).name.startswith("test_native_"):
            passed = passed and (re.search(r"checks=\d+ failures=0 native=", text) is not None or re.search(r": 0 failures", text) is not None or "Background solve, result overlay/probes and stale-result checks passed" in text)
        entry = {"script":script,"exit_code":result.returncode,"passed":passed,"script_error":"SCRIPT ERROR:" in diagnostics,"expected_script_errors":len(anonymous) if diagnostics != text else 0,"raw_script_error":"SCRIPT ERROR:" in text}
        entry.update(state="completed", explicit_failure=explicit_failure)
    except subprocess.TimeoutExpired as error:
        text = ((error.stdout or b"")+(error.stderr or b"")).decode("utf-8",errors="replace")
        entry = {"script":script,"passed":False,"timeout":True}
        stdout, stderr = error.stdout or b"", error.stderr or b""
        entry.update(state="timeout", exit_code=None)
    except OSError as error:
        text = str(error)
        entry = {"script":script,"passed":False,"state":"launch_failed","exit_code":None,"error":str(error)}
    except KeyboardInterrupt:
        text = "Regression collection interrupted"
        entry = {"script":script,"passed":False,"state":"interrupted","exit_code":None}
    entry.update(started_utc=started, ended_utc=datetime.now(timezone.utc).isoformat())
    (out/(Path(script).stem+".stdout.txt")).write_bytes(stdout)
    (out/(Path(script).stem+".stderr.txt")).write_bytes(stderr)
    entry["warning_count"] = text.count("WARNING:")
    entry["engine_error_count"] = text.count("ERROR:")
    entry["seconds"] = round(time.perf_counter()-start,3)
    (out/(Path(script).stem+".log")).write_text(text,encoding="utf-8")
    results.append(entry)
    print(json.dumps(entry),flush=True)
    (out/"results.json").write_text(json.dumps(results,indent=2)+"\n")
    if entry["state"] == "interrupted": break
missing = [script for script in scripts if script not in {item["script"] for item in results}]
passed = not missing and len(results)==len(scripts) and all(item["passed"] for item in results)
(out/"receipt.json").write_text(json.dumps({"passed":passed,"expected":len(scripts),"recorded":len(results),"missing":missing,"results_file":"results.json"},indent=2)+"\n")
raise SystemExit(0 if passed else 1)
