"""Validate every native solver against both built library configurations."""
import argparse,json,re,subprocess
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument("--godot",required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
(root/".tools").mkdir(exist_ok=True)
(root/".tools/unicore_native_release.gdextension").write_text((root/"native/unicore_native.gdextension.in").read_text(encoding="utf-8").replace("template_debug","template_release"),encoding="utf-8")
suites=["test_native_metrics_suite.gd","test_native_molecular_suite.gd","test_native_gravity_suite.gd","test_native_quantum_suite.gd","test_native_nuclear_suite.gd","test_native_remaining_fixtures_suite.gd"]
report=[]
for build in ["debug","release"]:
    extension=[] if build=="debug" else ["--extension=res://.tools/unicore_native_release.gdextension"]
    for suite in suites:
        result=subprocess.run([args.godot,"--headless","--path",str(root),"-s","res://tests/"+suite,"--","--require-native",*extension],capture_output=True,timeout=120)
        text=(result.stdout+result.stderr).decode("utf-8",errors="replace")
        (root/".tools"/(build+"-"+suite+".log")).write_text(text,encoding="utf-8")
        match=re.search(r"checks=(\d+) failures=(\d+) native=true",text)
        passed=result.returncode==0 and match is not None and match.group(2)=="0" and "SCRIPT ERROR:" not in text
        entry={"build":build,"suite":suite,"exit_code":result.returncode,"checks":int(match.group(1)) if match else None,"passed":passed}
        report.append(entry)
        print(json.dumps(entry),flush=True)
        if not passed:
            print(text)
            raise SystemExit(1)
(root/"docs/native/solver-validation-results.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
