# Godot 4.7.2 migration checkpoint — PARTIAL

Date: 2026-11-13. Baseline HEAD: `13e40a5a565a273485aa80ea14ed110df36136a2`. The working tree already held 181 changed or untracked entries. Prior code, fixtures, and Godot 4.0 crash evidence were retained.

## Runtime and native extension

The supplied Windows x86-64 executable is `D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`; banner `4.7.2.stable.official.ed1daf0bf`; SHA-256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`. A valid minimal project exited 0. The retained Godot 4.0 executable still reproduces the documented minimal-project `0xC0000005` null-base read at `+0x68`; see `CAD_MESHING_CHECKPOINT.md` and `docs/architecture/evidence/cad-crash-valid-minimal/`. This campaign observed no such exception under 4.7.2. It does not prove that all historical crashes are gone.

The 4.0-built GDExtension could not be reused. Godot 4.7 requires `compatibility_minimum >= 4.1`, and loading the old DLL after adding that key crashed during editor scan. We rebuilt against official `godot-cpp` commit `2a4c066e1e8c121046e9d35fe91cc8e726861c48`, selecting its 4.7 API and `native/godot472_profile.json`. This is a pinned repository commit, not an official 4.7.2 tag. `native/src/bindings/register_types.cpp` now uses the 4.1+ entry-point signature. The descriptor selects separately named 4.7 debug/release DLLs; old DLL bytes remain. Debug SHA-256: `293734a767241b3914f08d9829d6647a3efee5c93a85d375c6744c66296a20cc`. Release SHA-256: `7d0ab1ba5cb393068bdae4424ae1f754e8574b39a9ff93f7358ee63fad7bd03f`. Both were built with Qt MinGW 13.1 x86-64 and loaded in Godot.

`native/build_godot472.ps1 -Target template_debug` and `-Target template_release` rebuild UniCORE DLLs after matching `godot-cpp` archives exist. SCons compiled the profiled binding objects but its archive command exceeded the Windows command-line limit; `native/archive_godot472.py` assembled them in bounded batches. The upstream checkout and SCons installation remain under ignored `.tools/`. A clean-machine unattended dependency/bootstrap script is still missing.

## Script and Workbench fixes

The initial unresolved `CyberTheme` was a cascade from the failed extension/editor class scan. Its actual `class_name` and theme implementation remain intact. After rebuilding, `tests/run_godot472_scan.py` completed the editor/class scan with exit 0 and no parser errors. `core/cae/cae_document.gd` and `ui/cae/cae_workspace.gd` now use `HashingContext` for STEP byte arrays. `core/space_viewport.gd` calls the actual orb status API, removing a runtime method error.

The physics feature harness now executes after child `_ready()` because 4.7 schedules that lifecycle differently; all 14 assertions passed. The CAE recovery test canonicalizes parsed JSON because 4.7 serializes `0` and `0.0` differently; engineering values are still compared exactly. Numerical thresholds were not weakened.

The real Vulkan Workbench launched with its existing dark shell, `CyberTheme`, Model Explorer, inspector, viewport and navigation. `tests/test_godot472_main_shell.gd` exercised shell navigation and selected a cylinder at 1280×720 and 1920×1080. `tests/test_godot472_calculix_workbench.gd` executed real Gmsh and CalculiX Box/Cylinder studies, save/reopen and stale-result checks, and captured mesh, backend, execution, displacement and von Mises screens at both sizes. Exit 0; log markers `CALCULIX_WORKBENCH_PASS Box` and `CALCULIX_WORKBENCH_PASS Cylinder`. These are primitive studies. Imported STEP-to-CalculiX remains incomplete.

## Acceptance receipts

| Campaign | Actual result | Receipt |
|---|---|---|
| 4.7 editor/class scan | exit 0; zero parser errors | `.tools/godot472-migration/editor-scan.log` |
| Default regressions | 28/28, all exit 0 | `.tools/godot472-migration/default-regressions-final/receipt.json`, `results.json` |
| Graphical CalculiX Workbench | exit 0; Box and Cylinder pass | `.tools/godot472-migration/calculix-gui-rerun.log`, `workbench/*.png` |
| Main shell and both screen sizes | exit 0; zero reported failures | `.tools/godot472-migration/main-shell-capture-final.log`, `main-shell-*.png` |
| CalculiX adapter, patch, process, Gmsh repeatability, Extreme comparison, benchmarks, STEP OCC | seven checks, each exit 0 | `.tools/godot472-migration/engineering/results.json` |
| Four Extreme build configurations | see receipt | `.tools/godot472-migration/dynamics-builds/results.json` |
| Transient/modal numerical campaign | 31,615 assertions; runner exit 0 | `.tools/godot472-migration/dynamics-numerical/results.json` |
| Five shell startup/shutdown cycles | see receipt | `.tools/godot472-migration/startup-cycles/results.json` |

The existing bar/cantilever benchmark still reports 15.86% bending error at the finest density. The STEP OCC test verifies two real imported and meshed fixtures, but not interactive STEP structural solving. GUI scripts exercised actual controls and screenshots, but cannot cover every manual interaction or old project resource. No access violation was observed in the documented 4.7.2 runs.

Selected raw screenshots, GUI logs and JSON receipts were copied without alteration to `docs/architecture/evidence/godot472-migration/`. In particular, `main-shell-1280.png` and `main-shell-1920.png` show the existing interface, while `Box-displacement-*.png` and `Cylinder-von_mises-*.png` show actual CalculiX fields. Full job data and per-test logs remain under `.tools/godot472-migration/`.

The five bounded shell cycles took 11.852, 8.039, 8.160, 8.208 and 8.008 seconds end to end on this machine, including the five-frame quit condition. These are measured startup/shutdown observations, not a controlled performance comparison with Godot 4.0. GUI frame time and peak application memory were not measured.

## Reproduction and remaining scope

From the repository root, use Python with project dependencies. Set `UNICORE_PYTHON` to that interpreter before launching Godot for Gmsh jobs. Migration tests isolate `user://` under `.tools/godot472-migration` to preserve earlier evidence. Use fresh output paths for evidence-preserving runners.

```powershell
C:/Users/Victus/AppData/Local/Python/bin/python.exe tests/run_godot472_scan.py
C:/Users/Victus/AppData/Local/Python/bin/python.exe native/run_regressions.py --godot D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe --output .tools/godot472-migration/default-regressions-new
C:/Users/Victus/AppData/Local/Python/bin/python.exe tests/run_godot472_engineering.py --output .tools/godot472-migration/engineering-new
C:/Users/Victus/AppData/Local/Python/bin/python.exe tests/run_godot472_startup_cycles.py --output .tools/godot472-migration/startup-cycles-new
C:/Users/Victus/AppData/Local/Python/bin/python.exe tests/validate_stage7_dynamics.py --phase builds --output .tools/godot472-migration/dynamics-builds-new
C:/Users/Victus/AppData/Local/Python/bin/python.exe tests/validate_stage7_dynamics.py --phase numerical --output .tools/godot472-migration/dynamics-numerical-new
```

Launch the supplied executable with `--path .` after setting `UNICORE_PYTHON`, then navigate to CAE Workbench. The 4.0 binary remains a historical reference. The checkpoint is **PARTIAL** because clean-machine native bootstrap, exhaustive legacy project/resource interaction, and the separate STEP-to-CalculiX feature are incomplete. No OpenFOAM, Boolean CAD, or multi-body work was begun.
