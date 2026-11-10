# UniCORE Physics Engine Architecture & Interaction Test Survey

**Document**: `analysis.md`  
**Author**: Explorer Survey 3 (Physics Engine Architecture & Test Inspector)  
**Date**: 2026-10-28  
**Scope**: `res://core/physics/`, `res://modules/physics/`, `res://modules/physics/tools/`, `res://core/space_viewport.gd`, `res://core/event_bus.gd`, `res://tests/`

---

## 1. Executive Summary

This investigation examines the complete scientific physics simulation architecture in UniCORE, the interactive toolset and 3D raycasting/gizmo pipeline, and the test harness infrastructure. 

### Key Findings:
1. **Physical Engine Subsystems are Robust**: Symplectic integrators (`VerletIntegrator`, `RK4Integrator`), `BarnesHutOctree` ($O(N \log N)$), `SpatialHashGrid` ($O(N)$), `SimulationTimeController`, and `ConservationSentry` are fully functional and pass the 1066-line `test_physics_engine_suite.gd`.
2. **Critical Method Mismatch (`EventBus.publish` vs `EventBus.emit`)**: All new interaction modules (`physics_interaction_manager.gd`, `physics_time_bar.gd`, and all 5 scientific tools) call `_event_bus.publish(...)`. However, `res://core/event_bus.gd` defines `emit(...)` and contains **no** `publish` method. Calling `publish` will cause a fatal runtime crash. A canonical alias `func publish(event_name: String, payload: Dictionary = {}) -> void: emit(event_name, payload)` must be added to `event_bus.gd`.
3. **Module API Discrepancies**:
   - `CelestialSpawnerTool` calls `_gravity_module.spawn_body(pos, vel, mass, body_type)` and falls back to `_gravity_module.add_body(pos, vel, mass)`. But `NBodyGravityModule.add_body` expects `p_name: String` as its first parameter (`add_body(p_name, pos, vel, mass, ...)`). Calling it with `Vector3` as the first argument results in a GDScript type mismatch error.
   - `ParticleInjectorTool` calls `_md_module.inject_particles(pos, count, temp)` and `reset_to_maxwell_boltzmann()`, but `MolecularDynamicsModule` does not implement either method (silently failing).
   - `QuantumBenchTool` calls `set_potential_type`, `set_barrier_height`, `set_barrier_width`, `cycle_potential_type`, and `toggle_dimension`, but `QuantumWavePacketModule` does not expose these methods publicly.
   - `ScientificProbeTool` queries `_gravity_module.get("positions")`, `get("masses")`, and `_md_module.get("positions")`, which return `null` because the internal member variables use leading underscores (`_positions`, `_masses`).
4. **Obsolete Modules Status**: The toy modules (`cube_spawner_tool.gd`, `particle_system.gd`, `physics_gravity.gd`, `llm_turret_mod.gd`, `quartz_cached_mod.gd`) are already deleted from `res://modules/`. However, `ModuleRegistryClient.VERIFIED_MODULE_TEMPLATES` still contains inline code templates for `cube_spawner`, `physics_gravity`, and `particle_system`, which are referenced by existing tests (`test_fuzzy_registry.gd`, `test_module_library_suite.gd`).
5. **Test Architecture Defined**: A comprehensive 4-tier automated headless test suite (`res://tests/test_physics_interaction_suite.gd`) has been designed to verify gizmo singularity avoidance, 3D raycasting onto camera-facing focal planes, drag gestures, entity selection, and all 5 scientific tools without using `assert()`.

---

## 2. Core Physics Architecture & Invariant Subsystems

All core physics files reside in `res://core/physics/`:

| Component | Path | Role & Invariants |
|---|---|---|
| `SimulationTimeController` | `res://core/physics/simulation_time_controller.gd` | Central clock node. Fixed $\Delta t$ distribution (`fixed_delta = 0.01`), time scaling ($0.001\times$ to $1000\times$), pause/resume toggle, and `step_once()` execution with substepping limiter. |
| `PhysicalIntegrator` | `res://core/physics/physical_integrator.gd` | Base RefCounted class defining `integrate(positions, velocities, masses, force_callable, dt)`. |
| `VerletIntegrator` | `res://core/physics/verlet_integrator.gd` | Symplectic Velocity-Verlet solver. Conserves phase-space volume and Hamiltonian energy ($dE/dt \approx 0$). Supports velocity-dependent acceleration tensors. |
| `RK4Integrator` | `res://core/physics/rk4_integrator.gd` | 4th-order Runge-Kutta solver for non-conservative or highly non-linear dissipative systems. |
| `ConservationSentry` | `res://core/physics/conservation_sentry.gd` | Invariant watchdog calculating total energy $E = E_k + E_p$, linear momentum $\vec{P} = \sum m_i \vec{v}_i$, angular momentum $\vec{L} = \sum \vec{r}_i \times (m_i \vec{v}_i)$, and kinetic temperature $T$. Emits warnings if drift exceeds tolerances. |
| `SpatialHashGrid` | `res://core/physics/spatial_hash_grid.gd` | 3D spatial partitioning grid with prime hashing $((x \cdot 73856093) \oplus (y \cdot 19349663) \oplus (z \cdot 83492791))$. Provides $O(N)$ neighbor searches within cutoff radius $r_c$. |
| `BarnesHutOctree` | `res://core/physics/barnes_hut_octree.gd` | Hierarchical 3D octree accelerating $1/r^2$ long-range gravitational interactions from $O(N^2)$ to $O(N \log N)$ using multipole expansion with opening criterion $\theta_{crit} \le 0.5$. |
| `UnitConverter` | `res://core/physics/unit_converter.gd` | Scales between SI units, reduced Lennard-Jones units ($\sigma, \epsilon, m$), Planck units, and Astronomical units to eliminate IEEE-754 float precision loss. |

---

## 3. Physics Simulation Modules & Data Storage

All physics simulation modules inherit from `UniCoreModule` (`res://core/unicore_module.gd`) and run within `world_root`.

### 3.1 NBodyGravityModule (`res://modules/physics/n_body_gravity_module.gd`)
- **Data Buffers**:
  - `_positions: PackedVector3Array`
  - `_velocities: PackedVector3Array`
  - `_masses: PackedFloat32Array`
  - `_radii: PackedFloat32Array`
  - `_body_colors: PackedColorArray`
  - `_body_names: Array[String]`
- **Rendering**:
  - `MultiMeshInstance3D` (`_multimesh_instance`) with single draw call. Sphere mesh with `relativistic_mesh.gdshader` displaying Lorentz contraction and relativistic Doppler beaming.
  - Custom Data per instance: `Color(vel.x, vel.y, vel.z, gamma)`.
  - Orbit Trails: `ImmediateMesh` (`_trail_mesh`) rendering fading line strips for up to 32 tracked bodies.
- **Current APIs**:
  - `func add_body(p_name: String, pos: Vector3, vel: Vector3, mass: float, radius: float = 0.2, col: Color = Color.WHITE) -> void`
  - `func clear_particles() -> void`
  - Getters: `get_positions()`, `get_velocities()`, `get_masses()`, `get_radii()`, `get_particle_count()`, `get_octree()`, `get_sentry()`.
- **API Gap for Interaction**:
  - `CelestialSpawnerTool` needs `spawn_body(pos: Vector3, vel: Vector3, mass: float, body_type: String = "planet") -> void`. Currently missing.
  - No raycast entity selection: A helper `find_body_near_ray(ray_origin: Vector3, ray_dir: Vector3, max_dist: float) -> int` is needed to support clicking to select a celestial body.

### 3.2 MolecularDynamicsModule (`res://modules/physics/molecular_dynamics_module.gd`)
- **Data Buffers**:
  - `_positions: PackedVector3Array`
  - `_velocities: PackedVector3Array`
  - `_masses: PackedFloat32Array`
  - `_forces: PackedVector3Array`
- **Acceleration & Thermostat**:
  - `SpatialHashGrid` with cell size equal to cutoff radius $r_c = 2.5\sigma$.
  - Berendsen thermostat velocity scaling factor $\lambda = \sqrt{1 + \frac{\Delta t}{\tau} (T_{target}/T_{inst} - 1)}$.
  - Reflective cubic boundaries with coefficient of restitution $e$.
- **Rendering**:
  - `MultiMeshInstance3D` with `particle_field_glow.gdshader`. Vertex colors interpolate cold-blue to hot-red based on kinetic energy.
  - Wireframe boundary box rendered via `ImmediateMesh`.
- **Current APIs**:
  - `func heat_up(delta_temp: float = 0.2) -> void`
  - `func cool_down(delta_temp: float = 0.2) -> void`
  - `func compress_container(scale_factor: float = 0.95) -> void`
  - `func compute_instantaneous_temperature() -> float`
  - `func compute_velocity_distribution(num_bins: int, max_speed: float) -> Dictionary`
  - `func get_positions() -> PackedVector3Array`
  - `func get_velocities() -> PackedVector3Array`
- **API Gap for Interaction**:
  - Missing `inject_particles(pos: Vector3, count: int, temp: float) -> void` to dynamically inject gas molecules into the active ensemble.
  - Missing `reset_to_maxwell_boltzmann() -> void`.

### 3.3 NuclearDecayModule (`res://modules/physics/nuclear_decay_module.gd`)
- **Data Buffers**:
  - Nuclei: `nuclei_positions`, `nuclei_velocities`, `nuclei_masses`, `nuclei_isotope_keys`, `nuclei_half_lives`, `nuclei_channels`, `nuclei_active` (PackedByteArray).
  - Radiation: `rad_positions`, `rad_velocities`, `rad_masses`, `rad_types`, `rad_lifetimes`, `rad_active` (PackedByteArray).
- **Physical Engine**:
  - Poisson radioactive decay: $P_{decay} = 1 - e^{-\lambda \Delta t}$.
  - Ejected $\alpha, \beta, \gamma$ particles conserve relativistic 4-momentum ($Q = \Delta m \cdot c^2$).
  - Spatial collision detection between neutrons and fissile nuclei ($U-235$) inducing fission with 2 fragments + 2-3 prompt neutrons.
  - Control rod neutron absorption parameterized by `control_rod_depth \in [0.0, 1.0]`.
- **APIs**:
  - `func spawn_nucleus(pos: Vector3, vel: Vector3, isotope_symbol: String) -> int`
  - `func spawn_radiation(pos: Vector3, vel: Vector3, mass: float, rad_type: int, lifetime: float) -> int`
  - `func inject_trigger_neutron(pos: Vector3, vel: Vector3) -> void`
  - `func setup_reactor_core(u235_count: int, radius: float) -> void`
  - `func setup_isotope_sample(isotope_symbol: String, count: int, radius: float) -> void`
  - Property `control_rod_depth: float`
- **Status**: Perfectly matched with `NuclearLabTool`.

### 3.4 QuantumWavePacketModule (`res://modules/physics/quantum_wavepacket_module.gd`)
- **Data Buffers**:
  - 1D Wavefunction: `psi_real_1d`, `psi_imag_1d`, `potential_1d`, `prob_density_1d` (all `PackedFloat32Array`).
  - 2D Wavefunction: `psi_real_2d`, `psi_imag_2d`, `potential_2d`, `prob_density_2d`.
- **Physical Engine**:
  - Discretized Split-Operator Cayley evolution preserving unitary norm $\int |\psi|^2 dx = 1.0$.
  - Potential types: Free Space, Rectangular Barrier, Harmonic Well, Step Potential, Double Slit.
  - Real-time quantum tunneling analysis: calculates analytical transmission $T \approx e^{-2\kappa d}$ vs empirical probability transmission.
- **Rendering**:
  - 1D: Continuous ribbon strip via `ImmediateMesh`.
  - 2D: Dynamic vertex displacement surface via `ArrayMesh`.
- **APIs & Gaps**:
  - Existing: `initialize_gaussian_wavepacket(x0, sigma, k0)`, `initialize_2d_gaussian(...)`, `reset_simulation()`.
  - Missing for `QuantumBenchTool`: Public methods `set_potential_type(type_id: int)`, `set_barrier_height(v0: float)`, `set_barrier_width(width: float)`, `cycle_potential_type()`, `toggle_dimension()`.

---

## 4. 3D Interaction Engine & Tools Architecture

### 4.1 ScreenRaycaster (`res://core/physics/interaction/screen_raycaster.gd`)
- Converts 2D screen mouse positions into 3D world intersection vectors without physical `CollisionObject3D` nodes:
  - `cast_to_plane(camera, screen_pos, plane_normal, plane_origin) -> Variant`: Intersects camera projection ray with arbitrary `Plane(normal, d)`. Returns `Vector3` or `null` if parallel.
  - `cast_to_camera_facing_plane(camera, screen_pos, anchor_pos) -> Variant`: Billboard plane whose normal is `camera.global_basis.z.normalized()`. Eliminates perspective warping during 3D velocity dragging.
  - `cast_to_depth_plane(camera, screen_pos, depth) -> Variant`: Projects onto a plane situated at fixed depth $D$ along camera forward vector `-camera.global_basis.z`.

### 4.2 VelocityVectorGizmo (`res://core/physics/interaction/velocity_vector_gizmo.gd`)
- Procedural 3D arrow composed of a `CylinderMesh` shaft and a conical `CylinderMesh` head (top_radius = 0.0).
- **Singularity Avoidance**: When `dir.dot(Vector3.UP) > 0.99`, selects `Vector3.BACK` as the reference up vector to construct orthogonal basis vectors without degenerate zero cross products.
- **Dynamic Energy Color Gradient**:
  - Speed ratio $s = |v| / v_{max}$.
  - $s < 0.5$: Cyan (`#00E5FF`) $\to$ Amber (`#FFB300`).
  - $s \ge 0.5$: Amber (`#FFB300`) $\to$ Crimson (`#FF1744`).
- When $|v| < 0.001$, hides itself and zeros state without division by zero.

### 4.3 KeplerTrajectoryPreview (`res://core/physics/interaction/kepler_trajectory_preview.gd`)
- Computes orbital elements from instantaneous state vectors $\vec{r}, \vec{v}$:
  - Specific angular momentum $\vec{h} = \vec{r} \times \vec{v}$.
  - Eccentricity vector $\vec{e} = \frac{\vec{v} \times \vec{h}}{\mu} - \frac{\vec{r}}{|\vec{r}|}$.
  - Semi-latus rectum $p = |\vec{h}|^2 / \mu$.
- If $e < 0.99$: Draws closed ellipse across $\theta \in [0, 2\pi]$ (Green).
- If $e \ge 0.99$: Clamps true anomaly to escape cone $\theta_{max} = \arccos(-1/e) - 0.1$ and draws hyperbolic trajectory (Orange/Red).
- Degenerate plunge ($|\vec{h}| < 10^{-4}$) or zero attractor ($\mu \le 0$) hides the line strip.

### 4.4 PhysicsInteractionManager (`res://core/physics/interaction/physics_interaction_manager.gd`)
- Dispatches user mouse gestures to the active scientific tool:
  - **Left Click Press**: Raycasts onto depth plane at `default_focal_depth = 12.0` to set `_drag_anchor`. Initializes gizmo.
  - **Mouse Motion**: Raycasts onto camera-facing plane through `_drag_anchor`, calculates initial impulse $\vec{v}_0 = (\vec{r}_{current} - \vec{r}_{anchor}) \cdot 2.0$, clamps to `max_drag_speed = 25.0`, updates gizmo and orbit preview.
  - **Left Click Release**: Dispatches `entity_spawned` signal and EventBus event `"physics_entity_spawned"` with module ID and parameters.
  - **Right Click**: Cancels active drag (`_cancel_drag()`).
  - **Tool Switching**: Listens to `"physics_tool_selected"` (`"gravity"`, `"thermodynamics"`, `"nuclear"`, `"quantum"`, `"sensor"`, `"select"`).
  - **Time Routing**: Listens to `"physics_time_command"` (`"set_paused"`, `"toggle_pause"`, `"step_once"`, `"set_time_scale"`).

### 4.5 Suite of 5 Scientific Physics Tools (`res://modules/physics/tools/`)
1. **CelestialSpawnerTool** (`celestial_spawner_tool.gd`):
   - Spawns stars ($M=1000$), planets ($M=10$), black holes ($M=10000$) with tangential velocity $\vec{v}_0$.
   - Hotkeys: `1` (Planet), `2` (Star), `3` (Black Hole).
2. **ParticleInjectorTool** (`particle_injector_tool.gd`):
   - Injects clusters of gas molecules into `MolecularDynamicsModule` with target temperature.
   - Hotkeys: `Up` (Heat gas), `Down` (Cool gas), `R` (Reset Maxwell distribution).
3. **NuclearLabTool** (`nuclear_lab_tool.gd`):
   - Places fuel assemblies ($U-235$, $Ra-226$), fires trigger neutrons, and adjusts absorber control rods.
   - Hotkeys: `Space` (Fire neutron), `Down` (Insert rods), `Up` (Withdraw rods), `1` (Select U-235), `2` (Select Ra-226), `R` (Reset assembly).
4. **QuantumBenchTool** (`quantum_bench_tool.gd`):
   - Excites Gaussian wavepackets ($k_0, \sigma$) and reconfigures potential barriers/slits.
   - Hotkeys: `R` (Reset wavepacket), `B` (Cycle barrier type), `Up` (Raise $V_0$), `Down` (Lower $V_0$), `M` (Toggle 1D/2D).
5. **ScientificProbeTool** (`scientific_probe_tool.gd`):
   - Deploys 3D measurement sensor nodes recording local gravitational acceleration $\vec{g}$, gas density $\rho$, temperature $T$, pressure $P$, radiation flux CPS, and quantum probability density $|\psi|^2$.
   - Hotkeys: `P` (Deploy probe), `C` (Clear probes).

---

## 5. SpaceViewport, SpaceManager & EventBus Integration

### 5.1 EventBus Discrepancy
`res://core/event_bus.gd` defines:
```gdscript
func emit(event_name: String, payload: Dictionary = {}) -> void:
    event_emitted.emit(event_name, payload)
    ...
```
All UI and interaction scripts call `_event_bus.publish(event_name, payload)`.
**Resolution**: Add an alias in `res://core/event_bus.gd`:
```gdscript
func publish(event_name: String, payload: Dictionary = {}) -> void:
    emit(event_name, payload)
```

### 5.2 SpaceViewport Mounting
In `res://core/space_viewport.gd`:
- `CanvasLayer` holds the UI components: `PhysicsTimeBar`, `PhysicsToolbox`, `PhysicsInspectorDrawer`, `ConservationHUD`.
- `PhysicsInteractionManager` should be mounted under `WorldRoot` or as a child of `SpaceViewport`, with its `setup(event_bus, camera, module_manager, time_controller, sentry)` method invoked during space initialization.

### 5.3 SpaceManager Template Refactoring
In `res://core/space_manager.gd`:
- Constant `TEMPLATE_PHYSICS_LAB: String = "physics_lab"` is defined.
- `_build_template_space_data` should mount:
  1. `builtin_avatar_locomotion`
  2. `n_body_gravity_module`
  3. `molecular_dynamics_module`
  4. Optionally `physics_interaction_manager` / scientific tools.
- Obsolete references: Line 1016 (`mod_id == "cube_spawner_tool"`) should be cleaned up.

### 5.4 Module Registry Backwards Compatibility
In `res://core/module_registry_client.gd`:
- `VERIFIED_MODULE_TEMPLATES` currently contains `cube_spawner`, `sphere_spawner`, `physics_gravity`, and `particle_system`.
- `test_fuzzy_registry.gd` explicitly tests searches for `"cube_spawner_tool"`, `"кубик"`, `"красный кубик"`, etc.
- **Risk Mitigation**: When replacing toy templates with official physics modules (`n_body_gravity`, `molecular_dynamics`, `nuclear_decay`, `quantum_wavepacket`, `scientific_probe`), ensure that either:
  a) `cube_spawner_tool` is preserved as a deprecated compatibility entry, OR
  b) `test_fuzzy_registry.gd` and `test_module_library_suite.gd` are updated simultaneously to search for the new physics templates.

---

## 6. Discrepancy & Fix Matrix

| Component | File & Line | Observed Problem | Required Fix |
|---|---|---|---|
| `EventBus` | `res://core/event_bus.gd:27` | Only `emit()` is defined; all tools/UI call `publish()`. Fatal runtime crash. | Add `func publish(event_name: String, payload: Dictionary = {}) -> void: emit(event_name, payload)`. |
| `NBodyGravityModule` | `res://modules/physics/n_body_gravity_module.gd:628` | Has `add_body(p_name: String, pos: Vector3, ...)`. Missing `spawn_body(pos, vel, mass, body_type)`. | Add `func spawn_body(pos: Vector3, vel: Vector3, mass: float, body_type: String = "planet") -> void` and `find_body_near_ray(...)`. |
| `MolecularDynamicsModule` | `res://modules/physics/molecular_dynamics_module.gd` | Missing `inject_particles(pos, count, temp)` and `reset_to_maxwell_boltzmann()`. | Implement `inject_particles` appending to buffers and updating MultiMesh, and `reset_to_maxwell_boltzmann()`. |
| `QuantumWavePacketModule` | `res://modules/physics/quantum_wavepacket_module.gd` | Missing public methods `set_potential_type`, `set_barrier_height`, `set_barrier_width`, `cycle_potential_type`, `toggle_dimension`. | Implement these public setters, rebuilding potential and updating visuals. |
| `ScientificProbeTool` | `res://modules/physics/tools/scientific_probe_tool.gd:195-217` | Calls `_gravity_module.get("positions")` and `_md_module.get("positions")` (internal vars are `_positions`). Calls `softening_length` instead of `softening`. | Update probe tool to use `get_positions()`, `get_velocities()`, and fallback property checks. |
| `SpaceManager` | `res://core/space_manager.gd:24, 1016` | References deprecated `cube_spawner_tool` and `TEMPLATE_TOOL_PLAYGROUND`. | Clean up legacy checks, standardize on `TEMPLATE_PHYSICS_LAB`. |

---

## 7. Architecture for `test_physics_interaction_suite.gd`

The automated headless test suite `res://tests/test_physics_interaction_suite.gd` must execute via:
```powershell
& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_interaction_suite.gd
```

### Design Standards:
1. Extends `SceneTree`.
2. Custom assertion function: `assert_test(condition: bool, test_name: String, details: String = "")`.
3. **Zero built-in `assert()` calls**.
4. Strict static typing (`int`, `float`, `Vector3`, `PackedVector3Array`, `Dictionary`, `Callable`).
5. Primitives in lambdas captured via single-element arrays: `var captured := [false, 0.0]`.
6. Terminate with `quit(0)` on 100% success or `quit(1)` on any failure.

### 4-Tier Test Breakdown (35+ Comprehensive Test Cases):

```
res://tests/test_physics_interaction_suite.gd
├── TIER 1: Gizmo & Mathematical Raycasting Rigor (15 tests)
│   ├── ScreenRaycaster:
│   │   ├── T1.1: Null camera safety returns null
│   │   ├── T1.2: Ray parallel to plane returns null (singularity check)
│   │   ├── T1.3: Orthogonal raycast onto X-Z floor plane computes exact intersection
│   │   ├── T1.4: Oblique camera (45° pitch/yaw) computes correct 3D intersection
│   │   ├── T1.5: cast_to_camera_facing_plane returns anchor position on screen center ray
│   │   └── T1.6: cast_to_depth_plane calculates exact point along camera forward vector
│   ├── VelocityVectorGizmo:
│   │   ├── T1.7: Zero/near-zero vector (|v| < 0.001) hides gizmo without NaN
│   │   ├── T1.8: Collinear orientations (+Y, -Y, +Z, -Z, +X, -X) maintain orthogonal basis
│   │   ├── T1.9: Basis Y-axis matches normalized direction vector
│   │   ├── T1.10: Procedural shaft length + head length equals vector magnitude
│   │   └── T1.11: Dynamic color gradient: Cyan (<0.5 max) -> Amber (0.5 max) -> Crimson (1.0 max)
│   └── KeplerTrajectoryPreview:
│       ├── T1.12: Circular/elliptical orbit (e < 1.0) produces closed line strip
│       ├── T1.13: Escape trajectory (e >= 1.0) produces hyperbolic arc without NaN
│       ├── T1.14: Degenerate radial plunge (angular momentum h == 0) clears preview
│       └── T1.15: Zero central mass (mu <= 0) clears preview gracefully
│
├── TIER 2: Interaction Manager & Event Routing (8 tests)
│   ├── T2.1: Initialization, default SELECT mode, and focal depth setup
│   ├── T2.2: EventBus tool switching via "physics_tool_selected"
│   ├── T2.3: Time command routing ("set_paused", "toggle_pause", "step_once", "set_time_scale")
│   ├── T2.4: Left-click drag lifecycle: anchor setting, impulse calculation, max speed clamping
│   ├── T2.5: Right-click cancels active drag cleanly without spawning
│   ├── T2.6: Left-click release emits entity_spawned and dispatches EventBus event
│   ├── T2.7: Entity selection dispatches "physics_entity_selected" with metadata
│   └── T2.8: Parameter modification routing updates internal tool configuration
│
├── TIER 3: Scientific Tools & Physics Modules Integration (10 tests)
│   ├── CelestialSpawnerTool:
│   │   ├── T3.1: Lifecycle (initialize, action bindings, cleanup)
│   │   └── T3.2: Spawns celestial body into NBodyGravityModule and verifies count increment
│   ├── ParticleInjectorTool:
│   │   ├── T3.3: Injects gas molecules into MolecularDynamicsModule and verifies buffer growth
│   │   └── T3.4: Adjusts target temperature and verifies thermostat response
│   ├── NuclearLabTool:
│   │   ├── T3.5: Sets up U-235 fuel assembly in NuclearDecayModule
│   │   ├── T3.6: Injects trigger neutron and verifies prompt radiation buffer
│   │   └── T3.7: Adjusts control rod depth and verifies damping parameter
│   ├── QuantumBenchTool:
│   │   ├── T3.8: Injects Gaussian wavepacket into QuantumWavePacketModule and verifies norm = 1.0
│   │   └── T3.9: Reconfigures potential barrier height V0 and verifies potential buffer
│   └── ScientificProbeTool:
│       └── T3.10: Deploys probe and samples 3D field telemetry (gravity, gas, radiation, quantum)
│
└── TIER 4: End-to-End Simulation Sandbox Scenario (2 tests)
    ├── T4.1: End-to-end orbit injection and multi-step symplectic propagation
    └── T4.2: Scientific probe telemetry sampling near active physical bodies
```

---

## 8. Conclusion & Implementer Guidance

To implement Phase 2 cleanly and pass all verification checks:
1. **Apply the EventBus alias** (`publish` $\to$ `emit`) first.
2. **Expose the missing module methods**:
   - `NBodyGravityModule.spawn_body(pos, vel, mass, body_type)`.
   - `MolecularDynamicsModule.inject_particles(pos, count, temp)` and `reset_to_maxwell_boltzmann()`.
   - `QuantumWavePacketModule.set_potential_type()`, `set_barrier_height()`, `set_barrier_width()`, `cycle_potential_type()`, `toggle_dimension()`.
3. **Refine `ScientificProbeTool`** to use getters `get_positions()`, `get_velocities()`, and property `softening`.
4. **Implement `test_physics_interaction_suite.gd`** matching the 4-tier structure outlined above.
5. **Run `--check-only`** to confirm zero GDScript compilation errors.
