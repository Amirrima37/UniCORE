# Project: Interactive Scientific Physics Sandbox & Toolset in Godot 4.0.stable

## Architecture
- **Event Bus Layer**: `res://core/event_bus.gd` with both `emit()` and `publish()` methods.
- **Space & Module Management**:
  - `res://core/space_manager.gd`: Surface-less Cartesian vacuum laboratory. Defines `TEMPLATE_PHYSICS_LAB` mounting `n_body_gravity_module` and `molecular_dynamics_module`. Recognizes `res://modules/physics/` and `res://modules/physics/tools/`.
  - `res://core/module_library.gd`: Discovers built-in and physics modules/tools in `res://modules/physics/` and `res://modules/physics/tools/`.
  - `res://core/module_registry_client.gd`: Official physics templates replacing obsolete toy templates.
- **3D Interaction Engine**:
  - `res://core/physics/interaction/velocity_vector_gizmo.gd`: 3D procedural cylinder/cone mesh, dynamic length, safe orientation alignment (no NaN on zero length), relativistic/kinetic color gradient.
  - `res://core/physics/interaction/screen_raycaster.gd`: Camera-to-world raycasting on arbitrary focal planes (camera-facing, depth plane, normal planes).
  - `res://core/physics/interaction/kepler_trajectory_preview.gd`: Conic section orbit prediction for celestial bodies.
  - `res://core/physics/interaction/physics_interaction_manager.gd`: Input router, click-and-drag gesture recognizer, entity selection, and EventBus dispatcher.
- **Physics Engine Modules**:
  - `res://modules/physics/n_body_gravity_module.gd`: N-body gravity with `spawn_body()` and raycast entity queries.
  - `res://modules/physics/molecular_dynamics_module.gd`: Lennard-Jones gas with `inject_particles()` and `reset_to_maxwell_boltzmann()`.
  - `res://modules/physics/nuclear_decay_module.gd`: Radioactive isotopes, Poisson decays, neutron collisions.
  - `res://modules/physics/quantum_wavepacket_module.gd`: Schrödinger equation with public potential configuration setters.
- **Suite of 5 Interactive Scientific Physics Tools** (`res://modules/physics/tools/`):
  1. `celestial_spawner_tool.gd`: Star, planet, black hole placement with velocity dragging and Kepler trajectory cone.
  2. `particle_injector_tool.gd`: Gas injection with Maxwell-Boltzmann sampling, container resizing, laser heating/cooling.
  3. `nuclear_lab_tool.gd`: U-235/Ra-226 assembly placement, neutron gun firing, control rod depth adjustment.
  4. `quantum_bench_tool.gd`: Potential barrier/double-slit placement and wavepacket excitation.
  5. `scientific_probe_tool.gd`: 3D sensor placement sampling local gravitational, force, temperature, and radiation fields.
- **Verification Harness**:
  - `res://tests/test_physics_interaction_suite.gd`: 4-tier headless test suite adhering to Godot 4 headless conventions.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Obsolete Module Cleanup | Safely remove memory templates of 5 obsolete toy modules | M1 | ORIGINAL_REQUEST §R1 |
| 2 | SpaceManager Physics Lab | Refactor TEMPLATE_TOOL_PLAYGROUND to TEMPLATE_PHYSICS_LAB and recognize physics paths | M1 | ORIGINAL_REQUEST §R1 |
| 3 | ModuleRegistry & Library Scan | Scan physics directories and register official physics templates | M1 | ORIGINAL_REQUEST §R1 |
| 4 | EventBus publish alias | Provide publish() alias on EventBus to support UI and tool conventions | M1 | Survey Explorers 1-3 |
| 5 | Test Suite Synchronization | Update legacy tests (space_management, module_library, fuzzy_registry, regex_all) | M1 | Survey Explorer 2 |
| 6 | VelocityVectorGizmo 3D Mesh | Procedural shaft & cone mesh, dynamic length proportional to \|v_0\| | M2 | ORIGINAL_REQUEST §R2 |
| 7 | VelocityVectorGizmo Singularity Safety | Alignment without NaN on \|v_0\| == 0 and near-vertical vectors | M2 | ORIGINAL_REQUEST §R2, Spec |
| 8 | VelocityVectorGizmo Energy Color Ramp | Color gradient (Cyan -> Amber -> Crimson) mapping velocity magnitude | M2 | ORIGINAL_REQUEST §R2, Spec |
| 9 | Camera-to-World Raycasting | Focal plane intersections at arbitrary camera angles via ScreenRaycaster | M2 | ORIGINAL_REQUEST §R2 |
| 10 | Click-and-Drag Drag Gestures | Click sets position, drag vector determines initial impulse v_0 | M2 | ORIGINAL_REQUEST §R2 |
| 11 | Entity Selection & Ray Picking | Raycast against physical entities and publish physics_entity_selected | M2 | ORIGINAL_REQUEST §R2 |
| 12 | NBodyGravityModule API Bridge | Expose spawn_body() and raycast entity query | M3 | Survey Explorers 1 & 3 |
| 13 | MolecularDynamicsModule API Bridge | Expose inject_particles() and reset_to_maxwell_boltzmann() | M3 | Survey Explorers 1 & 3 |
| 14 | QuantumWavePacketModule API Bridge | Expose public setters for potential barrier height, width, and type | M3 | Survey Explorers 1 & 3 |
| 15 | CelestialSpawnerTool | Interactive celestial body spawner with velocity drag and Kepler preview | M3 | ORIGINAL_REQUEST §R3 |
| 16 | ParticleInjectorTool | Interactive gas injector with Maxwell-Boltzmann velocities and laser control | M3 | ORIGINAL_REQUEST §R3 |
| 17 | NuclearLabTool | Fuel assembly placement, neutron gun, and control rod depth | M3 | ORIGINAL_REQUEST §R3 |
| 18 | QuantumBenchTool | Barrier/slit placement, wavepacket emission, parameter tuning | M3 | ORIGINAL_REQUEST §R3 |
| 19 | ScientificProbeTool | Multi-field 3D measurement sensor reading gravity, temperature, and radiation | M3 | ORIGINAL_REQUEST §R3 |
| 20 | Static GDScript 2.0 Compliance | Zero untyped Variant variables, pass --check-only with exit code 0 | M4 | ORIGINAL_REQUEST §Acceptance |
| 21 | Automated Headless Test Suite | test_physics_interaction_suite.gd verifying gizmos, raycasting, selection, tools | M4 | ORIGINAL_REQUEST §Acceptance |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Obsolete Module Cleanup & Space Refactoring | EventBus alias, SpaceManager physics paths & templates, ModuleLibrary scanning, registry templates, test suite synchronization | none | PLANNED |
| 2 | M2: 3D Interaction Engine & Velocity Vector Gizmo | VelocityVectorGizmo (singularity safe, procedural mesh, color ramp), ScreenRaycaster, PhysicsInteractionManager (gestures, selection, events) | M1 | PLANNED |
| 3 | M3: Suite of 5 Interactive Scientific Physics Tools | Physics module bridges (NBody, MD, Quantum), 5 interactive tools (Celestial, Particle, Nuclear, Quantum, Probe) | M1, M2 | PLANNED |
| 4 | M4: Headless Physics Interaction Test Suite & E2E Verification | test_physics_interaction_suite.gd (Tiers 1-4), check-only syntax audit, test runner verification | M1, M2, M3 | PLANNED |

## Interface Contracts
### EventBus
- `func publish(event_name: String, payload: Dictionary = {}) -> void`: Alias for `emit(event_name, payload)`.
- Key events:
  - `physics_entity_selected`: `{"module_id": String, "entity": Dictionary}`
  - `physics_tool_selected`: `{"tool_id": String}`
  - `physics_parameter_changed`: `{"module_id": String, "param": String, "value": Variant}`
  - `physics_entity_spawned`: `{"module_id": String, "entity": Dictionary}`

### SpaceManager ↔ Modules
- SpaceManager recognizes `res://modules/physics/` and `res://modules/physics/tools/` as built-in / loadable.
- Template `TEMPLATE_PHYSICS_LAB = "physics_lab"` mounts `builtin_avatar_locomotion`, `n_body_gravity_module`, `molecular_dynamics_module`.

### Physics Modules ↔ Tools
- `NBodyGravityModule`:
  - `spawn_body(pos: Vector3, vel: Vector3, mass: float, body_type: String = "planet") -> void`
  - `find_body_near_ray(ray_origin: Vector3, ray_dir: Vector3, max_dist: float) -> Dictionary`
  - `get_positions() -> PackedVector3Array`, `get_velocities() -> PackedVector3Array`
- `MolecularDynamicsModule`:
  - `inject_particles(pos: Vector3, count: int, temp: float, stream_vel: Vector3 = Vector3.ZERO) -> void`
  - `reset_to_maxwell_boltzmann() -> void`
  - `get_positions() -> PackedVector3Array`, `get_velocities() -> PackedVector3Array`
- `QuantumWavePacketModule`:
  - `set_potential_type(type_id: int) -> void`
  - `set_barrier_height(v0: float) -> void`
  - `set_barrier_width(width: float) -> void`

## Code Layout
- `res://core/event_bus.gd`
- `res://core/space_manager.gd`
- `res://core/module_library.gd`
- `res://core/module_registry_client.gd`
- `res://core/physics/interaction/velocity_vector_gizmo.gd`
- `res://core/physics/interaction/screen_raycaster.gd`
- `res://core/physics/interaction/kepler_trajectory_preview.gd`
- `res://core/physics/interaction/physics_interaction_manager.gd`
- `res://modules/physics/n_body_gravity_module.gd`
- `res://modules/physics/molecular_dynamics_module.gd`
- `res://modules/physics/quantum_wavepacket_module.gd`
- `res://modules/physics/tools/celestial_spawner_tool.gd`
- `res://modules/physics/tools/particle_injector_tool.gd`
- `res://modules/physics/tools/nuclear_lab_tool.gd`
- `res://modules/physics/tools/quantum_bench_tool.gd`
- `res://modules/physics/tools/scientific_probe_tool.gd`
- `res://tests/test_physics_interaction_suite.gd`
- `res://tests/test_space_management_suite.gd`
- `res://tests/test_module_library_suite.gd`
- `res://tests/test_fuzzy_registry.gd`
- `res://tests/test_regex_all.gd`
