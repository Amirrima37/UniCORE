# HANDOFF — Explorer Survey 3 (Physics Engine Architecture & Test Inspector)

## 1. Observation

1. **`EventBus` Missing `publish()` Method**:
   - `res://core/event_bus.gd:27-36` defines:
     ```gdscript
     func emit(event_name: String, payload: Dictionary = {}) -> void:
         event_emitted.emit(event_name, payload)
         ...
     ```
   - In `res://core/physics/interaction/physics_interaction_manager.gd:163, 174, 184, 196, 205, 215`:
     ```gdscript
     _event_bus.publish("physics_entity_spawned", {"module_id": "n_body_gravity_module", "entity": entity_data})
     ```
   - In `res://modules/physics/tools/particle_injector_tool.gd:56, 73`:
     ```gdscript
     _event_bus.publish("gas_molecules_injected", ...)
     ```
   - In `res://modules/physics/tools/celestial_spawner_tool.gd:57`:
     ```gdscript
     _event_bus.publish("celestial_body_created", ...)
     ```
   - In `res://ui/physics/physics_time_bar.gd:61`:
     ```gdscript
     _event_bus.publish(event_name, payload)
     ```
   - There is zero declaration of `func publish` in `event_bus.gd` or anywhere in the repository. Calling `publish` causes a fatal runtime crash: `"Invalid call. Nonexistent function 'publish' in base 'Node (event_bus.gd)'"`.

2. **`CelestialSpawnerTool` vs `NBodyGravityModule` Parameter Mismatch**:
   - `res://modules/physics/tools/celestial_spawner_tool.gd:50-53`:
     ```gdscript
     if _gravity_module and _gravity_module.has_method("spawn_body"):
         _gravity_module.spawn_body(position, velocity, mass, body_type)
     elif _gravity_module and _gravity_module.has_method("add_body"):
         _gravity_module.add_body(position, velocity, mass)
     ```
   - `res://modules/physics/n_body_gravity_module.gd:628`:
     ```gdscript
     func add_body(p_name: String, pos: Vector3, vel: Vector3, mass: float, radius: float = 0.2, col: Color = Color.WHITE) -> void:
     ```
   - `NBodyGravityModule` does NOT have `spawn_body`. When it falls back to `add_body(position, velocity, mass)`, `position: Vector3` is passed as argument 1 (`p_name: String`), failing with a type error.

3. **`MolecularDynamicsModule` Missing Inject and Reset APIs**:
   - `res://modules/physics/tools/particle_injector_tool.gd:51-53, 84`:
     ```gdscript
     if _md_module and _md_module.has_method("inject_particles"):
         _md_module.inject_particles(pos, count, temp)
     ...
     if _md_module and _md_module.has_method("reset_to_maxwell_boltzmann"):
         _md_module.reset_to_maxwell_boltzmann()
     ```
   - Neither `inject_particles` nor `reset_to_maxwell_boltzmann` exists in `res://modules/physics/molecular_dynamics_module.gd`. The tool executes without errors, but silently does nothing.

4. **`ScientificProbeTool` Member Variable Name Mismatches**:
   - `res://modules/physics/tools/scientific_probe_tool.gd:195, 199, 215`:
     ```gdscript
     var positions: PackedVector3Array = _gravity_module.get("positions")
     var eps_sq: float = float(_gravity_module.get("softening_length"))
     var positions: PackedVector3Array = _md_module.get("positions")
     ```
   - In `n_body_gravity_module.gd:86, 42`: variable is `_positions` (getter `get_positions()`), and property is `softening` (not `softening_length`).
   - In `molecular_dynamics_module.gd:50`: variable is `_positions` (getter `get_positions()`). Calling `.get("positions")` returns `null`.

5. **`QuantumWavePacketModule` Missing Public Configuration Methods**:
   - `res://modules/physics/tools/quantum_bench_tool.gd:95-99, 112, 126, 135`:
     Calls `set_potential_type`, `set_barrier_height`, `set_barrier_width`, `cycle_potential_type`, `toggle_dimension`.
   - `res://modules/physics/quantum_wavepacket_module.gd` lacks these public methods (it only has internal `_unhandled_input` key bindings).

6. **Obsolete Modules on Disk vs Registry Templates**:
   - Files `res://modules/cube_spawner_tool.gd`, `particle_system.gd`, `physics_gravity.gd`, `llm_turret_mod.gd`, `quartz_cached_mod.gd` do not exist on disk.
   - However, `res://core/module_registry_client.gd:13-80` contains inline code templates for `cube_spawner`, `sphere_spawner`, `physics_gravity`, and `particle_system`.
   - Tests `test_fuzzy_registry.gd` and `test_module_library_suite.gd` actively assert the presence of `"cube_spawner_tool"`.

7. **Master Test Runner Integration**:
   - `res://tests/test_runner.gd:24`:
     ```gdscript
     if not dir.current_is_dir() and file_name.ends_with("_suite.gd") and file_name != "test_runner.gd":
         suites.append("res://tests/" + file_name)
     ```
   - Any script in `res://tests/*_suite.gd` extending `SceneTree` that terminates with `quit(0)` or `quit(1)` will be automatically executed and aggregated.

---

## 2. Logic Chain

1. From Observation 1: If any UI element or interactive tool executes `_event_bus.publish(...)`, Godot throws a runtime crash because `publish` is undefined on `EventBus`. Adding `func publish(event_name: String, payload: Dictionary = {}) -> void: emit(event_name, payload)` to `event_bus.gd` provides zero-cost backwards and forward compatibility across both naming conventions.
2. From Observation 2: If a user uses `CelestialSpawnerTool` to spawn a planet/star, the fallback call `_gravity_module.add_body(position, velocity, mass)` passes a `Vector3` where a `String` is expected. Implementing `func spawn_body(pos: Vector3, vel: Vector3, mass: float, body_type: String = "planet") -> void` in `NBodyGravityModule` cleanly resolves the call and avoids type errors.
3. From Observation 3: In `MolecularDynamicsModule`, particles are currently only initialized in a lattice at start. To allow `ParticleInjectorTool` to function, `MolecularDynamicsModule` must expose `inject_particles(pos: Vector3, count: int, temp: float) -> void` which resizes the arrays, appends new coordinates with Maxwell-sampled velocities, and synchronizes the MultiMesh instance count.
4. From Observation 4: Because GDScript's `Object.get(name)` queries object properties and not private underscore variables, `scientific_probe_tool.gd` fails to read particle positions from both `NBodyGravityModule` and `MolecularDynamicsModule`. Using explicit getter methods (`get_positions()`, `get_velocities()`) ensures reliable sampling across all modules.
5. From Observation 5: In `QuantumWavePacketModule`, the potential grid must be recomputed whenever barrier parameters change. Exposing public setter methods (`set_barrier_height(v0: float)`, `set_barrier_width(width: float)`, `set_potential_type(type: int)`) and calling `_rebuild_potential()` connects `QuantumBenchTool` to the simulation engine.
6. From Observation 6 & 7: Designing `res://tests/test_physics_interaction_suite.gd` without using built-in `assert()` and covering 4 tiers (Raycasting & Gizmos, Interaction Manager, 5 Tools & Modules, E2E Sandbox) satisfies Acceptance Criteria R3 while integrating seamlessly with `test_runner.gd`.

---

## 3. Caveats

1. **Backwards Compatibility in Registry**: Removing `cube_spawner_tool` from `module_registry_client.gd` completely would break `test_fuzzy_registry.gd` and `test_module_library_suite.gd`. The implementer should retain `cube_spawner_tool` as a legacy entry while adding official physics templates, or update those test files in the same changeset.
2. **SpaceViewport Headless Camera**: In `--headless` mode, `Camera3D` calculates raycasts based on its projection matrix and transform. In unit tests, a dummy `Camera3D` with an assigned `global_transform` and `fov` should be added to the scene tree to ensure `project_ray_origin` and `project_ray_normal` calculate non-degenerate rays.
3. **MultiMesh Headless Draw**: MultiMesh transforms update on CPU arrays and do not require active GPU rendering to be verified in headless mode.

---

## 4. Conclusion

The core physics engines and integrators in UniCORE are mathematically sound and robust. The interactive layer (tools, raycasting, velocity gizmo, interaction manager) is cleanly structured, but currently severed from the underlying physics modules by a small set of API method mismatches (`publish` vs `emit`, missing `spawn_body`, missing `inject_particles`, and underscore property queries in the probe).

Once these 5 targeted API connections are completed, the complete interactive physics sandbox will operate smoothly across all 5 scientific domains.

---

## 5. Remaining Work (For Implementer Agent)

1. **Fix `res://core/event_bus.gd`**:
   - Add `publish(event_name: String, payload: Dictionary = {}) -> void: emit(event_name, payload)`.
2. **Fix `res://modules/physics/n_body_gravity_module.gd`**:
   - Add `spawn_body(pos: Vector3, vel: Vector3, mass: float, body_type: String = "planet") -> void`.
   - Add raycast entity selection helper `find_body_near_ray(ray_origin: Vector3, ray_dir: Vector3, max_dist: float) -> Dictionary`.
3. **Fix `res://modules/physics/molecular_dynamics_module.gd`**:
   - Add `inject_particles(pos: Vector3, count: int, temp: float) -> void`.
   - Add `reset_to_maxwell_boltzmann() -> void`.
4. **Fix `res://modules/physics/quantum_wavepacket_module.gd`**:
   - Add `set_potential_type(type_id: int) -> void`.
   - Add `set_barrier_height(v0: float) -> void`.
   - Add `set_barrier_width(width: float) -> void`.
   - Add `cycle_potential_type() -> void`.
   - Add `toggle_dimension() -> void`.
5. **Fix `res://modules/physics/tools/scientific_probe_tool.gd`**:
   - Change `.get("positions")` and `.get("velocities")` to use `.get_positions()` and `.get_velocities()`.
   - Change `.get("softening_length")` to `.get("softening")`.
6. **Refactor `res://core/space_manager.gd`**:
   - Ensure `TEMPLATE_PHYSICS_LAB` is the primary template mounting `n_body_gravity_module` and `molecular_dynamics_module`.
7. **Implement `res://tests/test_physics_interaction_suite.gd`**:
   - Implement 4-tier test suite verifying `ScreenRaycaster`, `VelocityVectorGizmo`, `KeplerTrajectoryPreview`, `PhysicsInteractionManager`, and all 5 scientific tools.
8. **Verify with `--check-only`**:
   - Run `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only` to ensure exit code 0.

---

## 6. Verification Method

1. **Check Analysis Report**:
   - Read `c:\dev\UniCORE\.agents\teamwork\explorer_survey_3\analysis.md`.
2. **Static Check Command**:
   - `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`
3. **Headless Interaction Suite Execution**:
   - Once implemented: `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_interaction_suite.gd`
4. **Invalidation Conditions**:
   - If `_event_bus.publish` is called without alias in `event_bus.gd` $\to$ crash.
   - If `add_body` is called with Vector3 as arg 1 $\to$ GDScript type mismatch.
   - If `assert()` is used in test suites $\to$ process hang in headless mode.
