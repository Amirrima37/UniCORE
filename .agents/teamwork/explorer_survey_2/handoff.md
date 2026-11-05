# Handoff Report: Survey Explorer 2 (Obsolete Modules & Space Refactoring Auditor)

**Type**: Soft Handoff  
**Date**: 2026-10-28  
**Agent**: Explorer Survey 2  
**Parent Task**: ac022d96-cb0f-4487-9656-dfce4b989f50  
**Artifact**: `c:\dev\UniCORE\.agents\teamwork\explorer_survey_2\analysis.md`

---

## 1. Observation

1. **Obsolete Modules on Disk**:
   - `res://modules/cube_spawner_tool.gd`, `res://modules/particle_system.gd`, `res://modules/physics_gravity.gd`, `res://modules/llm_turret_mod.gd`, `res://modules/quartz_cached_mod.gd` have been deleted in the local workspace (`git status: D`).
2. **Registry Residuals**:
   - `res://core/module_registry_client.gd:14-80` still contains the `"cube_spawner"` template (`id: "cube_spawner_tool"`).
   - `res://core/module_registry_client.gd:376-447` still contains the `"physics_gravity"` template.
   - `res://core/module_registry_client.gd:510-571` still contains the `"particle_system"` template.
   - None of the 4 official physics simulation modules or tools have been registered in `VERIFIED_MODULE_TEMPLATES`.
3. **SpaceManager (`res://core/space_manager.gd`)**:
   - Lines 23-24: `const TEMPLATE_PHYSICS_LAB: String = "physics_lab"` and `const TEMPLATE_TOOL_PLAYGROUND: String = "physics_lab"`.
   - Lines 472-478: Template definition `TEMPLATE_TOOL_PLAYGROUND` mounts `builtin_avatar_locomotion`, `n_body_gravity_module`, and `molecular_dynamics_module`.
   - Lines 1094-1105: `_build_template_space_data()` creates physics lab spaces with all physics modules and interactive tools.
   - Line 1016 (`_get_current_modules_manifest`):
     `var is_builtin: bool = mod_id.begins_with("builtin_") or mod_id == "cube_spawner_tool" or FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id)`
     Still hardcodes `cube_spawner_tool`, and does **not** recognize `res://modules/physics/` or `res://modules/physics/tools/`.
   - Line 560 (`apply_space_data`):
     `var is_builtin: bool = bool(mod_dict.get("is_builtin", false)) or mod_id.begins_with("builtin_") or FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id)`
     Also lacks awareness of `res://modules/physics/`.
   - Lines 952-956 (`_resolve_module_source`):
     Does not check `res://modules/physics/` or `res://modules/physics/tools/`.
   - Running `test_space_management_suite.gd` emitted:
     `WARNING: [SpaceManager] Module 'n_body_gravity_module' source not found in ModuleLibrary, CacheSync, or Registry`
4. **ModuleLibrary Directory Scanner (`res://core/module_library.gd`)**:
   - Lines 69-72: `_scan_directory()` is only called on `res://modules/builtin` and `res://modules`.
   - Line 430: `_scan_directory()` uses `dir.get_files()` without directory recursion, causing `res://modules/physics/` to be completely invisible to `ModuleLibrary`.
5. **Existing Test Suite State**:
   - `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only` exits with **0** (clean parse).
   - `test_space_management_suite.gd`: 85 Passed, 5 Failed (fails lines 257-258 expecting `tool_studio` instead of `physics_lab`, line 264 expecting `tmpl_defs.has("tool_studio")`, and lines 147, 166 expecting serialized source code in space json).
   - `test_module_library_suite.gd`: Currently passes, but heavily asserts `cube_spawner_tool` existence in lines 90, 107-163, 180, 289.
   - `test_fuzzy_registry.gd`: Strictly asserts fuzzy resolution for `cube_spawner_tool`, `physics_gravity`, and `particle_system`.
   - `test_regex_all.gd`: Line 7 opens `res://modules/cube_spawner_tool.gd` directly and crashes/hangs due to null dereference.

---

## 2. Logic Chain

1. From **Observation 1 & 2**:
   - The obsolete toy module files have been removed from disk, but their definitions remain alive in memory via `ModuleRegistryClient.VERIFIED_MODULE_TEMPLATES`.
   - Removing them from `VERIFIED_MODULE_TEMPLATES` without simultaneously refactoring `test_module_library_suite.gd` and `test_fuzzy_registry.gd` will immediately cause test suite failures because those tests query `ModuleRegistryClient` directly.
2. From **Observation 3 & 4**:
   - When a physics space is created and subsequently saved, `_get_current_modules_manifest()` marks physics modules as `is_builtin: false` because they are located in `res://modules/physics/` rather than `res://modules/builtin/`.
   - When reloading the saved space, `apply_space_data()` does not call `_load_builtin_module()` and delegates to `_resolve_module_source()`.
   - Neither `_resolve_module_source()` nor `ModuleLibrary` scans `res://modules/physics/`.
   - Consequently, physics modules fail to load on space switch or reload.
   - Therefore, SpaceManager lines 560, 952-956, and 1016, and ModuleLibrary lines 69-72 must be made aware of `res://modules/physics/` and `res://modules/physics/tools/`.
3. From **Observation 3 & 5**:
   - The 5 failures in `test_space_management_suite.gd` are directly caused by:
     - The template key rename from `tool_studio` to `physics_lab` without updating the test's expected string in lines 257, 258, and 264.
     - A legacy test assertion checking for serialized GDScript in space JSON files, which is intentionally forbidden by `SpaceManager`.
   - `test_regex_all.gd` fails because it attempts to open the deleted `res://modules/cube_spawner_tool.gd` without checking if the file exists.

---

## 3. Caveats

1. **Read-Only Investigation**: As an Explorer, no core codebase modifications or deletions were performed; changes were audited and verified using read-only analysis and isolated headless test runs.
2. **UI Text References**: `res://ui/menu/main_menu.tscn:146` still contains the label `"Студия Инструментов (Playground: Спавнер Кубов)"`. Under `GEMINI.md`, `res://ui/` belongs strictly to the UI/Design chat and should be updated by that team.
3. **Multi-Agent Concurrency**: Some files (`space_manager.gd`, module deletions) were being concurrently touched in the workspace by peer agents. All findings reflect the exact current workspace state.

---

## 4. Conclusion

The safe deletion of toy modules and refactoring of `TEMPLATE_TOOL_PLAYGROUND` into `TEMPLATE_PHYSICS_LAB` requires a coordinated 4-part update:
1. **Clean Registry Templates**: Update `ModuleRegistryClient.VERIFIED_MODULE_TEMPLATES` to purge the 3 obsolete toy templates and register the official physics simulation modules (`n_body_gravity`, `molecular_dynamics`, `nuclear_decay`, `quantum_wavepacket`) and tools (`celestial_spawner_tool`, `particle_injector_tool`).
2. **Fix SpaceManager Path Blindness**: Update `space_manager.gd` lines 560, 685-696, 952-956, and 1016 to recognize `res://modules/physics/` and `res://modules/physics/tools/` as built-in and disk-resolvable, removing the hardcoded `cube_spawner_tool`.
3. **Fix ModuleLibrary Scanning**: Add `res://modules/physics` and `res://modules/physics/tools` to `ModuleLibrary.scan_library()`.
4. **Update Dependent Tests**: Synchronize `test_space_management_suite.gd`, `test_module_library_suite.gd`, `test_fuzzy_registry.gd`, and `test_regex_all.gd`.

---

## 5. Verification Method

To verify these findings and any subsequent fixes independently:

1. **Static Type & Syntax Verification**:
   ```powershell
   & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
   ```
   *Expected*: Exit code 0.
2. **Inspect Space Management Test**:
   ```powershell
   & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_space_management_suite.gd
   ```
   *Expected*: Verify the 5 failures in lines 147, 166, 257, 258, 264 and the warnings regarding `n_body_gravity_module` and `molecular_dynamics_module`.
3. **Inspect Regex Test**:
   ```powershell
   & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_regex_all.gd
   ```
   *Expected*: Verify it fails when `cube_spawner_tool.gd` is missing.
4. **Inspect Module Registry Templates**:
   Inspect `res://core/module_registry_client.gd:13-80` to verify whether toy modules are present.

---

## 6. Remaining Work (For Implementer / Next Agent)

1. **`res://core/space_manager.gd`**:
   - Line 560: Add `or FileAccess.file_exists("res://modules/physics/%s.gd" % mod_id) or FileAccess.file_exists("res://modules/physics/tools/%s.gd" % mod_id)`.
   - Lines 685-696: Ensure IDs with and without `_module` suffix resolve properly to the script files.
   - Lines 952-956: Add `res://modules/physics/%s.gd` and `res://modules/physics/tools/%s.gd` to `disk_paths`.
   - Line 1016: Replace `mod_id == "cube_spawner_tool"` with checks for physics directories.
2. **`res://core/module_library.gd`**:
   - Lines 69-72: Add `_scan_directory("res://modules/physics", true, ...)` and `_scan_directory("res://modules/physics/tools", true, ...)`.
   - Add physics paths to `direct_paths` in `has_module()` and `get_module_source()`.
3. **`res://core/module_registry_client.gd`**:
   - Replace obsolete templates (`cube_spawner`, `physics_gravity`, `particle_system`) with official physics templates (`n_body_gravity`, `molecular_dynamics`, `nuclear_decay`, `quantum_wavepacket`, `celestial_spawner_tool`, `particle_injector_tool`).
4. **`res://tests/test_space_management_suite.gd`**:
   - Update lines 257, 258 to expect `"physics_lab"`.
   - Update line 264 to expect `tmpl_defs.has("physics_lab")`.
   - Adjust lines 147 and 166 to align with `SpaceManager`'s policy against serializing source code into space JSON.
5. **`res://tests/test_module_library_suite.gd`**:
   - Replace references to `"cube_spawner_tool"` with an official template (e.g. `"sphere_spawner_tool"` or `"celestial_spawner_tool"`).
6. **`res://tests/test_fuzzy_registry.gd`**:
   - Update expected template IDs and keywords to match the updated physics templates.
7. **`res://tests/test_regex_all.gd`**:
   - Replace `"res://modules/cube_spawner_tool.gd"` with an existing file path.
