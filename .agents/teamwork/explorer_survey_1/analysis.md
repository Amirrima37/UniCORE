# UniCORE Scientific Physics Platform: Comprehensive Specification & Interface Analysis

**Document Author**: Explorer Survey 1 (Specification & Interface Miner)  
**Date**: 2026-10-28  
**Target Engine**: Godot 4.0.stable (official 92bee43ad)  
**Status**: Authoritative Architectural Survey & Discovery Report  

---

## 1. Executive Summary & Architectural Scope

The UniCORE platform is expanding from a modular core into an interactive, fundamental computational physics laboratory operating in a surface-less 3D vacuum. Following Phase 3 core engine implementation (numerical integrators, conservation sentry, spatial hash grid, and baseline physics domains), this survey defines the complete specification, mathematical models, API contracts, signal schemas, and edge-case handling for the **Interactive Scientific Physics Sandbox & Toolset**:

1. **VelocityVectorGizmo** (`res://core/physics/interaction/velocity_vector_gizmo.gd`)
2. **PhysicsInteractionManager** (`res://core/physics/interaction/physics_interaction_manager.gd`)
3. **The 5 Interactive Scientific Physics Tools** (`res://modules/physics/tools/`):
   - `CelestialSpawnerTool` (`celestial_spawner_tool.gd`)
   - `ParticleInjectorTool` (`particle_injector_tool.gd`)
   - `NuclearLabTool` (`nuclear_lab_tool.gd`)
   - `QuantumBenchTool` (`quantum_bench_tool.gd`)
   - `ScientificProbeTool` (`scientific_probe_tool.gd`)
4. **Interaction Auxiliary Systems**:
   - `ScreenRaycaster` (`res://core/physics/interaction/screen_raycaster.gd`)
   - `KeplerTrajectoryPreview` (`res://core/physics/interaction/kepler_trajectory_preview.gd`)
   - UI Interoperability (`PhysicsToolbox`, `PhysicsInspectorDrawer`, `EventBus`)

---

## 2. Features Discovered & Interface Contracts

### 2.1 Specification Catalog

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | 3D Gizmo | Velocity Vector Procedural Mesh | Generates a 3D arrow composed of a cylinder shaft and cone head dynamically scaled to impulse $|\vec{v}|$ | `origin: Vector3`, `vector: Vector3`, `max_speed_scale: float` | Updates `MeshInstance3D` scale, position, and orientation | Returns early and sets `visible = false` if $|\vec{v}| < 0.001$ | `velocity_vector_gizmo.gd` |
| 2 | 3D Gizmo | Singularity-Free Basis Alignment | Builds orthonormal basis orienting cylinder $+Y$ axis along $\hat{v} = \vec{v}/|\vec{v}|$ | Direction vector $\hat{v}$ | `Basis(right, dir, forward)` | If $|\hat{v} \cdot \hat{y}| > 0.99$, swaps reference up to $\vec{u} = (0, 0, 1)$ to prevent degenerate cross products | `velocity_vector_gizmo.gd` |
| 3 | 3D Gizmo | Dynamic Kinetic Energy Color Gradient | Transitions arrow color Cyan $\to$ Amber $\to$ Crimson based on normalized velocity ratio | Velocity magnitude $L$, $v_{max}$ | Albedo color assigned to `StandardMaterial3D` | Clamps ratio $\rho \in [0.0, 1.0]$; guards against $v_{max} \le 0$ with `max(v_max, 0.001)` | `velocity_vector_gizmo.gd` |
| 4 | Raycasting | Arbitrary Plane Ray Intersection | Computes 3D intersection point of camera screen ray with infinite 3D plane | `camera: Camera3D`, `screen_pos: Vector2`, `plane_normal: Vector3`, `plane_origin: Vector3` | `Variant` (`Vector3` or `null`) | Returns `null` if ray is parallel to plane ($|\vec{D} \cdot \hat{n}| < 10^{-6}$) or behind camera ($t < 0$) | `screen_raycaster.gd` |
| 5 | Raycasting | Camera-Facing Billboard Plane Raycast | Intersects screen ray with plane facing camera passing through anchor position | `camera: Camera3D`, `screen_pos: Vector2`, `anchor_pos: Vector3` | `Variant` (`Vector3` or `null`) | Returns `null` if camera is null or ray is parallel | `screen_raycaster.gd` |
| 6 | Raycasting | Fixed Depth Plane Raycast | Intersects screen ray with camera-perpendicular plane at distance $d$ in front of camera | `camera: Camera3D`, `screen_pos: Vector2`, `depth: float` | `Variant` (`Vector3` or `null`) | Returns `null` if camera is null | `screen_raycaster.gd` |
| 7 | Interaction | Click-and-Drag Impulse Detection | Detects mouse down to anchor initial 3D position, tracks drag vector to compute impulse $\vec{v}_0$, and finishes gesture on mouse release | Mouse input events (`InputEventMouseButton`, `InputEventMouseMotion`) | Emits `drag_started`, `drag_updated`, `drag_ended`; updates gizmo | If screen motion $< 6$ px, treats as click (selection or point spawn) | `physics_interaction_manager.gd` |
| 8 | Interaction | Entity Picking & Proximity Selection | Casts 3D ray into active physics module buffers to identify closest particle or entity within pick tolerance | Screen coordinate `Vector2`, active modules | Emits `entity_selected`, publishes `"physics_entity_selected"` | Ignores entities behind camera; returns null if distance exceeds threshold | `physics_interaction_manager.gd` |
| 9 | Interaction | Orbit Conic Section Prediction | Computes Kepler orbital elements from position and velocity vectors and renders closed/escape trajectories in real time | `primary_pos: Vector3`, `body_pos: Vector3`, `velocity: Vector3`, $\mu = G M$ | Renders line strip on `ImmediateMesh` | Clears surfaces and hides if $\mu \le 0$, $|\vec{r}| < 0.01$, $|\vec{v}| < 0.001$, or radial plunge ($|\vec{h}| < 10^{-4}$) | `kepler_trajectory_preview.gd` |
| 10 | Tool | Celestial Body Spawning | Spawns stars, planets, moons, and black holes into `NBodyGravityModule` with impulse and orbit prediction | `pos: Vector3`, `vel: Vector3`, `mass: float`, `body_type: String` | Appends body to `NBodyGravityModule`; emits `celestial_body_created` | Resolves module dynamically; guards against missing module reference | `celestial_spawner_tool.gd` |
| 11 | Tool | Molecular Gas Injection & Thermostat | Injects thermal gas clusters with Maxwell-Boltzmann distribution and controls Berendsen thermostat temperature | `pos: Vector3`, `count: int`, `temp: float` | Adds particles to `MolecularDynamicsModule`; emits `gas_injected` | Clamps target temperature to $T \ge 0.05$ | `particle_injector_tool.gd` |
| 12 | Tool | Laser Heating & Optical Molasses | Applies localized thermal energy or velocity damping force $\vec{F} = -\gamma \vec{v}$ to particles within beam cylinder/sphere | `pos: Vector3`, `mode: int`, `radius: float`, `power: float` | Modifies particle velocity buffer in-place | Ignores particles outside laser radius; clamps cooling multiplier | `particle_injector_tool.gd` (Spec) |
| 13 | Tool | Radioisotope Assembly Placement | Places structured geometric clusters of U-235, Ra-226, C-14, or H-3 in the nuclear reaction chamber | `pos: Vector3`, `isotope: String`, `count: int`, `radius: float` | Spawns nuclei in `NuclearDecayModule`; registers system with sentry | Rejects unknown isotope symbols with error log | `nuclear_lab_tool.gd` (Spec) |
| 14 | Tool | Neutron Gun Firing | Aims and emits high-speed prompt neutrons along dragged velocity vector to trigger induced fission chain reactions | `pos: Vector3`, `vel: Vector3` | Spawns neutron radiation entity in `NuclearDecayModule` | Caps total radiation entities to `MAX_RADIATION` | `nuclear_lab_tool.gd` (Spec) |
| 15 | Tool | Control Rod Reactivity Tuning | Adjusts absorber depth from 0.0 (withdrawn, supercritical) to 1.0 (inserted, scrammed) | `depth: float` $\in [0.0, 1.0]$ | Updates `control_rod_depth` in `NuclearDecayModule` | Clamps depth strictly to $[0.0, 1.0]$ | `nuclear_lab_tool.gd` (Spec) |
| 16 | Tool | Quantum Potential Barrier Shaping | Configures rectangular barriers, step potentials, harmonic wells, or double-slits | `type: int`, $V_0: \text{float}$, $d: \text{float}$, $x_0: \text{float}$ | Updates potential buffers and transforms visualizer mesh | Rebuilds potential grid; handles 1D and 2D arrays | `quantum_bench_tool.gd` (Spec) |
| 17 | Tool | Wavepacket Emission & Tunneling Probe | Emits localized Gaussian wavepacket with incident wavenumber $k_0$; computes empirical vs analytical transmission $T$ | Center $x_0, z_0$, width $\sigma$, wavenumber $k_0$ | Reinitializes wavefunction buffers; emits `tunneling_measured` | Enforces Dirichlet boundary conditions at grid boundaries | `quantum_bench_tool.gd` (Spec) |
| 18 | Tool | 3D Scientific Field Sensor Placement | Deploys localized sensor probes in 3D vacuum to sample gravitational, thermodynamic, radiation, and quantum fields | Raycast hit `Vector3`, `probe_type: String` | Instantiates visual probe node; registers probe ID in registry | Rejects placement if maximum probe count (e.g. 8) is reached | `scientific_probe_tool.gd` (Spec) |
| 19 | Tool | Multi-Field Telemetry & History Sampling | Samples local field strength $\vec{g}, \Phi, T_{local}, n, \Phi_{rad}, |\psi|^2$ at sensor coordinates at fixed sampling frequency | Fixed delta tick, probe coordinates | Emits rolling history buffer and telemetry Dictionary to EventBus | Handles absence of specific modules gracefully without null errors | `scientific_probe_tool.gd` (Spec) |

---

## 3. Mathematical Models & Rigorous Formulations

### 3.1 Velocity Vector Gizmo: Geometry, Proportions & Basis Orthonormality

Given an initial click position $\vec{x}_{anchor} \in \mathbb{R}^3$ and a dragged position $\vec{x}_{drag} \in \mathbb{R}^3$:
$$\vec{v} = (\vec{x}_{drag} - \vec{x}_{anchor}) \cdot k_{drag}$$
where $k_{drag}$ is the velocity drag sensitivity multiplier (default $2.0$).

#### Length & Head/Shaft Partitioning
1. Velocity magnitude:
   $$L = |\vec{v}| = \sqrt{v_x^2 + v_y^2 + v_z^2}$$
2. Singularity check:
   $$\text{If } L < 10^{-3} \implies \text{gizmo is deactivated; } \vec{v}_{current} = \vec{0}$$
3. Adaptive head length: To prevent the cone head from overflowing the total vector length at low speeds, the actual head length is capped at 40% of the vector length:
   $$L_{head} = \min(L_{head\_param}, L \times 0.4), \quad \text{where } L_{head\_param} = 0.4\text{ m}$$
4. Shaft length:
   $$L_{shaft} = L - L_{head}$$
5. Transform offsets: Since Godot's `CylinderMesh` has its origin at its geometric center ($Y=0$) with total height $1.0$:
   - Shaft scale: $\vec{S}_{shaft} = (1.0, L_{shaft}, 1.0)$
   - Shaft local position: $\vec{P}_{shaft} = \left(0, \frac{L_{shaft}}{2}, 0\right)$
   - Head scale: $\vec{S}_{head} = \left(1.0, \frac{L_{head}}{L_{head\_param}}, 1.0\right)$
   - Head local position: $\vec{P}_{head} = \left(0, L_{shaft} + \frac{L_{head}}{2}, 0\right)$

#### Orthonormal Basis Construction Without Gimbal Singularities
The cylinder points along the local $+Y$ axis. We must compute a rotation matrix $\mathbf{R} = [\vec{u}_{right} \; \hat{d} \; \vec{u}_{forward}]$ such that:
$$\hat{d} = \frac{\vec{v}}{L}$$
To avoid a degenerate cross-product when $\hat{d}$ is parallel to the global up vector $\hat{y} = (0, 1, 0)$:
$$\vec{u}_{ref} = \begin{cases} (0, 0, 1) & \text{if } |\hat{d} \cdot (0, 1, 0)| > 0.99 \\ (0, 1, 0) & \text{otherwise} \end{cases}$$
The right and forward orthogonal unit vectors are:
$$\vec{u}_{right} = \frac{\hat{d} \times \vec{u}_{ref}}{|\hat{d} \times \vec{u}_{ref}|}$$
$$\vec{u}_{forward} = \vec{u}_{right} \times \hat{d}$$
The global basis is:
$$\mathbf{B} = \text{Basis}(\vec{u}_{right}, \hat{d}, \vec{u}_{forward})$$
Because $\vec{u}_{right} \perp \hat{d}$ and $\vec{u}_{forward} = \vec{u}_{right} \times \hat{d}$, $\det(\mathbf{B}) = 1.0$, guaranteeing an orthonormal, right-handed coordinate frame free of shear and reflection.

#### Energy Spectrum Color Gradient
Let the normalized velocity ratio be:
$$\rho = \text{clamp}\left(\frac{L}{\max(v_{max}, 0.001)}, 0.0, 1.0\right)$$
The color transitions smoothly across two thermodynamic/relativistic regimes:
- **Subsonic / Thermal Regime** ($\rho \in [0.0, 0.5]$):
  $$\vec{C}(\rho) = \text{lerp}\left(\text{Cyan}(0.0, 0.9, 1.0), \text{Amber}(1.0, 0.7, 0.0), 2\rho\right)$$
- **Relativistic / High-Energy Regime** ($\rho \in (0.5, 1.0]$):
  $$\vec{C}(\rho) = \text{lerp}\left(\text{Amber}(1.0, 0.7, 0.0), \text{Crimson}(1.0, 0.1, 0.3), 2(\rho - 0.5)\right)$$

---

### 3.2 3D Screen-to-World Raycasting & Plane Projection

Given camera position $\vec{C} \in \mathbb{R}^3$, view projection matrix, and screen coordinate $\vec{s} = (x, y) \in \mathbb{R}^2$:
- Ray origin: $\vec{O} = \text{project\_ray\_origin}(\vec{s})$
- Ray unit direction: $\vec{D} = \text{project\_ray\_normal}(\vec{s})$

#### Infinite Plane Intersection
An arbitrary plane is defined by normal unit vector $\hat{n}$ and point $\vec{P}_0$:
$$(\vec{P} - \vec{P}_0) \cdot \hat{n} = 0$$
Substituting the ray parametric equation $\vec{P}(t) = \vec{O} + t \vec{D}$:
$$(\vec{O} + t \vec{D} - \vec{P}_0) \cdot \hat{n} = 0 \implies t = \frac{(\vec{P}_0 - \vec{O}) \cdot \hat{n}}{\vec{D} \cdot \hat{n}}$$
- **Singularity Check**: If $|\vec{D} \cdot \hat{n}| < 10^{-6}$, the ray is parallel to the plane (no intersection, returns `null`).
- **Direction Check**: If $t < 0$, the plane is behind the camera (invalid intersection, returns `null`).
- **Hit Point**:
  $$\vec{P}_{hit} = \vec{O} + t \vec{D}$$

#### Interaction Plane Modes
1. **Camera-Facing Billboard Plane** (Passing through anchor $\vec{P}_{anchor}$):
   $$\hat{n} = -\text{camera.global\_basis.z}, \quad \vec{P}_0 = \vec{P}_{anchor}$$
   Guarantees that dragging in screen space produces an isometric 1:1 displacement in world space without perspective elongation.
2. **Fixed Depth Plane** (At depth $d$ in front of camera):
   $$\vec{P}_0 = \vec{C} - \text{camera.global\_basis.z} \cdot d, \quad \hat{n} = -\text{camera.global\_basis.z}$$
3. **Cartesian Ground Plane (XZ)**:
   $$\hat{n} = (0, 1, 0), \quad \vec{P}_0 = (0, y_{plane}, 0)$$

---

### 3.3 Kepler Orbit Prediction (Conic Section Reconstruction)

Given primary attractor position $\vec{r}_{primary}$, orbiting body initial position $\vec{r}$, initial velocity $\vec{v}$, and gravitational parameter $\mu = G M_{primary}$:

1. Relative displacement: $\vec{\rho} = \vec{r} - \vec{r}_{primary}$, $r = |\vec{\rho}|$.
2. Specific angular momentum vector:
   $$\vec{h} = \vec{\rho} \times \vec{v}, \quad h = |\vec{h}|$$
   If $h < 10^{-4}$, the orbit is a degenerate radial plunge (line preview cleared).
3. Eccentricity vector:
   $$\vec{e} = \frac{\vec{v} \times \vec{h}}{\mu} - \frac{\vec{\rho}}{r}, \quad e = |\vec{e}|$$
4. Semi-latus rectum:
   $$p = \frac{h^2}{\mu}$$
5. Perifocal coordinate unit vectors:
   - Periapsis unit vector: $\hat{P} = \frac{\vec{e}}{e}$ (or $\frac{\vec{\rho}}{r}$ if $e < 10^{-4}$)
   - Normal to orbital plane: $\hat{W} = \frac{\vec{h}}{h}$
   - In-plane orthogonal vector: $\hat{Q} = \hat{W} \times \hat{P}$
6. Radial distance as function of true anomaly $\theta$:
   $$r(\theta) = \frac{p}{1 + e \cos\theta}$$
7. Geometry cases:
   - **Elliptical / Circular Orbits** ($e < 0.99$):
     Discretized over $\theta \in [0, 2\pi]$ across $N_{seg} = 120$ points:
     $$\vec{x}(\theta) = \vec{r}_{primary} + r(\theta) \cos\theta \hat{P} + r(\theta) \sin\theta \hat{Q}$$
   - **Hyperbolic Escape Trajectories** ($e \ge 0.99$):
     Bounded by the asymptote angle $\theta_{max} = \arccos\left(-\frac{1}{e}\right) - 0.1$:
     Discretized over $\theta \in [-\theta_{max}, \theta_{max}]$.

---

### 3.4 Entity Raycasting & Proximity Picking

Given ray $(\vec{O}, \vec{D})$ and candidate entity at $\vec{C} \in \mathbb{R}^3$ with radius $R_{entity}$:
1. Vector from origin to entity: $\vec{w} = \vec{C} - \vec{O}$.
2. Projection distance along ray: $t_{proj} = \vec{w} \cdot \vec{D}$.
3. If $t_{proj} < 0$, entity is behind the camera.
4. Perpendicular distance squared from entity center to ray:
   $$d_\perp^2 = |\vec{w}|^2 - t_{proj}^2 = (\vec{w} \cdot \vec{w}) - t_{proj}^2$$
5. Selection hit condition:
   $$d_\perp^2 \le (R_{entity} + R_{margin})^2, \quad \text{where } R_{margin} = 0.3\text{ m}$$
6. Distance to entrance intersection:
   $$t_{hit} = t_{proj} - \sqrt{(R_{entity} + R_{margin})^2 - d_\perp^2}$$
7. The entity with the minimum positive $t_{hit}$ across all active modules is selected.

---

### 3.5 Cross-Module Scientific Probe Field Mathematics

A `ScientificProbe` located at sensor coordinates $\vec{x}_{probe} \in \mathbb{R}^3$ samples:

1. **Gravitational Field $\vec{g}$ and Potential $\Phi$** (from `NBodyGravityModule`):
   $$\vec{g}(\vec{x}_{probe}) = -\sum_{i=1}^N \frac{G M_i (\vec{x}_{probe} - \vec{r}_i)}{\left(|\vec{x}_{probe} - \vec{r}_i|^2 + \epsilon^2\right)^{3/2}}$$
   $$\Phi(\vec{x}_{probe}) = -\sum_{i=1}^N \frac{G M_i}{\sqrt{|\vec{x}_{probe} - \vec{r}_i|^2 + \epsilon^2}}$$
2. **Local Thermodynamic Density $n$ and Kinetic Temperature $T_{local}$** (from `MolecularDynamicsModule`):
   For all particles within probe sensor radius $R_{probe}$ ($N_{local}$ count):
   $$n = \frac{N_{local}}{\frac{4}{3}\pi R_{probe}^3}$$
   Mean drift velocity: $\vec{v}_{flow} = \frac{1}{N_{local}} \sum_{i \in \text{sensor}} \vec{v}_i$.
   Local thermal kinetic temperature:
   $$T_{local} = \frac{1}{3 N_{local} k_B} \sum_{i \in \text{sensor}} m_i |\vec{v}_i - \vec{v}_{flow}|^2$$
3. **Radiation Flux $\Phi_{rad}$ and Dosimetry** (from `NuclearDecayModule`):
   Count of ionizing particles (neutrons, $\alpha, \beta, \gamma$) passing through the probe sensor cross-section per second:
   $$\Phi_{rad} = \frac{\Delta N_{detected}}{\Delta t \cdot \pi R_{probe}^2} \quad [\text{particles} / (\text{m}^2 \cdot \text{s})]$$
   Dose rate proxy: $\dot{D} = \Phi_{rad} \times k_{dose} \; [\mu\text{Sv/h}]$.
4. **Quantum Wavepacket Probability Density $|\psi|^2$** (from `QuantumWavePacketModule`):
   Sample nearest discrete grid cell:
   $$P_{local} = |\psi(\vec{x}_{probe})|^2 = \psi_R^2 + \psi_I^2, \quad \text{Phase } \theta = \text{atan2}(\psi_I, \psi_R)$$

---

## 4. Signal Schemas & EventBus Interaction Topology

```
+-----------------------------------------------------------------------------------+
|                                  EventBus                                         |
+-----------------------------------------------------------------------------------+
    ^                        ^                         |                      |
    | "physics_tool_selected"| "physics_entity_selected"| "physics_parameter_changed"|
    |                        |                         v                      v
+-----------------------+ +--------------------------------+ +---------------------+
|    PhysicsToolbox     | |     PhysicsInteractionManager  | | PhysicsInspector    |
| (UI / Design Domain)  | |        (res://core/physics/)   | |       Drawer        |
+-----------------------+ +--------------------------------+ +---------------------+
                                       |
                   +-------------------+-------------------+
                   |                   |                   |
                   v                   v                   v
        +--------------------+ +----------------+ +-------------------+
        | VelocityVectorGizmo| | ScreenRaycaster| | OrbitTrajectory   |
        |   (3D Arrow Node)  | |  (Math/Plane)  | |   Preview Mesh    |
        +--------------------+ +----------------+ +-------------------+
                   |
                   +---------------------------------------+
                   |                                       |
                   v                                       v
+-------------------------------------+ +-------------------------------------+
|   res://modules/physics/tools/      | |       res://modules/physics/        |
|-------------------------------------| |-------------------------------------|
| 1. CelestialSpawnerTool             | | 1. NBodyGravityModule               |
| 2. ParticleInjectorTool             | | 2. MolecularDynamicsModule          |
| 3. NuclearLabTool                   | | 3. NuclearDecayModule               |
| 4. QuantumBenchTool                 | | 4. QuantumWavePacketModule          |
| 5. ScientificProbeTool              | | 5. ScientificProbeModule            |
+-------------------------------------+ +-------------------------------------+
```

### Event Payload Contracts

#### 1. `physics_tool_selected`
```gdscript
{
    "tool_id": String # "select", "gravity", "thermodynamics", "nuclear", "quantum", "sensor"
}
```

#### 2. `physics_entity_selected`
```gdscript
{
    "entity_id": String,       # e.g. "body_0", "probe_target", "nucleus_42"
    "type": String,            # "celestial_body", "gas_molecule", "radioisotope", "sensor_probe"
    "position": Vector3,       # World coordinate
    "velocity": Vector3,       # Velocity state vector
    "mass": float,             # Physical mass
    "energy": float,           # Kinetic or binding energy
    "metadata": Dictionary     # Module-specific telemetry (temperature, gamma, isotope, etc.)
}
```

#### 3. `physics_parameter_changed`
```gdscript
{
    "module_id": String,       # "n_body_gravity_module", "molecular_dynamics_module", etc.
    "param": String,           # "gravity_mass", "thermo_temp", "nuclear_isotope", "quantum_v0"
    "value": Variant           # float, int, String, bool
}
```

#### 4. `physics_entity_spawned`
```gdscript
{
    "module_id": String,
    "entity": {
        "position": Vector3,
        "velocity": Vector3,
        "mass": float,
        "metadata": Dictionary
    }
}
```

---

## 5. Architectural Inconsistencies & Critical Vulnerabilities Discovered

During forensic analysis of the existing codebase, five critical interface vulnerabilities were identified that would cause runtime crashes if not resolved:

### Finding 1: `EventBus.publish` Method Absence
- **Observation**: `res://core/event_bus.gd` defines `func emit(event_name: String, payload: Dictionary = {}) -> void`. It does NOT define `publish(...)`.
- **Impact**: Files written against the UI spec (`physics_interaction_manager.gd`, `celestial_spawner_tool.gd`, `particle_injector_tool.gd`, `physics_time_bar.gd`) invoke `_event_bus.publish(...)`. When executed, this results in runtime error `Invalid call. Nonexistent function 'publish' in base 'Node (EventBus)'`.
- **Authoritative Resolution**: In `res://core/event_bus.gd`, implement method alias:
  ```gdscript
  func publish(event_name: String, payload: Dictionary = {}) -> void:
      emit(event_name, payload)
  ```
  Additionally, tools must support defensive calling: `if _event_bus.has_method("publish"): ... elif _event_bus.has_method("emit"): ...`.

### Finding 2: `add_body` Argument Order Mismatch in `CelestialSpawnerTool`
- **Observation**: `NBodyGravityModule.add_body` has signature:
  ```gdscript
  func add_body(p_name: String, pos: Vector3, vel: Vector3, mass: float, radius: float = 0.2, col: Color = Color.WHITE) -> void
  ```
  In `celestial_spawner_tool.gd`, the call was made as:
  ```gdscript
  _gravity_module.add_body(position, velocity, mass)
  ```
- **Impact**: In GDScript 2.0 with strict static typing, passing `position` (type `Vector3`) to parameter `p_name` (type `String`) causes a fatal runtime type error.
- **Authoritative Resolution**: Update `CelestialSpawnerTool` to pass the identifier as the first parameter:
  ```gdscript
  var body_name := "%s_%d" % [body_type.capitalize(), _body_counter]
  _gravity_module.add_body(body_name, position, velocity, mass, radius, color)
  ```

### Finding 3: Missing Dynamic Particle Injection in `MolecularDynamicsModule`
- **Observation**: `MolecularDynamicsModule` populates particle buffers strictly during `reset_simulation()`. It currently lacks a public `inject_particles(...)` method.
- **Impact**: `ParticleInjectorTool` calls `_md_module.has_method("inject_particles")`, which evaluates to `false`, leaving dynamic thermal gas injection non-functional.
- **Authoritative Resolution**: Add `inject_particles` to `MolecularDynamicsModule`:
  ```gdscript
  func inject_particles(center_pos: Vector3, count: int, temp: float, stream_vel: Vector3 = Vector3.ZERO) -> void:
      var old_n := _positions.size()
      var new_n := old_n + count
      _positions.resize(new_n)
      _velocities.resize(new_n)
      _masses.resize(new_n)
      _forces.resize(new_n)
      ...
  ```

### Finding 4: Forbidden `ClassName.has_method()` Usage
- **Observation**: Per UniCORE GEMINI.md Rule 1.1, Godot 4.0-stable prohibits calling `has_method()` directly on class names (e.g. `UniCoreModule.has_method(...)`).
- **Impact**: Calling `has_method()` on class names causes engine parser/runtime errors.
- **Authoritative Resolution**: Always invoke `has_method()` on instantiated references (`obj.has_method(...)`).

### Finding 5: Headless Test Suite Safety (`assert()` Ban)
- **Observation**: Godot 4 headless execution deadlocks if a native `assert()` fails.
- **Impact**: Running tests with native `assert()` in CI or command line can permanently freeze the process.
- **Authoritative Resolution**: Automated tests in `res://tests/` must use tracking functions (`assert_test(cond, name, details)`) and terminate via `quit(exit_code)`.

---

## 6. Edge Cases & Boundary Conditions Analysis

| # | Feature | Input / Edge Condition | Expected / Authoritative Behavior |
|---|---------|------------------------|------------------------------------|
| 1 | VelocityVectorGizmo | Zero-length impulse ($|\vec{v}| = 0$) | Gizmo becomes invisible (`visible = false`), $\vec{v}_{current} = \vec{0}$, no divide-by-zero or NaN basis. |
| 2 | VelocityVectorGizmo | Pure vertical impulse ($\vec{v} = (0, 10, 0)$) | Detects $|\hat{v} \cdot \hat{y}| > 0.99$; swaps reference up vector to $\vec{u} = (0, 0, 1)$; builds valid right-handed basis without degenerate cross product. |
| 3 | VelocityVectorGizmo | Pure negative vertical ($\vec{v} = (0, -10, 0)$) | Swaps reference up vector to $\vec{u} = (0, 0, 1)$; builds valid basis pointing downward. |
| 4 | VelocityVectorGizmo | Tiny impulse ($|\vec{v}| = 0.05\text{ m}$) | Head length dynamically shrinks to $40\%$ of length ($0.02\text{ m}$) so shaft remains visible and head does not exceed total length. |
| 5 | VelocityVectorGizmo | Ultra-relativistic speed ($|\vec{v}| \ge 1000\text{ m/s}$) | Speed ratio clamped to $1.0$; material color clamped to full Crimson valve without color overflow. |
| 6 | ScreenRaycaster | Screen ray parallel to interaction plane ($\vec{D} \cdot \hat{n} = 0$) | Returns `null` without throwing an exception or returning `Vector3.INF`. |
| 7 | ScreenRaycaster | Screen ray cast with `camera = null` | Returns `null` safely. |
| 8 | ScreenRaycaster | Interaction plane positioned behind camera ($t < 0$) | Returns `null`; prevents spawning objects behind the observer. |
| 9 | PhysicsInteractionManager | Fast click-and-release without drag ($< 6$ pixels displacement) | Does not spawn moving entity; executes entity selection picking at anchor or spawns stationary body with $\vec{v} = \vec{0}$. |
| 10 | PhysicsInteractionManager | Right-click during active drag gesture | Cancels active drag; hides gizmo and orbit preview; leaves physical world untouched. |
| 11 | KeplerTrajectoryPreview | Radial plunge trajectory ($|\vec{h}| = |\vec{r} \times \vec{v}| < 10^{-4}$) | Clears surfaces and hides preview; prevents division by zero in semi-latus rectum $p = h^2/\mu$. |
| 12 | KeplerTrajectoryPreview | Hyperbolic trajectory ($e \ge 1.0$) | Evaluates asymptote angle $\theta_{max} = \arccos(-1/e)$; renders open hyperbola in orange-red without diverging to infinity. |
| 13 | NuclearLabTool | Max radiation particle buffer capacity reached (`MAX_RADIATION = 20000`) | Reuses inactive slots (`rad_active[i] == 0`); rejects spawn if buffer is saturated without memory reallocation or crash. |
| 14 | QuantumBenchTool | High incident energy surpassing barrier ($E > V_0$) | Analytical transmission formula switches from $\sinh^2(\kappa d)$ to $\sin^2(k' d)$ oscillatory regime. |
| 15 | ScientificProbeTool | Sample requested when physics module is unmounted | Returns default neutral telemetry (zero field, ambient temp, zero radiation) without throwing null reference error. |

---

## 7. Concrete Step-by-Step Implementation & Verification Roadmap

For the core and UI development teams implementing Phase 3 Extension:

### Phase 1: Core Interaction Engine
1. **EventBus Interoperability**: Add `func publish(event_name: String, payload: Dictionary = {})` to `res://core/event_bus.gd`.
2. **VelocityVectorGizmo**: Verify `res://core/physics/interaction/velocity_vector_gizmo.gd` passes all zero-length and vertical basis singularity tests.
3. **PhysicsInteractionManager**: Complete `res://core/physics/interaction/physics_interaction_manager.gd` with camera raycasting, drag detection, tool mode matching, and entity picking.

### Phase 2: Scientific Tools Suite (`res://modules/physics/tools/`)
4. **CelestialSpawnerTool**: Fix `add_body` parameter order; connect `KeplerTrajectoryPreview` to `NBodyGravityModule`.
5. **ParticleInjectorTool**: Implement `inject_particles` on `MolecularDynamicsModule` and wire laser cooling/heating.
6. **NuclearLabTool**: Implement radioisotope assembly spawning, neutron gun drag firing, and control rod depth slider.
7. **QuantumBenchTool**: Implement potential barrier placement, step function, double-slit geometry, and wavepacket emission.
8. **ScientificProbeTool**: Implement 3D sensor placement, rolling telemetry history, and cross-module field sampling formulas.

### Phase 3: Automated Headless Test Suite
9. Create `res://tests/test_physics_interaction_suite.gd` covering:
   - Gizmo geometry, scale, and color transitions (5 asserts).
   - Gizmo basis singularity resistance (zero, $+Y$, $-Y$) (5 asserts).
   - Screen raycaster plane intersections (5 asserts).
   - Interaction manager tool switching and event propagation (5 asserts).
   - Tool spawning and lifecycle tests across all 5 scientific tools (10 asserts).
10. Verify test suite with:
    `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`
    and execute headless test suite.
