# Forensic Audit & Architecture Analysis: Obsolete Modules & Space Refactoring

**Agent**: Explorer Survey 2 (Obsolete Modules & Space Refactoring Auditor)  
**Date**: 2026-10-28  
**Project**: UniCORE (Godot 4.0.stable)  
**Target Areas**:
1. Obsolete toy modules slated for deletion (`cube_spawner_tool.gd`, `particle_system.gd`, `physics_gravity.gd`, `llm_turret_mod.gd`, `quartz_cached_mod.gd`)
2. Template refactoring in `res://core/space_manager.gd` and `res://core/module_registry_client.gd`
3. Test suite impact and breakage risk analysis across `res://tests/`

---

## 1. Executive Summary

A forensic audit of UniCORE was conducted to verify the status, remaining dependencies, template registrations, and test impacts of removing obsolete toy modules and refactoring the space management templates from `TEMPLATE_TOOL_PLAYGROUND` to `TEMPLATE_PHYSICS_LAB`.

### Key Findings
1. **Disk Status**: All 5 obsolete files (`cube_spawner_tool.gd`, `particle_system.gd`, `physics_gravity.gd`, `llm_turret_mod.gd`, `quartz_cached_mod.gd`) have already been removed from `res://modules/` on disk (marked as `D` in `git status`).
2. **Registry Residuals**: `res://core/module_registry_client.gd` still contains 3 obsolete inlined templates in `VERIFIED_MODULE_TEMPLATES`:
   - `cube_spawner` (id: `cube_spawner_tool`)
   - `physics_gravity` (id: `physics_gravity`)
   - `particle_system` (id: `particle_system`)
   None of the official physics simulation modules (`n_body_gravity_module`, `molecular_dynamics_module`, `nuclear_decay_module`, `quantum_wavepacket_module`) or tools have been registered in `VERIFIED_MODULE_TEMPLATES` yet.
3. **SpaceManager Latent Serialization Bug Uncovered**:
   - `res://core/space_manager.gd:1016` hardcodes `mod_id == "cube_spawner_tool"` as built-in, but does **not** recognize `res://modules/physics/` or `res://modules/physics/tools/`.
   - When a physics space is saved, `n_body_gravity_module` and `molecular_dynamics_module` are serialized with `"is_builtin": false`.
   - On reload, `apply_space_data()` fails to find their source code because `_resolve_module_source()` only checks `res://modules/`, `res://modules/builtin/`, and `user://modules/` (not `res://modules/physics/`), generating warnings:
     `WARNING: [SpaceManager] Module 'n_body_gravity_module' source not found in ModuleLibrary, CacheSync, or Registry`
4. **ModuleLibrary Directory Scanner Blind Spot**:
   - `res://core/module_library.gd:69-72` only calls `_scan_directory()` on `res://modules/builtin` and `res://modules`.
   - `_scan_directory()` does not recurse into subdirectories. Thus, `res://modules/physics/` and `res://modules/physics/tools/` are completely invisible to `ModuleLibrary` unless explicitly registered in `ModuleRegistryClient.VERIFIED_MODULE_TEMPLATES` or scanned directly.
5. **Test Impacts**:
   - `res://tests/test_space_management_suite.gd`: Fails 5 assertions because it still expects template key `"tool_studio"` instead of `"physics_lab"`, and expects `source_code` in space JSON.
   - `res://tests/test_module_library_suite.gd`: Still relies on `cube_spawner_tool` from `VERIFIED_MODULE_TEMPLATES`. If removed without updating the test, this suite will fail.
   - `res://tests/test_fuzzy_registry.gd`: Strictly asserts fuzzy resolution for "кубик" -> `cube_spawner_tool`, "гравитация" -> `physics_gravity`, and "партиклы" -> `particle_system`.
   - `res://tests/test_regex_all.gd`: Directly opens `"res://modules/cube_spawner_tool.gd"` from disk and crashes with a null file handle.

---

## 2. Forensic Audit of Obsolete Toy Modules

### 2.1 File-by-File Dependency Matrix

| Obsolete Module | Disk Status | Code References | Test References | Space/Registry References | Risk Level |
|---|---|---|---|---|---|
| `cube_spawner_tool.gd` | Deleted (`git status: D`) | `agent/agent_brain.gd:63` (docstring comment) | `test_module_library_suite.gd`<br>`test_fuzzy_registry.gd`<br>`test_regex_all.gd`<br>`test_space_leak_audit.gd` | `space_manager.gd:1016`<br>`module_registry_client.gd:15,29`<br>`main_menu.tscn:146` | **HIGH** (Tests break if removed from registry without test refactoring) |
| `particle_system.gd` | Deleted (`git status: D`) | None | `test_fuzzy_registry.gd` (7 queries) | `module_registry_client.gd:510-571` | **MEDIUM** (`test_fuzzy_registry.gd` fails if removed from registry) |
| `physics_gravity.gd` | Deleted (`git status: D`) | None | `test_fuzzy_registry.gd` (7 queries) | `module_registry_client.gd:376-447` | **MEDIUM** (`test_fuzzy_registry.gd` fails if removed from registry) |
| `llm_turret_mod.gd` | Deleted (`git status: D`) | None | `test_semantic_cache_suite.gd:426,439,441` (string mock only) | None | **ZERO** (Safe, disk file was leftover) |
| `quartz_cached_mod.gd` | Deleted (`git status: D`) | None | `test_semantic_cache_suite.gd:379,388,414,417` (string mock only) | None | **ZERO** (Safe, disk file was leftover) |

### 2.2 Detailed Breakdown of Residual References

#### A. `cube_spawner_tool`
1. **`res://core/space_manager.gd:1016`**:
   ```gdscript
   // CURRENT:
   var is_builtin: bool = mod_id.begins_with("builtin_") or mod_id == "cube_spawner_tool" or FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id)
   ```
   *Action Needed*: Remove `mod_id == "cube_spawner_tool"`. Add checks for `res://modules/physics/%s.gd` and `res://modules/physics/tools/%s.gd`.
2. **`res://core/module_registry_client.gd:14-80`**:
   `"cube_spawner"` template with id `"cube_spawner_tool"` is still defined in `VERIFIED_MODULE_TEMPLATES`.
   *Action Needed*: Replace with official scientific tool template (e.g., `celestial_spawner_tool`).
3. **`res://tests/test_regex_all.gd:7-13`**:
   ```gdscript
   for path in ["res://modules/cube_spawner_tool.gd", "res://modules/builtin/ground_plane.gd"]:
       var f := FileAccess.open(path, FileAccess.READ)
       var content := f.get_as_text() # CRASHES: f is null!
   ```
   *Action Needed*: Replace `"res://modules/cube_spawner_tool.gd"` with an existing module path, e.g., `"res://modules/camera_effects.gd"` or `"res://modules/physics/n_body_gravity_module.gd"`.
4. **`res://tests/test_space_leak_audit.gd:49-51`**:
   ```gdscript
   var tool_mod = mod_mgr.get_module("cube_spawner_tool")
   if tool_mod and tool_mod.has_method("spawn_cube"):
       tool_mod.spawn_cube(Vector3(i, 1.0, -2.0))
   ```
   *Impact*: Safe (has null guard), but no longer exercises dynamic node spawning.
5. **`res://ui/menu/main_menu.tscn:146`**:
   ```ini
   popup/item_3/text = "Студия Инструментов (Playground: Спавнер Кубов)"
   ```
   *Action Needed*: For UI/Design chat — update string to `"Физическая Лаборатория (Physics Lab: N-Body & Молекулярная Динамика)"`.

#### B. `particle_system`
1. **`res://core/module_registry_client.gd:510-571`**:
   Still defined in `VERIFIED_MODULE_TEMPLATES`. Uses `CPUParticles3D`, which violates the architectural constraint:
   *"Particle systems render using MultiMeshInstance3D without allocating individual Node3D nodes per particle."*
2. **`res://tests/test_fuzzy_registry.gd:120,143,150,159,167,194,222`**:
   Tests fuzzy keyword matching for `"партиклы"`, `"партикли"`, `"particls"`, `"партикл"`, `"фонтан частиц"`, and `template_ids.has("particle_system")`.

#### C. `physics_gravity`
1. **`res://core/module_registry_client.gd:376-447`**:
   Still defined in `VERIFIED_MODULE_TEMPLATES`. Uses Godot's built-in `RigidBody3D`, which is incompatible with the symplectic conservative physics engine.
2. **`res://tests/test_fuzzy_registry.gd:116,140,147,158,169,187,220`**:
   Tests fuzzy keyword matching for `"гравитация"`, `"гравитаця"`, `"graviti"`, `"гравитацыя"`, `"физический кубик"`, and `template_ids.has("physics_gravity")`.

#### D. `llm_turret_mod` and `quartz_cached_mod`
- Both files were unreferenced disk artifacts.
- `tests/test_semantic_cache_suite.gd:373-442` creates these modules in memory from multiline string literals during semantic cache hit/miss unit testing. Deleting the `.gd` files from disk causes zero issues for this suite.

---

## 3. Template Refactoring Analysis

### 3.1 SpaceManager Template Refactoring (`res://core/space_manager.gd`)

#### Current State
- Line 23-24:
  ```gdscript
  const TEMPLATE_PHYSICS_LAB: String = "physics_lab"
  const TEMPLATE_TOOL_PLAYGROUND: String = "physics_lab"
  ```
- Lines 472-478 (`get_template_definitions`):
  ```gdscript
  TEMPLATE_TOOL_PLAYGROUND: {
      "key": TEMPLATE_TOOL_PLAYGROUND,
      "name": "Physics Laboratory",
      "description": "Физическая Лаборатория: N-Body Гравитация и Молекулярная Динамика",
      "modules": ["builtin_avatar_locomotion", "n_body_gravity_module", "molecular_dynamics_module"],
      "environment": {"bg_color": [0.06, 0.07, 0.09, 1.0], "ambient_energy": 0.6}
  }
  ```
- Lines 1071-1072 (`normalize_template_type`):
  ```gdscript
  "tool_studio", "tool_playground", "playground", "tools", "toolstudio", "physics_lab", "lab":
      return TEMPLATE_TOOL_PLAYGROUND
  ```
- Lines 1094-1105 (`_build_template_space_data`):
  Instantiates `builtin_avatar_locomotion`, `n_body_gravity_module`, `molecular_dynamics_module`, `nuclear_decay_module`, `quantum_wavepacket_module`, and 5 physics tools.

#### Issues Identified
1. **Inconsistent Module Naming Contract**:
   - File on disk: `res://modules/physics/n_body_gravity_module.gd`
   - Class name: `NBodyGravityModule`
   - `get_module_id()` returns: `"n_body_gravity"` (NOT `"n_body_gravity_module"`)
   - File on disk: `res://modules/physics/molecular_dynamics_module.gd`
   - Class name: `MolecularDynamicsModule`
   - `get_module_id()` returns: `"molecular_dynamics"` (NOT `"molecular_dynamics_module"`)
   - SpaceManager `_load_builtin_module` explicitly matches `"n_body_gravity_module"` and `"molecular_dynamics_module"`.
   - If SpaceManager tries to load using the ID returned by `get_module_id()`, `_load_builtin_module` won't find it unless both IDs (with and without `_module`) are handled!
2. **Missing Path Awareness in Space Serialization**:
   - `SpaceManager._load_builtin_module()` (lines 685-696) knows how to load from `res://modules/physics/` and `res://modules/physics/tools/`.
   - BUT `SpaceManager.apply_space_data()` (line 560) only checks:
     ```gdscript
     var is_builtin: bool = bool(mod_dict.get("is_builtin", false)) or mod_id.begins_with("builtin_") or FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id)
     ```
   - AND `SpaceManager._get_current_modules_manifest()` (line 1016) only checks:
     ```gdscript
     var is_builtin: bool = mod_id.begins_with("builtin_") or mod_id == "cube_spawner_tool" or FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id)
     ```
   - Consequently, physics modules are marked `is_builtin: false` when saving, and fail to load when reopening the space.
3. **Fallback Resolution Blind Spot**:
   - `_resolve_module_source()` (lines 952-956) only checks:
     ```gdscript
     var disk_paths: Array[String] = [
         "res://modules/%s.gd" % mod_id,
         "res://modules/builtin/%s.gd" % mod_id,
         "user://modules/%s.gd" % mod_id
     ]
     ```
   - It should also include:
     ```gdscript
     "res://modules/physics/%s.gd" % mod_id,
     "res://modules/physics/tools/%s.gd" % mod_id
     ```

### 3.2 Module Registry Client Verified Templates (`res://core/module_registry_client.gd`)

#### Current State
- `VERIFIED_MODULE_TEMPLATES` contains 9 templates.
- 3 of them are obsolete toy modules:
  1. `cube_spawner` (id: `cube_spawner_tool`)
  2. `physics_gravity` (id: `physics_gravity`)
  3. `particle_system` (id: `particle_system`)

#### Required Refactoring
Replace the 3 obsolete toy templates with official physics simulation templates and interactive tools:
1. **`n_body_gravity`**:
   - ID: `"n_body_gravity"` (or `"n_body_gravity_module"`, aliased)
   - Category: `"physics"`
   - Tags: `["physics", "gravity", "nbody", "relativity", "orbit", "barneshut", "физика", "гравитация", "орбиты", "тела", "релятивизм"]`
   - Source: Points to `res://modules/physics/n_body_gravity_module.gd` or embeds canonical code.
2. **`molecular_dynamics`**:
   - ID: `"molecular_dynamics"` (or `"molecular_dynamics_module"`, aliased)
   - Category: `"physics"`
   - Tags: `["physics", "molecular", "dynamics", "lennard_jones", "thermostat", "berendsen", "gas", "молекулярная", "динамика", "газ", "термодинамика", "партиклы", "частицы", "физика"]`
   - Source: Points to `res://modules/physics/molecular_dynamics_module.gd`.
3. **`nuclear_decay`**:
   - ID: `"nuclear_decay"`
   - Category: `"physics"`
   - Tags: `["physics", "nuclear", "decay", "isotopes", "fission", "radiation", "ядерный", "распад", "изотопы", "радиация", "деление", "физика"]`
   - Source: Points to `res://modules/physics/nuclear_decay_module.gd`.
4. **`quantum_wavepacket`**:
   - ID: `"quantum_wavepacket"`
   - Category: `"physics"`
   - Tags: `["physics", "quantum", "wavepacket", "schrodinger", "tunneling", "interference", "квантовая", "волновой", "пакет", "шредингер", "туннелирование", "интерференция", "физика"]`
   - Source: Points to `res://modules/physics/quantum_wavepacket_module.gd`.
5. **Interactive Tools**:
   - `celestial_spawner_tool` (`res://modules/physics/tools/celestial_spawner_tool.gd`)
   - `particle_injector_tool` (`res://modules/physics/tools/particle_injector_tool.gd`)

*Note on Fuzzy Matching Tags*:
Notice that by giving `n_body_gravity` the tags `["гравитация", "физика", "gravity", "cube", "кубик", "отскок"]` and `molecular_dynamics` the tags `["партиклы", "частицы", "фонтан", "газ", "particles"]`, fuzzy queries in `test_fuzzy_registry.gd` ("гравитация", "партиклы") can gracefully transition to the new physics modules!

---

## 4. Test Suite Impact & Breakage Analysis

### 4.1 Broken / Failing Tests (Verified via Headless Execution)

#### 1. `res://tests/test_space_management_suite.gd`
- **Command**: `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_space_management_suite.gd`
- **Current Result**: **85 Passed, 5 Failed**
- **Failure 1 & 2** (Lines 257-258):
  ```gdscript
  assert_true(booted_space_mgr.normalize_template_type("Tool Playground") == "tool_studio", ...)
  assert_true(booted_space_mgr.normalize_template_type("playground") == "tool_studio", ...)
  ```
  *Cause*: `normalize_template_type()` now returns `physics_lab` instead of `tool_studio`.
  *Fix*: Update expected value to `"physics_lab"`.
- **Failure 3** (Line 264):
  ```gdscript
  assert_true(tmpl_defs.has("default") and tmpl_defs.has("cyber_void") and tmpl_defs.has("clean_slate") and tmpl_defs.has("tool_studio"), ...)
  ```
  *Cause*: Template definitions dictionary key is now `"physics_lab"`, not `"tool_studio"`.
  *Fix*: Check `tmpl_defs.has("physics_lab")`.
- **Failure 4 & 5** (Lines 147, 166):
  ```gdscript
  assert_true(m.has("source_code") and not m["source_code"].is_empty(), "Dynamic module source_code serialized")
  ```
  *Cause*: Architectural constraint in `space_manager.gd:1005` strictly prohibits serializing raw GDScript source into JSON files.
  *Fix*: Adjust test expectation to match the project's security architecture.

#### 2. `res://tests/test_regex_all.gd`
- **Command**: `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_regex_all.gd`
- **Current Result**: **CRASH / HANG**
- **Cause**: Line 7 iterates over `["res://modules/cube_spawner_tool.gd", "res://modules/builtin/ground_plane.gd"]`. Calling `FileAccess.open` on the deleted file returns `null`, causing an unhandled null dereference on line 10 (`f.get_as_text()`).
- **Fix**: Change `"res://modules/cube_spawner_tool.gd"` to an existing module path (e.g. `"res://modules/camera_effects.gd"`).

#### 3. `res://tests/test_module_library_suite.gd` (Pending Breakage)
- Currently passes only because `cube_spawner_tool` is still present in `ModuleRegistryClient.VERIFIED_MODULE_TEMPLATES`.
- As soon as `cube_spawner_tool` is removed from `VERIFIED_MODULE_TEMPLATES`, lines 107-163, 180, and 289 will fail because `library.get_all_modules()` will no longer contain `cube_spawner_tool`.
- **Fix**: Refactor `test_module_library_suite.gd` to test an existing registry template (such as `sphere_spawner_tool`, `camera_effects`, or `celestial_spawner_tool`).

#### 4. `res://tests/test_fuzzy_registry.gd` (Pending Breakage)
- Directly queries `ModuleRegistryClient.fuzzy_search("кубик")`, `"гравитация"`, `"партиклы"`, and asserts exact IDs:
  - `cube_spawner_tool`
  - `physics_gravity`
  - `particle_system`
- And line 220-223 asserts:
  ```gdscript
  assert_true(template_ids.has("physics_gravity"), ...)
  assert_true(template_ids.has("particle_system"), ...)
  assert_true(template_ids.has("cube_spawner_tool"), ...)
  ```
- **Fix**: Update keywords and assertions to match the new physics templates (`n_body_gravity`, `molecular_dynamics`, `celestial_spawner_tool`, etc.).

---

## 5. Precise Proposed Changes

### Proposed Change 1: `res://core/space_manager.gd`
1. **Fix `is_builtin` detection on save and load**:
   In `apply_space_data` (line 560):
   ```gdscript
   // BEFORE:
   var is_builtin: bool = bool(mod_dict.get("is_builtin", false)) or mod_id.begins_with("builtin_") or FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id)
   // AFTER:
   var is_builtin: bool = bool(mod_dict.get("is_builtin", false)) or mod_id.begins_with("builtin_") or FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id) or FileAccess.file_exists("res://modules/physics/%s.gd" % mod_id) or FileAccess.file_exists("res://modules/physics/tools/%s.gd" % mod_id)
   ```
   In `_get_current_modules_manifest` (line 1016):
   ```gdscript
   // BEFORE:
   var is_builtin: bool = mod_id.begins_with("builtin_") or mod_id == "cube_spawner_tool" or FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id)
   // AFTER:
   var is_builtin: bool = mod_id.begins_with("builtin_") or FileAccess.file_exists("res://modules/builtin/%s.gd" % mod_id) or FileAccess.file_exists("res://modules/physics/%s.gd" % mod_id) or FileAccess.file_exists("res://modules/physics/tools/%s.gd" % mod_id)
   ```
2. **Add physics directories to `_resolve_module_source()` disk fallback** (lines 952-956):
   ```gdscript
   var disk_paths: Array[String] = [
       "res://modules/%s.gd" % mod_id,
       "res://modules/builtin/%s.gd" % mod_id,
       "res://modules/physics/%s.gd" % mod_id,
       "res://modules/physics/tools/%s.gd" % mod_id,
       "user://modules/%s.gd" % mod_id
   ]
   ```
3. **Support ID resolution with and without `_module` suffix in `_load_builtin_module`** (lines 685-696):
   ```gdscript
   elif mod_id == "n_body_gravity_module" or mod_id == "n_body_gravity":
       path = "res://modules/physics/n_body_gravity_module.gd"
   elif mod_id == "molecular_dynamics_module" or mod_id == "molecular_dynamics":
       path = "res://modules/physics/molecular_dynamics_module.gd"
   elif mod_id == "nuclear_decay_module" or mod_id == "nuclear_decay":
       path = "res://modules/physics/nuclear_decay_module.gd"
   elif mod_id == "quantum_wavepacket_module" or mod_id == "quantum_wavepacket":
       path = "res://modules/physics/quantum_wavepacket_module.gd"
   ```

### Proposed Change 2: `res://core/module_library.gd`
Add `res://modules/physics` and `res://modules/physics/tools` to `scan_library()`:
```gdscript
// lines 68-73:
_scan_directory("res://modules/builtin", true, seen_ids, new_catalog, registry_templates)
_scan_directory("res://modules/physics", true, seen_ids, new_catalog, registry_templates)
_scan_directory("res://modules/physics/tools", true, seen_ids, new_catalog, registry_templates)
_scan_directory("res://modules", false, seen_ids, new_catalog, registry_templates)
```
And add them to `has_module()` and `get_module_source()` `direct_paths`.

### Proposed Change 3: `res://core/module_registry_client.gd`
Replace `cube_spawner`, `physics_gravity`, and `particle_system` in `VERIFIED_MODULE_TEMPLATES` with:
- `n_body_gravity` (referencing `res://modules/physics/n_body_gravity_module.gd`)
- `molecular_dynamics` (referencing `res://modules/physics/molecular_dynamics_module.gd`)
- `nuclear_decay` (referencing `res://modules/physics/nuclear_decay_module.gd`)
- `quantum_wavepacket` (referencing `res://modules/physics/quantum_wavepacket_module.gd`)
- `celestial_spawner_tool` (referencing `res://modules/physics/tools/celestial_spawner_tool.gd`)
- `particle_injector_tool` (referencing `res://modules/physics/tools/particle_injector_tool.gd`)

---

## 6. Synthesis and Conclusion

1. **Deletion of Obsolete Files**: The 5 targeted toy module files are already deleted from the working tree.
2. **Space Template Transition**: SpaceManager's `TEMPLATE_TOOL_PLAYGROUND` has been redirected to `physics_lab`, mounting real physics modules. However, SpaceManager still suffers from path blindness when saving/loading physics spaces due to lines 560, 952, and 1016.
3. **Test Suite Hygiene**: The 4 affected test files (`test_space_management_suite.gd`, `test_module_library_suite.gd`, `test_fuzzy_registry.gd`, `test_regex_all.gd`) must be coordinated with the registry updates to keep `--check-only` and headless execution clean.
