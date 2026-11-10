# Native migration

The CAE workspace now also exposes `UniCoreStructuralSolver`: a box volume
mesher and initial static linear elastic TET4 solver, with worker cancellation,
displacements, element fields and reactions. Its scope and measured bending
accuracy limits are documented in [Engineering tools](../cae-workspace.md).
It is separate from the existing particle/time-dependent numerical cores.

If the local SCons package cannot be read, `native/build_direct.ps1` rebuilds
the bindings against the existing pinned Godot C++ archives. Both debug and
release archives must already exist; this fallback does not build Godot C++.

## Status

Conservation reductions and all four built-in numerical cores now have native
implementations: molecular dynamics, gravity, quantum waves and nuclear dynamics.
The GDScript modules retain scene lifecycle, tools, rendering and telemetry.
The project selects auto, with script fallback for missing capabilities, custom
subclasses/callbacks and workloads below the measured selection gates.

Gravity and quantum support deterministic native checkpoints. Nuclear retains the
existing engine-global RNG; its snapshots explicitly mark RNG as non-restorable.
Any connected nuclear decay/fission listener retains the scripted stepping path
in every mode, preserving mid-event callbacks and their RNG effects.

The broader plan remains open for profiled initialization/generation work, probe
batching, optional workers, complete module/RNG checkpoints, sanitizers, graphical
exports and API freeze. Numerical reference code has not been deleted. See
SOLVERS.md, MOLECULAR.md and VALIDATION.md. API version 1 is provisional.

## Toolchain

The source tree is an archive without a root .git directory, so its originating
revision cannot be established. The installed portable engine reports
`4.0.stable.official.92bee43ad`; single precision is required by the native build.
The initial target is Windows x86_64; other shipping targets remain unspecified.

This workstation has Python 3.14.7 at
`C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe` and Qt MinGW
13.1.0 at `C:/Qt/Tools/mingw1310_64/bin`. Its `g++.exe` is zero bytes; use
`x86_64-w64-mingw32-g++.exe`. No Qt installation files were changed.
SCons 4.10.1 was installed locally under `.tools/python-packages`.

The Godot 4.0 C++ API predates the modern GDExtension entry-point signature.
Use the pinned binding revision, not a current branch. See the official
[Godot 4.0 C++ example](https://docs.godotengine.org/en/4.0/tutorials/scripting/gdextension/gdextension_cpp_example.html).
The build fails on a different binding commit, platform, architecture or precision.
Do not assume compatibility with newer Godot versions; they have not been tested.

## Reproduce

From the project root, fetch the pinned dependency in an ordinary source checkout:

```powershell
git clone https://github.com/godotengine/godot-cpp.git native/godot-cpp
git -C native/godot-cpp checkout 9d1c396c54fc3bdfcc7da4f3abcb52b14f6cce8f
python -m pip install --target .tools/python-packages scons==4.10.1
```

This archive cannot record a Git submodule. `native/dependencies.json` records the
pin and SConstruct verifies it. A future Git repository can replace the local
checkout with a submodule at that exact revision.

```powershell
$taskPython = 'C:/Users/Victus/AppData/Local/Python/pythoncore-3.14-64/python.exe'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File native/build.ps1 -Python $taskPython -CompilerBin C:/Qt/Tools/mingw1310_64/bin -Cxx C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe -Target template_debug
powershell.exe -NoProfile -ExecutionPolicy Bypass -File native/build.ps1 -Python $taskPython -CompilerBin C:/Qt/Tools/mingw1310_64/bin -Cxx C:/Qt/Tools/mingw1310_64/bin/x86_64-w64-mingw32-g++.exe -Target template_release
```

The process-only execution-policy option permits this local script without changing Windows policy. Both libraries must exist before build.ps1 activates the descriptor. The committed
`.gdextension.in` template targets Godot 4.0 and omits newer descriptor fields.
The normal Godot editor imports the activated descriptor. The dedicated test and
benchmark scripts also load it explicitly for fresh headless runs.
Compiler runtimes are statically linked. Inspect `objdump -p` DLL dependencies
before distributing binaries. No fast-math or floating point contraction is enabled.

```powershell
& ./.tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . -s res://tests/test_native_metrics_suite.gd -- --require-native
& $taskPython native/run_regressions.py --godot "$pwd/.tools/godot/Godot_v4.0-stable_win64_console.exe" --all-suites
& ./.tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . -s res://tests/benchmark_particle_metrics.gd
```

`run_regressions.py` includes explicit empirical scripts and records per-script
exit codes, timeouts and script diagnostics. A zero exit plus diagnostics requires
review: validation suites intentionally provoke some errors, while other suites
can return zero after a runtime exception. Raw logs live under `.tools/regression`.
The benchmark reports whole audit batches, including boundary overhead and scripted
telemetry formatting, without a potential callback or update signals. Its p95 is
the p95 of batch means, not a frame p95. It is not a full-simulation CPU benchmark.

## Packaging and rollback

```powershell
& $taskPython native/package_project.py --variant script --output .tools/packages/unicore-script.zip
& $taskPython native/package_project.py --variant native --output .tools/packages/unicore-native.zip
```

These are project archives, not validated engine exports. Native packaging requires
both DLLs and the descriptor. Script packaging excludes all bin files and extension
descriptors. Both exclude developer dependencies, imports and native source.
Clean source checkouts have no activated descriptor and start with scripted physics.
Run the script archive in a fresh project directory to verify missing-extension startup.
Actual Windows executable export and visual smoke tests remain release gates.

Set a sentry's `compute_backend` to `gdscript` to roll back its stateless numerical
reduction. No solver state or baseline moves. Fully removing the extension requires
a script-only package; changing the runtime backend cannot fix a missing DLL at startup.

## Remaining gates

Establish workload-level timings and real rendering costs on a graphical run;
resolve or formally characterize baseline regression failures; capture complete
simulation fixtures, units and random-stream state; implement and validate each
solver independently; test complete checkpoints, edits, replacement and unload;
validate native memory safety and exports; only then freeze the complete API and
consider deleting production reference paths. No end-to-end speedup, frame-time,
memory-safety or cross-platform claim is made by this initial slice.

## Molecular validation

```powershell
& ./.tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . -s res://tests/test_native_molecular_suite.gd -- --require-native
& ./.tools/godot/Godot_v4.0-stable_win64_console.exe --headless --path . -s res://tests/benchmark_molecular_solver.gd
```

The benchmark includes wrapper synchronization, both native integration stages and,
optionally, a scripted conservation audit. It excludes real visualization costs.
`--capture-fixture` prints the deterministic scripted golden step used by the suite.
To select the release DLL in a headless project that has not already auto-loaded
the debug DLL, pass `--extension=res://.tools/unicore_native_release.gdextension`
with a descriptor mapping the debug feature to the release DLL. For projects with
an existing extension cache, use a separate staged project with that descriptor
mapping; loading two implementations of the same native classes is unsupported.

Fresh-archive validation (imports both variants into isolated directories):

```powershell
python native/validate_packages.py --godot "$pwd/.tools/godot/Godot_v4.0-stable_win64.exe"
```

This uses the direct engine executable for a hidden headless import, then verifies
native and missing-extension execution paths. It leaves its staged projects and
logs under .tools for inspection. run_regressions.py also accepts --project-root
to run the full inventory against one of these staged projects.

## Validate all cores

```powershell
python native/run_solver_validation.py --godot "$pwd/.tools/godot/Godot_v4.0-stable_win64_console.exe"
```

The runner creates its release-only descriptor under .tools and verifies all six
native suites against both DLL configurations. As noted above, do not load a second
implementation of the same native classes into a process that already auto-loaded
the debug DLL; use a separate staged project/descriptor for release checks if the
root project's extension cache has been initialized.

`tests/benchmark_remaining_solvers.gd` compares scripted/native/auto complete
headless steps for gravity, 1D/2D quantum, decay and induced fission. Its
`--capture-fixtures` mode captures only the explicit gdscript backend.
