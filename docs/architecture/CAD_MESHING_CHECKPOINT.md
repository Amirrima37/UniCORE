# CAD Checkpoint A — PARTIAL (2026-11-13)

The existing dirty repository and CalculiX stabilization work were preserved. This checkpoint is not a STEP-to-CalculiX PASS.

## Later Godot 4.7.2 migration evidence

The separate engine migration now launches the existing Workbench graphically under the supplied Godot 4.7.2 runtime and verifies 28/28 default regressions, real Box/Cylinder Gmsh → CalculiX result screens, seven engineering checks including the two real STEP OCC fixtures, four Extreme native build configurations, and five clean shell startup/shutdown cycles. See [GODOT_4_7_2_MIGRATION.md](GODOT_4_7_2_MIGRATION.md). This supersedes the earlier statement below that graphical Workbench acceptance is blocked by the Godot 4.0 minimal-project crash. It does **not** complete imported STEP → CalculiX or prove that every historical crash is fixed. The 4.0 crash evidence remains valid for that runtime.

## Implemented

- Existing Gmsh 4.15.2 SDK OCC import accepts one STEP solid. Embedded source bytes are SHA-256 checked and capped at 64 MiB before import; the bridge rejects zero-volume and multiple-solid imports. CAD face groups are named from the source hash and OCC face tag. The existing TET4 validator checks positive determinants, nonmanifold faces, and exact exterior triangle coverage.
- The existing Geometry menu has an Import STEP action. It embeds the original bytes in the UCAE JSON document, stores source SHA-256, and starts the existing asynchronous Gmsh path. The imported boundary triangulation is used for viewport geometry after meshing. Imported face groups appear in the face selector and can be sent to the existing support/force commands. Project open rejects corrupted embedded bytes. The original import path is not needed after save.
- CalculiX adapter retains the existing per-face triangle area weighting and node mapping. No new solver execution on imported STEP has been observed, so this remains an unverified connection.

## Real engine test

Run `C:/Users/Victus/AppData/Local/Python/bin/python.exe tests/test_step_gmsh_real.py` from the repository root. Actual exit 0 after a first failed test-harness attempt corrected the `getBoundary` API call. The script uses the pinned real SDK to export two OCC solids to STEP, reimports both, checks one solid, volume, bounds, face count, and SHA, then calls the production bridge and checks TET4 orientation and boundary coverage. Actual files and JSON receipt are under `tests/fixtures/step/`.

Bar: CAD volume 0.010000000000000002 m3, 6 faces, 86 nodes, 201 TET4, mesh volume 0.010000000000000021 m3. Cylinder: CAD volume 0.006283185307179587 m3, 3 faces, 85 nodes, 231 TET4, faceted mesh volume 0.0060506026267136935 m3. Both have positive minimum Jacobian. Gmsh STEP writer reports Open CASCADE STEP translator 7.8.1; direct OCCT library integration was not added. Exact source hashes are in receipt.json because repeated STEP export can change file bytes.

## Missing acceptance

The original Godot launches were interrupted before the failure mode was correctly classified; the reproduced access violation is documented below. No GUI screenshot or GUI PASS is claimed. Imported STEP > CalculiX was not executed. Save/reopen with moved original, corruption rejection inside Godot, analytical bar comparison, cylinder independent comparison, refinement, actual cancellation/timeout/stale worker cases, 28 default regressions and the CalculiX campaign remain unrun. The current import uses a mesh-derived CAD rendering once meshed; before meshing the viewport has no imported solid display. Face naming is valid only for unchanged bytes/import settings, and no topology healing/validation beyond one positive-volume solid is implemented. The prior Godot access violation remains unresolved.

Verdict: PARTIAL. Do not use this checkpoint as evidence of the required complete Workbench solve or visualization.

## Critical correction: current Godot access violation (2026-11-13)

The earlier phrase "graphical launches did not finish" was misleading. A Windows native debug-event run now **reproduces a second-chance 0xC0000005 access violation**. This is a crash, not evidence of a hang. The user also reported closing a Windows crash dialog manually; the captured debugger run avoids dependence on that dialog.

The exact current exception is a READ at address `0x0000000000000068`, RIP `0x00007ff756aa9148` in `Godot_v4.0-stable_win64.exe` loaded at `0x00007ff752360000` (module offset `0x4749148`). The bytes at RIP begin `48 83 7b 68 00`, i.e. `cmp qword ptr [rbx+68h],0`; RBX is zero in the captured context. The fault therefore is a null-base field read in this reproduction. The prior historical crash is different: Godot offset `0x518504`, `mov rax,[rax+68h]`, with a nonzero RAX and a nonzero invalid read address. Equal exception class and `+68h` displacement do not establish one common root cause.

A 7-frame DbgHelp StackWalk64 trace contains the Godot executable, kernel32 and ntdll. No UniCORE extension, Gmsh or OCCT module is loaded in the captured minimal-project run. The **same RIP, instruction, access address and stack** reproduce for (a) the full app-shell test, (b) `--headless --path . --quit`, and (c) a separate minimal `project.godot` containing only `config_version=5`. The last case establishes that the current failure does not require the STEP code, UniCORE scripts, GDExtension or its thread boundaries. The installed Godot 4.0 binary SHA-256 is `dbc5b785ac1df4878d15e527b7d41f16c83a1107958762ac03c0c7ac35daad5c`.

Evidence is retained in `docs/architecture/evidence/cad-crash-current/`, `cad-crash-startup/` and `cad-crash-minimal/`: debug events, loaded modules, registers, exact instruction bytes, stack offsets and valid `MDMP` minidumps. Reproduce with `C:/Users/Victus/AppData/Local/Python/bin/python.exe tests/diagnose_cad_minimal.py` from the repository root. The debugger helper captures a second-chance exception and lets Windows terminate the process; it does not swallow the exception. A matching PDB/WinDbg is unavailable locally, so the native function name and deeper Godot source root cause remain unresolved. The dump's recorded DbgHelp last-error 6 is stale after successful `MiniDumpWriteDump`; the file has a valid MDMP header and nonzero size. No claim is made that the historical AnalysisDrawer lifetime correction caused or fixes this distinct minimal-project fault.

**Graphical STEP acceptance remains blocked by the reproduced Godot executable crash.** No GUI screenshots or STEP-to-CalculiX pass are claimed. The production code has not been disabled or the exception hidden.


## Godot 4.7.2 comparison requested by user

Tested the user's binary `D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`, SHA-256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`. The existing Godot 4.0 binary and project configuration were not replaced.

A valid minimal Godot scene under the same debug-event harness completed with actual process exit **0**, no second-chance `0xC0000005`, and no dump. See `docs/architecture/evidence/godot472-valid-minimal/debug-events.json`. By comparison, the 4.0 binary crashes with `0xC0000005` on the same minimal project, with RIP/`RBX`/access address documented above. This supports an engine-version-specific failure for the minimal reproduction. It does not prove which Godot source change fixed it.

The 4.7.2 binary was also launched against UniCORE with `--headless --path . --quit`. The bounded 25-second attempt produced **no access violation** but reached the harness timeout and required termination. Its raw log contains numerous GDScript parse errors, including unresolved `CyberTheme` in `ui/hud/top_bar.gd`; therefore it did not establish application or Workbench compatibility. See `docs/architecture/evidence/godot472-unicore-startup/`. The earlier 4.7.2 run against an invalid minimal project was discarded as acceptance evidence because that project lacked a valid main scene. The valid-scene exit-0 run supersedes it.

Reproduction commands from repository root: `C:/Users/Victus/AppData/Local/Python/bin/python.exe tests/diagnose_godot472_valid_minimal.py` and `C:/Users/Victus/AppData/Local/Python/bin/python.exe tests/diagnose_godot472_unicore.py`. Neither result is a graphical STEP or CalculiX acceptance run. No false crash fix or full Godot upgrade is claimed.
`nThe 4.0 comparison was rerun after creating the valid minimal scene; it again exited 0xC0000005 at the same instruction. See docs/architecture/evidence/cad-crash-valid-minimal/debug-events.json. The first rerun attempt could not overwrite a locked earlier debuggee.log and is not counted as an execution.

