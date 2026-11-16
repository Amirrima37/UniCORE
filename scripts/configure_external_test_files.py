"""Move direct CAD GUI/failure output literals while retaining historical inputs."""
from pathlib import Path
import re,json
ROOT=Path(__file__).resolve().parents[1];updated=[]
for p in (ROOT/'tests').glob('*cad*.gd'):
 text=p.read_text(encoding='utf-8');old=text;selected=set()
 for line in text.splitlines():
  if any(token in line for token in ['FileAccess.WRITE','save_project(', 'save_png(', 'var path=', 'var saved=', 'var invalid_path=']):
   selected.update(re.findall(r'"res://docs/architecture/evidence/([^"\n]+)"',line))
 for rel in selected:
  text=text.replace('"res://docs/architecture/evidence/'+rel+'"','preload("res://tests/development_paths.gd").output_file('+json.dumps('CAD/'+rel)+')')
 if text!=old:p.write_text(text,encoding='utf-8');updated.append(p.relative_to(ROOT).as_posix())
record=ROOT/'docs/maintenance/evidence/external-migration/updated-paths.json'
paths=json.loads(record.read_text());record.write_text(json.dumps(sorted(set(paths+updated+['tests/development_paths.gd'])),indent=2))
print(updated)
