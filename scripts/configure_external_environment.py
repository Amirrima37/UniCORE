"""Apply scoped path substitutions; historical reports and receipts stay unchanged."""
import re,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];changed=[]
bootstrap="import sys\nsys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[DEPTH]/'scripts/engines'))\nfrom development_paths import sdk_root, godot_environment_root, test_output_root, output_dir\n"
for folder in ['native/occt','tests']:
 for p in (ROOT/folder).glob('*.py'):
  text=p.read_text(encoding='utf-8');old=text
  # Preserve historic summarizer text; change executable path expressions only.
  text=re.sub(r"\b(?:ROOT|root)\s*/\s*['\"]\.tools/occt-sdk(?:/([^'\"]*))?['\"]",lambda m:"sdk_root()"+("/"+repr(m[1]) if m[1] else ''),text)
  text=re.sub(r"\b(?:ROOT|root)\s*/\s*['\"]\.tools/godot472-migration(?:/([^'\"]*))?['\"]",lambda m:"godot_environment_root()"+("/"+repr(m[1]) if m[1] else ''),text)
  text=re.sub(r"(?P<prefix>\bOUT\s*=\s*)(?:ROOT|root)\s*/\s*['\"]docs/architecture/evidence/([^'\"]+)['\"]",lambda m:m['prefix']+'output_dir('+repr('CAD/'+m[2])+')',text)
  if text!=old:
   text=bootstrap.replace('DEPTH','2' if folder=='native/occt' else '1')+text
   p.write_text(text,encoding='utf-8');changed.append(str(p.relative_to(ROOT)))
p=ROOT/'scripts/engines/native_occt.py';text=p.read_text(encoding='utf-8');text=text.replace("SDK=ROOT/'.tools/occt-sdk'","from development_paths import sdk_root\nSDK=sdk_root()")
p.write_text(text,encoding='utf-8');changed.append(str(p.relative_to(ROOT)))
for p in (ROOT/'tests').glob('*.gd'):
 text=p.read_text(encoding='utf-8');old=text
 text=re.sub(r'"res://\.tools/godot472-migration/([^"\n]*)"',lambda m:'preload("res://tests/development_paths.gd").godot_environment('+json.dumps(m[1])+')',text)
 text=re.sub(r'const OUT\s*=\s*"res://docs/architecture/evidence/([^"\n]+)"',lambda m:'var OUT=preload("res://tests/development_paths.gd").output('+json.dumps('CAD/'+m[1])+')',text)
 if text!=old:p.write_text(text,encoding='utf-8');changed.append(str(p.relative_to(ROOT)))
p=ROOT/'native/build_occt.ps1';text=p.read_text(encoding='utf-8');text=text.replace("$taskSdk=Join-Path $taskRoot '.tools/occt-sdk/ucrt64'","$taskSdkRoot=& $taskPython $taskRoot/scripts/engines/development_paths.py sdk\n$taskSdk=Join-Path $taskSdkRoot 'ucrt64'")
text=text.replace('$taskSdkRoot=& $taskPython',"$taskPython=$env:UNICORE_PYTHON\nif([string]::IsNullOrEmpty($taskPython)){$taskPython='C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe'}\n$taskSdkRoot=& $taskPython")
text=text.replace('-o .tools/occt-sdk/unicore_occt_worker.exe','-o "$taskSdkRoot/unicore_occt_worker.exe"').replace('-o .tools/occt-sdk/make_occt_fixtures.exe','-o "$taskSdkRoot/make_occt_fixtures.exe"')
p.write_text(text,encoding='utf-8');changed.append(str(p.relative_to(ROOT)))
p=ROOT/'native/run_regressions.py';text=p.read_text(encoding='utf-8');text=text.replace('parser = argparse.ArgumentParser()',bootstrap.replace('DEPTH','1')+'parser = argparse.ArgumentParser()').replace('dir=os.environ.get("UNICORE_TEST_OUTPUT_ROOT")','dir=output_dir("NATIVE")')
p.write_text(text,encoding='utf-8');changed.append(str(p.relative_to(ROOT)))
(ROOT/'docs/maintenance/evidence/external-migration').mkdir(parents=True,exist_ok=True)
(ROOT/'docs/maintenance/evidence/external-migration/updated-paths.json').write_text(json.dumps(changed,indent=2))
print(json.dumps(changed))

