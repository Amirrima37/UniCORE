"""Print production, configuration, fixtures and current documentation paths."""
from pathlib import Path
import os
ROOT=Path(__file__).resolve().parents[1]
EXCLUDED={'__pycache__','godot-cpp','build','evidence'}
for folder in ['agent','core','modules','ui','shaders','scenes','scripts','native','tests']:
    for base,dirs,files in os.walk(ROOT/folder,followlinks=False):
        dirs[:]=sorted(d for d in dirs if d not in EXCLUDED and not (Path(base)/d).is_junction() and not (Path(base)/d).is_symlink())
        for name in sorted(files):
            p=Path(base)/name
            if p.suffix not in {'.pyc','.o','.obj','.dll','.exe','.log'}:
                print(p.relative_to(ROOT).as_posix())
for p in [ROOT/'project.godot',ROOT/'AGENTS.md',*(ROOT/'docs/architecture').glob('*.md')]:
    if p.is_file():print(p.relative_to(ROOT).as_posix())
