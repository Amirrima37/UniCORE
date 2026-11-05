# Soft Handoff Report: Explorer Survey 1 (Specification & Interface Miner)

**Author**: Explorer Survey 1  
**Date**: 2026-10-28  
**Parent Agent**: `ac022d96-cb0f-4487-9656-dfce4b989f50`  
**Deliverable**: Comprehensive Analysis of Physics Interaction Engine & 5 Scientific Tools  
**Path**: `c:\dev\UniCORE\.agents\teamwork\explorer_survey_1\analysis.md`  

---

## 1. Observation

1. **Authoritative Specifications Inspected**:
   - `C:/Users/Amirrima37/.gemini/antigravity/brain/51a93ace-161d-4812-aeda-bc1b959a8496/ui_design_physics_interface_spec.md`:
     - Line 60: `_event_bus.publish("physics_time_command", ...)`
     - Line 103: `_event_bus.publish("physics_tool_selected", {"tool_id": tool_id})`
     - Line 132: listens to `"physics_entity_selected"`, publishes `"physics_parameter_changed"`
   - `C:/Users/Amirrima37/.gemini/antigravity/brain/51a93ace-161d-4812-aeda-bc1b959a8496/scientific_simulation_architecture_spec.md`:
     - Task 1 to 8 specifications: mathematical models for Velocity-Verlet, Lennard-Jones, 1PN Relativistic precession, Berendsen thermostat, Poisson decay, Schrödinger equation.

2. **Existing Core Codebase Findings**:
   - `res://core/event_bus.gd`:
     - Line 27: `func emit(event_name: String, payload: Dictionary = {}) -> void:`
     - `grep_search` confirmed zero occurrences of `func publish` across the repository.
   - `res://core/physics/interaction/velocity_vector_gizmo.gd`:
     - Lines 50-54: Returns early when `length < 0.001` and hides gizmo.
     - Lines 61-66: Swaps reference up vector to `Vector3.BACK` when `absf(dir.dot(Vector3.UP)) > 0.99`.
     - Lines 80-87: Interpolates Cyan $\to$ Amber $\to$ Crimson based on normalized speed ratio.
   - `res://core/physics/interaction/screen_raycaster.gd`:
     - Provides static helpers `cast_to_plane`, `cast_to_camera_facing_plane`, and `cast_to_depth_plane`.
   - `res://core/physics/interaction/kepler_trajectory_preview.gd`:
     - Line 55: Evaluates eccentricity vector $\vec{e} = (\vec{v} \times \vec{h})/\mu - \vec{r}/|\vec{r}|$.
     - Clears surfaces on degenerate radial plunge ($|\vec{h}| < 10^{-4}$).
   - `res://core/physics/interaction/physics_interaction_manager.gd`:
     - Contains initial draft of camera-to-world raycasting and mouse drag gestures, but invokes `_event_bus.publish(...)` directly.
   - `res://modules/physics/n_body_gravity_module.gd`:
     - Line 628: `func add_body(p_name: String, pos: Vector3, vel: Vector3, mass: float, radius: float = 0.2, col: Color = Color.WHITE) -> void:`
   - `res://modules/physics/tools/celestial_spawner_tool.gd`:
     - Line 53: Calls `_gravity_module.add_body(position, velocity, mass)` with wrong parameter order (Vector3 passed to String argument).
   - `res://modules/physics/tools/particle_injector_tool.gd`:
     - Line 52: Calls `_md_module.inject_particles(pos, count, temp)`, but `res://modules/physics/molecular_dynamics_module.gd` does not have an `inject_particles` method.
   - `res://modules/physics/tools/`:
     - Only `celestial_spawner_tool.gd` and `particle_injector_tool.gd` exist. `nuclear_lab_tool.gd`, `quantum_bench_tool.gd`, and `scientific_probe_tool.gd` are not yet created.

3. **Compiler & Check-Only Status**:
   - Executing `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only` exited with code 0 (zero syntax errors in current repo).

---

## 2. Logic Chain

1. **Interface Contract Conflict (EventBus)**:
   - Because `event_bus.gd` defines `emit()` and lacks `publish()`, any code calling `_event_bus.publish()` (such as `physics_interaction_manager.gd`, `physics_time_bar.gd`, `celestial_spawner_tool.gd`, and `particle_injector_tool.gd`) will fail at runtime with a missing method error.
   - Resolution: Adding `func publish(event_name: String, payload: Dictionary = {}) -> void: emit(event_name, payload)` to `event_bus.gd` cleanly resolves this without breaking existing callers.

2. **Type Safety & Runtime Error (CelestialSpawnerTool)**:
   - In GDScript 2.0 with static typing, `add_body` in `NBodyGravityModule` expects `p_name: String` as argument 1, `pos: Vector3` as argument 2, and `vel: Vector3` as argument 3.
   - Passing `position` (Vector3) to argument 1 violates static type checking and throws an argument type mismatch error.
   - Resolution: `CelestialSpawnerTool` must generate a string identifier (e.g. `"Body_%d"` or `"Planet_%d"`) as argument 1.

3. **Functional Disconnection (ParticleInjectorTool)**:
   - `ParticleInjectorTool` delegates particle spawning to `_md_module.inject_particles(...)`. Because `MolecularDynamicsModule` does not implement `inject_particles(...)`, clicking the tool fails silently without injecting gas.
   - Resolution: `MolecularDynamicsModule` must expose `inject_particles(center_pos: Vector3, count: int, temp: float, stream_vel: Vector3 = Vector3.ZERO)` that appends to contiguous packed arrays and resizes MultiMesh.

4. **Completeness of Tool Suite**:
   - The user request requires 5 scientific tools: CelestialSpawnerTool, ParticleInjectorTool, NuclearLabTool, QuantumBenchTool, ScientificProbeTool.
   - NuclearLabTool, QuantumBenchTool, and ScientificProbeTool need to be implemented according to the specifications documented in `analysis.md`.

---

## 3. Caveats

1. **Rendering Performance of Large Dynamic Injections**:
   - In Godot 4.0, dynamically resizing `MultiMesh.instance_count` every frame or on rapid drag can trigger GPU buffer reallocations. Preallocating particle buffers or batching injections is recommended.
2. **Headless Limitations**:
   - Headless Godot runs with mock/dummy DisplayServer (`--headless`). Raycasting math using `Camera3D.project_ray_origin` and `project_ray_normal` works mathematically, but viewport dimensions must be manually set or assumed in headless unit tests (e.g., standard viewport size 1280x720).

---

## 4. Conclusion

All requirements, mathematical formulations, data structures, signal schemas, and edge-case behavior for `VelocityVectorGizmo`, `PhysicsInteractionManager`, and the 5 Interactive Scientific Physics Tools are fully discovered, analyzed, and documented in `c:\dev\UniCORE\.agents\teamwork\explorer_survey_1\analysis.md`.

Critical fixes have been formulated for:
- EventBus `publish` vs `emit` alias.
- `CelestialSpawnerTool` argument order fix.
- `MolecularDynamicsModule` dynamic `inject_particles` addition.
- Implementation templates for `NuclearLabTool`, `QuantumBenchTool`, and `ScientificProbeTool`.

---

## 5. Verification Method

To independently verify the discoveries:
1. **Check Script Syntax**:
   ```powershell
   & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
   ```
2. **Inspect Files**:
   - Check `res://core/event_bus.gd` line 27 for `func emit`.
   - Check `res://modules/physics/n_body_gravity_module.gd` line 628 for `add_body` signature.
   - Check `res://modules/physics/molecular_dynamics_module.gd` for absence of `inject_particles`.
3. **Inspect Detailed Survey Report**:
   - View `c:\dev\UniCORE\.agents\teamwork\explorer_survey_1\analysis.md`.

---

## 6. Remaining Work (Implementation Phase)

1. Core Dev Agent:
   - Add `publish()` alias to `res://core/event_bus.gd`.
   - Add `inject_particles(...)` to `res://modules/physics/molecular_dynamics_module.gd`.
   - Implement `res://modules/physics/tools/nuclear_lab_tool.gd`.
   - Implement `res://modules/physics/tools/quantum_bench_tool.gd`.
   - Implement `res://modules/physics/tools/scientific_probe_tool.gd`.
   - Update `celestial_spawner_tool.gd` and `physics_interaction_manager.gd` with verified parameter order and event topics.
2. Testing Agent:
   - Create and run `res://tests/test_physics_interaction_suite.gd`.
