"""Create a Godot project archive with either the script or native backend available."""
import argparse, json, zipfile
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument("--variant", choices=["script", "native"], required=True)
parser.add_argument("--output", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
output = Path(args.output).resolve()
required = ["bin/unicore_native.gdextension", "bin/windows/x86_64/unicore_native.windows.template_debug.x86_64.dll", "bin/windows/x86_64/unicore_native.windows.template_release.x86_64.dll"]
if args.variant == "native":
    for item in required:
        if not (root/item).is_file():
            raise SystemExit("Missing native build artifact: " + item)
output.parent.mkdir(parents=True, exist_ok=True)
excluded = {".git", ".godot", ".tools", ".agents", ".github", "native"}
with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        if not path.is_file() or path.resolve() == output or any(part in excluded for part in relative.parts):
            continue
        if args.variant == "script" and (relative.parts[0] == "bin" or path.suffix == ".gdextension"):
            continue
        if relative.parts[0] == "bin" and relative.as_posix() not in required:
            continue
        archive.write(path, relative.as_posix())
    if args.variant == "native":
        archive.write(root/"native/godot-cpp/LICENSE.md", "licenses/godot-cpp-LICENSE.md")
    archive.writestr("native-package.json", json.dumps({"variant":args.variant,"godot":"4.0.stable.official.92bee43ad","api_version":1}))
print(output)
