from pathlib import Path
import re,json,ast
ROOT=Path(__file__).resolve().parents[1]
for p in (ROOT/'tests').glob('*.py'):
 text=p.read_text(encoding='utf-8');old=text
 text=re.sub(r"\((?:ROOT|root)/'docs/architecture/evidence/([^']+)/([^'/]+)'\)\.write_text",lambda m:"(output_dir("+repr('CAD/'+m[1])+")/"+repr(m[2])+").write_text",text)
 if text!=old:
  if 'from development_paths import' not in text:
   text="import sys\nsys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))\nfrom development_paths import output_dir\n"+text
  p.write_text(text,encoding='utf-8')
p=ROOT/'native/build_godot472.ps1';text=p.read_text(encoding='utf-8')
text=text.replace('$objectDir=Join-Path $root ".tools/cae-godot472-$Target"',"$taskCacheRoot=$env:UNICORE_BUILD_CACHE_ROOT\nif([string]::IsNullOrEmpty($taskCacheRoot)){$taskCacheRoot='D:/PROJECT/CACHE/BUILD'}\n$objectDir=Join-Path $taskCacheRoot \"cae-godot472-$Target\"")
p.write_text(text,encoding='utf-8')
# Update old launcher --output defaults that otherwise recreate the old tree.
for p in (ROOT/'tests').glob('*.py'):
 text=p.read_text(encoding='utf-8');old=text
 text=re.sub(r"default='\.tools/godot472-migration/([^']+)'",lambda m:"default=str(godot_environment_root()/"+repr(m[1])+")",text)
 if text!=old:
  if 'from development_paths import' not in text:text="import sys\nsys.path.insert(0,str(__import__('pathlib').Path(__file__).resolve().parents[1]/'scripts/engines'))\nfrom development_paths import godot_environment_root\n"+text
  p.write_text(text,encoding='utf-8')
changed=[]
for folder in ['tests','native/occt','scripts/engines']:
 for p in (ROOT/folder).glob('*.py'):
  text=p.read_text(encoding='utf-8');ast.parse(text)
  if 'development_paths import' in text:changed.append(p.relative_to(ROOT).as_posix())
for p in (ROOT/'tests').glob('*.gd'):
 if 'res://tests/development_paths.gd' in p.read_text(encoding='utf-8'):changed.append(p.relative_to(ROOT).as_posix())
changed+=['native/build_occt.ps1','native/build_godot472.ps1','native/run_regressions.py']
(ROOT/'docs/maintenance/evidence/external-migration/updated-paths.json').write_text(json.dumps(changed,indent=2))
print('Configured',len(changed),'files; Python syntax checked')
