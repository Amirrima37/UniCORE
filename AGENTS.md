# UniCORE working guide

Godot 4.7.2 front end; GDScript owns documents and UI, isolated Python jobs own
CAD/meshing/solver orchestration, C++ owns OCCT geometry and native physics.
Start with docs/architecture/README.md and the subsystem relevant to the task.

- `core/cae/`: CAD graph, mesh identity, conditions, solver backends, persistence.
- `ui/cae/`: engineering workspace and review workflows.
- `scripts/engines/`: OCCT/Gmsh/CalculiX jobs, ownership and retention.
- `native/occt/`: isolated worker, SDK lock and provisioning; `native/src/`: physics.
- `tests/`: focused CAD runners and native regression manifest; fixtures are sources.

Preserve dirty and untracked work. Never reset, clean, or delete unfamiliar files.
Do not scan `.tools`, `.godot`, `.git`, native build/vendor trees, Python caches,
or historical evidence by default. Use `python scripts/source_files.py` for a
focused inventory. Open specific receipts only when needed. These instructions
guide discovery; neither Git ignores nor this file enforce read restrictions.

Pinned dependencies: Godot 4.7.2, Gmsh 4.15.2, CalculiX 2.23, OCCT 7.8.1;
the seven original hashes are in the CAD24 completion final receipt.
External development paths are centralized in `scripts/engines/development_paths.py`.
`UNICORE_OCCT_SDK_ROOT` defaults to `D:/PROJECT/SDK/OCCT`.
`UNICORE_GODOT_ENV_ROOT` defaults to `D:/PROJECT/GODOT/TEST_ENVIRONMENTS/godot472-migration`.
`UNICORE_TEST_OUTPUT_ROOT` defaults to `D:/PROJECT/TEST_OUTPUTS`.
Godot build objects use `UNICORE_BUILD_CACHE_ROOT` or `D:/PROJECT/CACHE/BUILD`.
Use process-local overrides. Keep SDK archives, lockfiles and manifests for offline reconstruction.
Native changes require import auditing, build sealing, and real native tests.
`native/build_occt.ps1` also requires the existing `D:/msys64` compiler environment.
Never weaken pin verification or numerical assertions.

Use the installed Python explicitly if the `python` alias does not launch.
Focused checks: `python tests/cad24_native.py`, `python tests/cad24_history.py`,
`python tests/cad24_retention.py`; preservation: `python tests/run_cad21.py preservation`.
Full campaign: `python tests/run_cad24_completion.py`.
Default regression: `python native/run_regressions.py --godot <pinned-exe> --output <new-evidence-dir>`.
Omit `--output` for a unique regression workspace under the external output root.
Set `UNICORE_TEST_OUTPUT_ROOT` to choose another parent.
The runner places its Godot profile there too and prints the output path.
Logs and failure diagnostics are retained there for review; remove the workspace
after reviewing results and confirming all its workers have exited.
Require all 28 default regressions. Runners retain unique attempts and raw logs.

Engineering evidence is user data. Keep final receipts, failed diagnostics,
fixtures and pinned/archived evidence. Delete managed jobs only through
`scripts/engines/artifact_retention.py`: 2 GiB, seven days, 600-second grace,
active/pinned/archived protections. Verify lossless external archives before
removing originals; record per-file hashes and restoration instructions.
