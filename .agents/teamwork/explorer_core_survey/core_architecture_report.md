# UniCORE Fundamental Scientific Physics Simulation Platform
## Core Architecture Survey & Integration Report

- **Date**: 2026-10-28
- **Author**: Core Architecture Explorer (`explorer_core_survey`)
- **Target Platform**: Godot 4.0.stable (Official 92bee43ad)
- **Status**: Verified & Finalized

---

## 1. Executive Summary

UniCORE is designed as a modular, event-driven, runtime-extensible computational environment. The objective of the Fundamental Scientific Physics Simulation Platform initiative is to convert this environment into a surface-less 3D vacuum laboratory governed by symplectic numerical integrators, Noether invariant watchdogs, spatial acceleration data structures, and rigorous physics domains (molecular dynamics, relativistic gravity, nuclear decay, and quantum wavepackets).

This survey examines the structural mechanisms of UniCORE, establishes the exact interface contracts required for full engine compatibility, analyzes the observer/space isolation model, and documents the Godot 4.0-stable constraints that must be adhered to by all implementation agents.

---

## 2. UniCoreModule Contract & Lifecycle Specification

### 2.1 Base Class Definition (`res://core/base_module.gd`)
All UniCORE modules must extend `UniCoreModule` (or duck-type inherit `Node`/`Node3D` while strictly implementing the lifecycle API):

```gdscript
class_name UniCoreModule
extends Node

signal module_ready(module_id: String)
signal module_error(module_id: String, error_message: String)

var core_context: Dictionary = {}
var is_initialized: bool = false

func get_module_id() -> String:
    return "base_module"

func get_module_name() -> String:
    return "Base Module"

func get_action_bindings() -> Array[Dictionary]:
    return []

func initialize(context: Dictionary) -> bool:
    core_context = context
    is_initialized = true
    module_ready.emit(get_module_id())
    return true

func cleanup() -> void:
    is_initialized = false
    queue_free()
```

### 2.2 Lifecycle Contract & Execution Flow
1. **Instantiation**: `script.new()`.
   - **Crucial Rule**: The constructor `_init()` must **never** require arguments (`_find_method_info` rejects scripts where required arguments > 0).
2. **Tree Placement**: The module node is placed into `world_root` (`$WorldRoot` in `SpaceViewport`) with its `name` set to `module_id`.
3. **Initialization**: `initialize(context: Dictionary) -> bool`.
   - The `context` dictionary injected by `ModuleManager` (`res://core/module_manager.gd:281`) provides:
     - `context["event_bus"]`: Instance of `EventBus`.
     - `context["world_root"]`: Root 3D node (`Node3D`).
     - `context["module_manager"]`: Reference to `ModuleManager`.
     - `context["space_sync"]`: Network synchronization node (or `null`).
   - The module must call `super.initialize(context)` (if extending `UniCoreModule`), connect to necessary `EventBus` topics, and allocate runtime resources.
4. **Action Registration**: `get_action_bindings() -> Array[Dictionary]`.
   - Enables `InputMapper` (`res://core/input_mapper.gd`) to detect keybindings automatically.
   - Format:
     ```gdscript
     func get_action_bindings() -> Array[Dictionary]:
         return [
             {
                 "action": "heat_gas",
                 "label": "Heat Gas (Thermostat)",
                 "default_key": KEY_UP,
                 "description": "Increases Berendsen target temperature"
             },
             {
                 "action": "cool_gas",
                 "label": "Cool Gas (Thermostat)",
                 "default_key": KEY_DOWN,
                 "description": "Decreases Berendsen target temperature"
             }
         ]
     ```
5. **Process Stepping**:
   - Physical modules **must not** integrate equations of motion in Godot's raw `_process(delta: float)` or `_physics_process(delta: float)`.
   - Instead, physical modules subscribe to `SimulationTimeController.sim_tick(dt: float, sim_time: float)` or tick deterministically during fixed-delta updates.
6. **Destruction & Cleanup**: `cleanup() -> void`.
   - Must disconnect all callbacks from `EventBus` (`event_bus.unsubscribe(...)` or `event_bus.unsubscribe_all_for_target(self)`).
   - Free all allocated textures, meshes, and buffers.
   - Call `super.cleanup()`.
   - Must be callable with **zero** arguments.

### 2.3 CodeValidator Static Analysis Requirements (`res://agent/code_validator.gd`)
Prior to runtime injection or import, code is verified by `CodeValidator`:
- Must inherit `Node` or `UniCoreModule`.
- Must not contain calls to `OS.execute`, `OS.kill`, `OS.crash`, `OS.create_process`, `OS.shell_open`, `OS.set_environment`.
- Must not invoke `DirAccess.remove_absolute`, `erase_contents_recursive`, `make_dir_absolute`.
- Must not write to `res://` paths (read-only for security).
- Must not contain reflection execution bypasses like `.call("execute", ...)` or `Engine.get_singleton("OS")`.
- Must pass `GDScript.reload()` compilation with zero errors.

---

## 3. Core Subsystems & Architecture Placement

### 3.1 Existing Subsystems Topology
```
res://
├── core/
│   ├── base_module.gd           # Base UniCoreModule contract
│   ├── module_manager.gd        # Runtime module loader, script compilation, prototype spawner
│   ├── event_bus.gd             # System publish-subscribe bus
│   ├── space_manager.gd         # Space serialization, template spaces, camera state
│   ├── space_viewport.gd        # Root application scene, wiring subsystems together
│   ├── settings_manager.gd      # Display, controls, audio, and agent settings
│   ├── input_mapper.gd          # Keybinding aggregator and InputMap synchronizer
│   ├── module_library.gd        # Local script storage and indexing
│   ├── diagnostic_logger.gd     # Ring-buffered diagnostic logging
│   └── net/                     # P2P multiplayer, LAN discovery, and CRDT sync
```

### 3.2 Physics Simulation Core Placement (`res://core/physics/`)
The computational physics core is housed under `res://core/physics/`:

| Component | Target File | Class Name | Base Class | Responsibilities |
|---|---|---|---|---|
| **Time Engine** | `res://core/physics/simulation_time_controller.gd` | `SimulationTimeController` | `Node` | Dispatches discrete $\Delta t$, time scale ($0.001\times$ to $1000\times$), pause/resume, and step-once ticking. |
| **Unit Converter** | `res://core/physics/unit_converter.gd` | `UnitConverter` | `RefCounted` | Natural and reduced unit scales (Lennard-Jones, Planck, Astronomical) to avoid IEEE 754 precision issues. |
| **Integrator Base** | `res://core/physics/physical_integrator.gd` | `PhysicalIntegrator` | `RefCounted` | Abstract interface: `integrate(positions, velocities, masses, force_callable, dt)`. |
| **Verlet Integrator** | `res://core/physics/verlet_integrator.gd` | `VerletIntegrator` | `PhysicalIntegrator` | Symplectic Velocity-Verlet algorithm ensuring zero long-term energy drift in conservative Hamiltonian systems. |
| **RK4 Integrator** | `res://core/physics/rk4_integrator.gd` | `RK4Integrator` | `PhysicalIntegrator` | Classical 4th-order Runge-Kutta solver for non-Hamiltonian or velocity-dependent force fields. |
| **Conservation Sentry**| `res://core/physics/conservation_sentry.gd` | `ConservationSentry` | `Node` | Continuous Noether invariant auditor ($E, \vec{P}, \vec{L}, Q$). Emits warning signals when drift exceeds tolerance. |
| **Spatial Hash Grid** | `res://core/physics/spatial_hash_grid.gd` | `SpatialHashGrid` | `RefCounted` | Uniform 3D hash grid with fast prime hashing for $O(N)$ particle neighbor searches within cutoff radius $r_c$. |
| **Barnes-Hut Octree** | `res://core/physics/barnes_hut_octree.gd` | `BarnesHutOctree` | `RefCounted` | $O(N \log N)$ spatial octree with center-of-mass multipole approximation for gravitational and electrostatic fields. |

### 3.3 Physics Simulation Modules Placement (`res://modules/physics/`)

| Module | Target File | Class Name | Domain & Features |
|---|---|---|---|
| **Molecular Dynamics** | `res://modules/physics/molecular_dynamics_module.gd` | `MolecularDynamicsModule` | Lennard-Jones 12-6 potential ($r_c = 2.5\sigma$), Berendsen thermostat ($T_{target}$), reflective container, Maxwell-Boltzmann velocity distribution, single `MultiMeshInstance3D` renderer. |
| **N-Body Gravity** | `res://modules/physics/n_body_gravity_module.gd` | `NBodyGravityModule` | Relativistic and Newtonian N-body gravitation with configurable speed of light $c_{sim}$, Lorentz boost $\gamma$, orbit trail visualizer via `ImmediateMesh`. |
| **Nuclear Decay** | `res://modules/physics/nuclear_decay_module.gd` | `NuclearDecayModule` | Isotope table (U-235, Ra-226, C-14, H-2, H-3, He-4), Poisson stochastic decay channels ($\alpha, \beta^-, \gamma$), induced neutron fission chain reactions, 4-momentum conservation. |
| **Quantum Wavepacket** | `res://modules/physics/quantum_wavepacket_module.gd` | `QuantumWavePacketModule` | Discretized 1D/2D Schrödinger wavepacket propagation via unitary Cayley split-operator evolution, potential barriers (tunneling), phase hue mapping. |
| **Scientific Probe** | `res://modules/physics/scientific_probe_module.gd` | `ScientificProbeModule` | 3D field measurement probes, flux detectors, energy/momentum spectrum visualizer. |

---

## 4. EventBus Messaging Architecture

### 4.1 Bus Architecture (`res://core/event_bus.gd`)
The UniCORE `EventBus` implements a decoupled publish/subscribe pattern:

```
[Physics Modules] ---> emit(topic, payload: Dictionary) ---> [EventBus] ---> callback(payload: Dictionary) ---> [UI / Watchdogs]
```

Key API methods:
- `subscribe(event_name: String, callback: Callable) -> void`: Adds callable to internal `_listeners` array.
- `unsubscribe(event_name: String, callback: Callable) -> void`: Removes specific callable.
- `emit(event_name: String, payload: Dictionary = {}) -> void`: Fires `event_emitted` signal and executes all valid listener Callables with `payload`.
- `unsubscribe_all_for_target(target: Object) -> void`: Purges all callbacks associated with `target` when unmounting.

### 4.2 Standard Physics Event Topics & Payload Contracts
To ensure interoperability between the physics engine, modules, and diagnostic UI:

| Topic | Emitter | Payload Structure | Description |
|---|---|---|---|
| `sim_tick` | `SimulationTimeController` | `{"dt": float, "sim_time": float}` | Clock tick dispatched on every discrete fixed step. |
| `sim_time_scale_changed` | `SimulationTimeController` | `{"time_scale": float}` | Fired when time multiplier changes. |
| `sim_paused` | `SimulationTimeController` | `{"is_paused": bool}` | Fired when simulation pauses or resumes. |
| `invariants_updated` | `ConservationSentry` | `{"kinetic_energy": float, "potential_energy": float, "total_energy": float, "energy_drift_ratio": float, "linear_momentum": Vector3, "angular_momentum": Vector3, "particle_count": int, "temperature": float, "is_conserved": bool}` | Periodic invariant audit snapshot. |
| `conservation_warning` | `ConservationSentry` | `{"violation_type": String, "relative_drift": float, "tolerance": float}` | Triggered when Noether invariant drift exceeds tolerance. |
| `nuclear_reaction_occurred` | `NuclearDecayModule` | `{"reaction_type": String, "parent": String, "daughter": String, "ejected": Array, "energy_released_mev": float, "position": Vector3}` | Emitted on radioactive decay or fission event. |
| `quantum_tunneling_detected` | `QuantumWavePacketModule` | `{"barrier_height": float, "incident_energy": float, "transmission_ratio": float}` | Emitted when wavepacket probability density traverses a barrier. |

---

## 5. Scientific Observer Paradigm & Space Environment

### 5.1 Baseline Environment: Surface-less 3D Vacuum
In `res://core/space_manager.gd`, the default space template is `TEMPLATE_DEFAULT_STUDIO`:
- Modules loaded: `["builtin_avatar_locomotion"]`.
- Environment: Dark vacuum background `Color(0.06, 0.07, 0.09, 1.0)`, ambient energy 0.6.
- Surface/Ground: **Zero default ground planes**. `builtin_ground_plane` is NOT included in the default studio. The world is a sterile Cartesian reference frame.

### 5.2 User Observer Camera Isolation (`res://modules/builtin/avatar_locomotion.gd`)
- The user camera is an instance of `Camera3D` nested under `AvatarYaw` and `AvatarPitch` Node3Ds.
- Movement is purely kinematic translation based on WASD/Space/Ctrl/Shift input:
  $$\vec{r}_{cam} \leftarrow \vec{r}_{cam} + \hat{d}_{input} \cdot v_{move} \cdot \Delta t$$
- **Immunity Guarantee**:
  - The observer has no `RigidBody3D`, no `CollisionShape3D`, and no physical mass.
  - The camera is not registered in `SpatialHashGrid` or particle arrays.
  - No gravitational acceleration, thermodynamic temperature transfer, relativistic mass dilation, or nuclear radiation flux is applied to the observer.
  - The observer represents an external inertial experimenter in an absolute laboratory frame.

---

## 6. Godot 4.0.stable Engine Constraints & Implementation Rules

All subagents and implementers must strictly obey the following Godot 4.0.stable constraints codified in `GEMINI.md`:

### 6.1 Strict GDScript 2.0 Static Typing
- Every variable, parameter, and return type must be explicitly typed.
- Prohibited: `var count = 0`, `func update(data):`.
- Required: `var count: int = 0`, `func update(data: Dictionary) -> void:`.
- Zero untyped `Variant` variables in math loops to guarantee maximum GDScript bytecode performance.

### 6.2 Prohibited `ClassName.has_method(...)` on Class Names
- In Godot 4.0-stable, calling `.has_method(...)` or `.has_signal(...)` directly on a `class_name` symbol causes an engine crash or compilation error.
- Permitted: Call on instances (`instance.has_method("foo")`) or use `ClassDB.class_has_method(class_string, method_string)`.

### 6.3 Lambda Primitive Capture by Value
- Primitives (`bool`, `int`, `float`) captured by closures/lambdas are copied by value.
- To mutate state across a lambda closure, wrap the primitive in a 1-element `Array`:
  ```gdscript
  var completed := [false]
  var callable := func():
      completed[0] = true
  ```

### 6.4 `Callable.bind(...)` Argument Order
- `Callable.bind(...)` appends bound arguments *to the end* of the parameter list.
- Example: If a signal emits `(a: float, b: float)` and you connect with `.bind(c: int)`, the target callback signature must be `func _on_signal(a: float, b: float, c: int) -> void:`.

### 6.5 High-Performance GPU Multi-Mesh Rendering
- Creating individual `Node3D` instances for thousands of particles will overwhelm Godot's scene tree iterator and memory allocator.
- Particles must be stored in contiguous packed buffers (`PackedVector3Array`, `PackedFloat32Array`) and rendered via a single `MultiMeshInstance3D`:
  ```gdscript
  var multimesh := MultiMesh.new()
  multimesh.transform_format = MultiMesh.TRANSFORM_3D
  multimesh.use_colors = true
  multimesh.instance_count = particle_count
  ```

### 6.6 Headless Test Execution Constraints
- Built-in `assert()` halts/hangs the Godot process when running under `--headless`.
- Test suites must use tracking counters and explicit termination:
  ```gdscript
  var passed_count: int = 0
  var failed_count: int = 0
  func assert_true(cond: bool, test_name: String, err_msg: String = "") -> void:
      if cond:
          passed_count += 1
          print("  [PASS] %s" % test_name)
      else:
          failed_count += 1
          print("  [FAIL] %s - %s" % [test_name, err_msg])
  ```
- All test suites must reside in `res://tests/test_*_suite.gd` so `test_runner.gd` aggregates them automatically.
- Verification command:
  ```powershell
  & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
  ```

---

## 7. Concrete Implementation Blueprint for Phase 1 & 2 Agents

### 7.1 Core Physics Subagent Blueprint
1. Create `res://core/physics/simulation_time_controller.gd`:
   - Properties: `time_scale: float`, `fixed_delta: float`, `is_paused: bool`, `sim_time: float`, `max_substeps: int`.
   - Dispatch `sim_tick(dt: float, sim_time: float)` during `_physics_process`.
2. Create `res://core/physics/physical_integrator.gd`, `verlet_integrator.gd`, `rk4_integrator.gd`:
   - Enforce Velocity-Verlet symplectic step:
     $$\vec{r}_{t+\Delta t} = \vec{r}_t + \vec{v}_t \Delta t + \frac{1}{2} \vec{a}_t \Delta t^2$$
     $$\vec{a}_{t+\Delta t} = \frac{1}{m} \sum \vec{F}(\vec{r}_{t+\Delta t})$$
     $$\vec{v}_{t+\Delta t} = \vec{v}_t + \frac{1}{2}(\vec{a}_t + \vec{a}_{t+\Delta t}) \Delta t$$
3. Create `res://core/physics/conservation_sentry.gd`:
   - Compute total energy $E = E_k + E_p$, momentum $\vec{P} = \sum m_i \vec{v}_i$, angular momentum $\vec{L} = \sum \vec{r}_i \times (m_i \vec{v}_i)$.
   - Track relative drift $|E(t) - E_0| / |E_0|$.
4. Create `res://core/physics/spatial_hash_grid.gd`:
   - 3D spatial partitioning table with prime hashing: $(ix \cdot 73856093) \oplus (iy \cdot 19349663) \oplus (iz \cdot 83492791)$.

### 7.2 Physics Modules Subagent Blueprint
1. Create `res://modules/physics/molecular_dynamics_module.gd`:
   - Lennard-Jones force calculation with cutoff $r_c = 2.5\sigma$.
   - Berendsen thermostat velocity rescaling factor $\lambda$.
   - MultiMeshInstance3D color gradient mapping: kinetic energy $\to$ Blue (cold) to Red (hot).
2. Create `res://modules/physics/n_body_gravity_module.gd`:
   - Newtonian $G \frac{m_1 m_2}{r^2} \hat{r}$ with speed of light $c_{sim}$ cap and $\gamma$ Lorentz factor.
   - ImmediateMesh orbit trail drawing.
3. Create `res://modules/physics/nuclear_decay_module.gd`:
   - Poisson decay probability $P = 1 - e^{-\lambda \Delta t}$.
   - Alpha, beta, and induced fission channels.
4. Create `res://modules/physics/quantum_wavepacket_module.gd`:
   - 1D/2D grid wavepacket $\psi(x) = \psi_R + i \psi_I$.
   - Unitary time evolution with potential barrier tunneling.

### 7.3 Testing Subagent Blueprint
- Create `res://tests/test_physics_engine_suite.gd`:
  - Test 1: Verlet harmonic oscillator energy drift $< 0.001$ over 5,000 steps.
  - Test 2: SpatialHashGrid neighbor query equivalence with brute-force $O(N^2)$.
  - Test 3: SimulationTimeController pause, step_once, and time scale validation.
  - Test 4: ConservationSentry invariant auditing.
  - Test 5: Molecular dynamics Berendsen thermostat convergence to $T_{target}$.
  - Test 6: Relativistic velocity cap ($v < c_{sim}$).
  - Test 7: Nuclear decay exponential law statistics.

---

## 8. Conclusion
The existing UniCORE architecture (`res://core/base_module.gd`, `res://core/module_manager.gd`, `res://core/space_manager.gd`, `res://core/event_bus.gd`) provides an ideal substrate for the Fundamental Scientific Physics Simulation Platform. The baseline space template is already configured as a sterile vacuum, the observer camera is purely kinematic and immune to physical forces, and the dynamic module lifecycle enables hot-reloadable simulation domains. Adherence to strict GDScript 2.0 static typing, symplectic time-stepping, and data-oriented `MultiMeshInstance3D` rendering will satisfy all acceptance criteria.
