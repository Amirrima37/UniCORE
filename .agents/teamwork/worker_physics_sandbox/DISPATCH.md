# DISPATCH: Worker (Core Implementer) - Interactive Physics Sandbox & Toolset

## Mission
Implement all required fixes, connections, and verifications for the Interactive Scientific Physics Sandbox & Toolset in UniCORE (Godot 4.0.stable).

## Mandatory Inputs to Read
1. `c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md` (Read first!)
2. `c:\dev\UniCORE\.agents\teamwork\orchestrator_2\PROJECT.md`
3. Explorer Reports:
   - `c:\dev\UniCORE\.agents\teamwork\explorer_survey_1\handoff.md` and `analysis.md`
   - `c:\dev\UniCORE\.agents\teamwork\explorer_survey_2\handoff.md` and `analysis.md`
   - `c:\dev\UniCORE\.agents\teamwork\explorer_survey_3\handoff.md` and `analysis.md`

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Technical Work Checklist
1. `res://core/event_bus.gd`:
   - Add `func publish(event_name: String, payload: Dictionary = {}) -> void: emit(event_name, payload)`
2. `res://core/space_manager.gd`:
   - Refactor `TEMPLATE_TOOL_PLAYGROUND` into `TEMPLATE_PHYSICS_LAB` (mounting `builtin_avatar_locomotion`, `n_body_gravity_module`, `molecular_dynamics_module`).
   - Fix lines 560, 952-956, 1016 to recognize `res://modules/physics/` and `res://modules/physics/tools/` as built-in and resolvable on disk, removing hardcoded `cube_spawner_tool`.
3. `res://core/module_library.gd`:
   - In `scan_library()` / `_scan_directory()`, add `res://modules/physics` and `res://modules/physics/tools`.
   - Update `direct_paths` in `has_module()` and `get_module_source()` for physics modules.
4. `res://core/module_registry_client.gd`:
   - Update verified templates to include official physics simulation templates (`n_body_gravity`, `molecular_dynamics`, `nuclear_decay`, `quantum_wavepacket`, `celestial_spawner_tool`, `particle_injector_tool`). Retain backward-compatible mappings if needed by legacy tests.
5. Physics Module Bridges:
   - `res://modules/physics/n_body_gravity_module.gd`:
     - Implement `func spawn_body(pos: Vector3, vel: Vector3, mass: float, body_type: String = "planet") -> void`
     - Implement `func find_body_near_ray(ray_origin: Vector3, ray_dir: Vector3, max_dist: float = 50.0) -> Dictionary`
   - `res://modules/physics/molecular_dynamics_module.gd`:
     - Implement `func inject_particles(pos: Vector3, count: int, temp: float, stream_vel: Vector3 = Vector3.ZERO) -> void`
     - Implement `func reset_to_maxwell_boltzmann() -> void`
   - `res://modules/physics/quantum_wavepacket_module.gd`:
     - Implement public methods: `set_potential_type(type_id: int) -> void`, `set_barrier_height(v0: float) -> void`, `set_barrier_width(width: float) -> void`, `cycle_potential_type() -> void`, `toggle_dimension() -> void`.
6. Interactive Tools & Interaction Layer:
   - `res://modules/physics/tools/celestial_spawner_tool.gd`:
     - Ensure calls to `_gravity_module.spawn_body` or `_gravity_module.add_body` pass correct arguments.
   - `res://modules/physics/tools/scientific_probe_tool.gd`:
     - Fix `.get("positions")` -> `.get_positions()`, `.get("velocities")` -> `.get_velocities()`, `.get("softening_length")` -> `.softening`.
   - `res://core/physics/interaction/velocity_vector_gizmo.gd`:
     - Verify procedural meshes, dynamic length, orientation alignment without NaN on zero length, color coding ramp.
   - `res://core/physics/interaction/physics_interaction_manager.gd`:
     - Verify raycasting on focal planes, drag gestures, entity selection, EventBus integration.
7. Verification & Tests:
   - Update dependent tests if affected (`test_space_management_suite.gd`, `test_regex_all.gd`, etc.).
   - Execute:
     `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`
     (Must exit with 0)
   - Execute:
     `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_interaction_suite.gd`
     (Must exit with 0, all tests PASS)

Write your full report to `c:\dev\UniCORE\.agents\teamwork\worker_physics_sandbox\handoff.md`.
