# Godot 4.7.2 migration launch (2026-11-13)

Use the verified Windows x86-64 runtime at `D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` (SHA-256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`). Set `UNICORE_PYTHON` to a Python installation with the pinned Gmsh bridge dependencies before meshing. Launch from the repository root with `powershell -ExecutionPolicy Bypass -File scripts/run_godot472.ps1 -PythonExe <python.exe>`; the selector checks the runtime hash before running the existing project. The historical Godot 4.0 binary remains available; its instructions below are historical and it reproduces the documented minimal-project access violation on this machine.

The 4.7 GDExtension is selected by `bin/unicore_native.gdextension`. The debug and release DLLs were rebuilt using official godot-cpp commit `2a4c066e1e8c121046e9d35fe91cc8e726861c48`, API 4.7, Qt MinGW 13.1 x86-64, and `native/godot472_profile.json`. With the profiled godot-cpp archives available, run:

```powershell
powershell -ExecutionPolicy Bypass -File native/build_godot472.ps1 -Target template_debug
powershell -ExecutionPolicy Bypass -File native/build_godot472.ps1 -Target template_release
C:/Users/Victus/AppData/Local/Python/bin/python.exe tests/run_godot472_scan.py
```

On this Windows toolchain SCons compiled the godot-cpp objects but its archive command exceeded the command-line limit. `native/archive_godot472.py <godot-cpp-checkout> template_debug` (and `template_release`) archives those already compiled objects in bounded batches. The ignored `.tools/godot-cpp-4.7` checkout and SCons installation are local prerequisites; automated clean-machine acquisition remains unfinished. Full evidence and limits: [GODOT_4_7_2_MIGRATION.md](GODOT_4_7_2_MIGRATION.md).

# Optional engine pack checkpoint

## Current Workbench pack (native Windows)

Acquire both packs with the existing `acquire-gmsh.ps1` and
`acquire-calculix.ps1`; no solver compilation is required. Python is now a
runtime dependency for this optional pack. The detected installation is
`%LOCALAPPDATA%/Python/pythoncore-3.14-64/python.exe`; set `UNICORE_PYTHON` before
launching Godot if your interpreter differs. Normal native solvers do not use it.

In the existing Workbench: create one Box or Cylinder; open Analysis settings,
choose Static Structural / TET4 / CalculiX 2.23; apply fixed support and total
face force through existing region controls; save settings; generate mesh;
Solve. Cancel targets only that job. Results offer displacement/stress fields,
deformation, original overlay and probes. Save/Open retains study/results and
backend. Editing invalidates results. Rotated/scaled/multi-solid models, pressure,
gravity, prescribed motion and other analyses reject for this pack.

```powershell
python native/run_regressions.py --godot .tools/godot/Godot_v4.0-stable_win64_console.exe --output docs/architecture/evidence/calculix/regressions-final
& .tools/godot/Godot_v4.0-stable_win64_console.exe --path . --script tests/test_calculix_workbench.gd
& .tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . --script tests/benchmark_calculix_gmsh.gd
python tests/test_calculix_process.py
python tests/test_gmsh_repeatability.py
python tests/compare_calculix_extreme.py
python tests/run_calculix_acceptance.py
python tests/archive_calculix_evidence.py
```

The graphical test runs actual block/cylinder studies and captures screenshots.
Solver-owned job logs stay under Godot's `user://calculix_jobs`; exported study
fixtures and benchmark/regression receipts are in `docs/architecture/evidence`.
Meshing is currently synchronous. The full acceptance verdict remains PARTIAL;
see CALCULIX_CHECKPOINT2.md. Earlier CLI-only status paragraphs are historical.

CalculiX checkpoint 2 reproduction (native Windows, no WSL):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/engines/acquire-calculix.ps1
& .tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . --script tests/test_calculix_adapter.gd
& .tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . --script tests/test_calculix_numerical.gd
```

These run actual exported cases; they are not a production GUI workflow.
See CALCULIX_CHECKPOINT2.md for hashes, evidence and limitations. The older
statement below that no structural pack is installed is superseded here.

All downloaded files stay under excluded `.tools/engines`. Startup never builds
dependencies. Run from this repository in PowerShell:

```powershell
./scripts/engines/acquire-gmsh.ps1
./scripts/engines/test-gmsh.ps1
& .tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . --script tests/test_backend_registry.gd
```

On hosts where script execution is disabled, use a process-scoped invocation:
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/engines/test-gmsh.ps1`.
This invocation was used successfully without changing persistent system policy.

The native test uses the repository's existing Qt MinGW compiler and Windows
LoadLibrary with the official C ABI, avoiding a C++ ABI assumption. Build failures
stop the script. It is a smoke test, not the full CAD/mesh acceptance suite.
No external structural or CFD pack has been installed. WSL execution and path
translation remain unimplemented; WSL discovery was denied in this environment.

CAD expansion: PARTIAL infrastructure only; see docs/architecture/CAD_MESHING_CHECKPOINT.md. No new native or GUI acceptance claimed.
