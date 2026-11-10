"""Import fresh staged project archives and verify native/fallback physics paths."""
import argparse,json,re,subprocess,tempfile,time,zipfile
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument("--godot",required=True,help="Use the engine executable, not its console launcher")
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
artifacts=root/".tools"
report={}
for variant in ["script","native"]:
    stage=Path(tempfile.mkdtemp(prefix="molecular-"+variant+"-",dir=artifacts))
    with zipfile.ZipFile(artifacts/"packages"/("unicore-"+variant+".zip")) as archive:
        for item in archive.infolist():
            if not (stage/item.filename).resolve().is_relative_to(stage.resolve()):
                raise SystemExit("Unsafe archive path")
        archive.extractall(stage)
    log_path=artifacts/("molecular-import-"+variant+".log")
    with log_path.open("wb") as output:
        process=subprocess.Popen([args.godot,"--headless","--editor","--path",str(stage)],stdout=output,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        deadline=time.monotonic()+40
        imported=False
        try:
            while time.monotonic()<deadline:
                cache=stage/".godot/global_script_class_cache.cfg"
                extension=stage/".godot/extension_list.cfg"
                if cache.exists() and "MolecularDynamicsModule" in cache.read_text(encoding="utf-8",errors="replace") and (variant=="script" or extension.exists()):
                    imported=True
                    time.sleep(0.5)
                    break
                if process.poll() is not None:
                    break
                time.sleep(0.2)
        finally:
            if process.poll() is None:
                process.terminate()
            process.wait(timeout=10)
    if not imported:
        raise SystemExit("Fresh "+variant+" import did not finish; inspect "+str(log_path))
    entries=[]
    for script,summary in [("test_native_metrics_suite.gd","METRICS"),("test_native_molecular_suite.gd","MOLECULAR"),("test_native_gravity_suite.gd","GRAVITY"),("test_native_quantum_suite.gd","QUANTUM"),("test_native_nuclear_suite.gd","NUCLEAR"),("test_native_remaining_fixtures_suite.gd","REMAINING_FIXTURES"),("test_physics_features_suite.gd","Physics Features Audit")]:
        command=[args.godot,"--headless","--path",str(stage),"-s","res://tests/"+script]
        if variant=="native" and script.startswith("test_native_"):
            command += ["--","--require-native"]
        result=subprocess.run(command,capture_output=True,timeout=90,creationflags=subprocess.CREATE_NO_WINDOW)
        text=(result.stdout+result.stderr).decode("utf-8",errors="replace")
        (artifacts/("molecular-package-"+variant+"-"+script+".log")).write_text(text,encoding="utf-8")
        if script.startswith("test_native_"):
            match=re.search(r"checks=(\d+) failures=0 native=(true|false)",text)
            valid=match is not None and match.group(2)==("true" if variant=="native" else "false")
        else:
            valid="passed=14, failed=0" in text
        passed=result.returncode==0 and valid and "SCRIPT ERROR:" not in text
        entries.append({"script":script,"passed":passed,"exit_code":result.returncode,"summary":[line for line in text.splitlines() if summary in line]})
        print(variant,json.dumps(entries[-1]),flush=True)
        if not passed:
            raise SystemExit(text)
    report[variant]={"project_root":str(stage),"checks":entries}
    (artifacts/"molecular-package-checks.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
