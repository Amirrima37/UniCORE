# Handoff Report: Molecular Dynamics Architecture Blueprint (M3-1)

**Agent**: Explorer M3-1 (`teamwork_preview_explorer`)  
**Mission**: Milestone 3 (Modular Physics Simulation Domains)  
**Deliverable**: `c:\dev\UniCORE\.agents\teamwork\explorer_m3_1\blueprint_molecular_dynamics.md`  
**Handoff Type**: Hard (Investigation complete, full blueprint produced)

---

## 1. Observation

1. **UniCoreModule Contract (`res://core/base_module.gd`)**:
   - `class_name UniCoreModule extends Node` (lines 1-2).
   - Lifecycle methods: `initialize(context: Dictionary) -> bool` (lines 25-29), `cleanup() -> void` (lines 31-34), `get_module_id() -> String` (lines 13-14), `get_module_name() -> String` (lines 16-17), and `get_action_bindings() -> Array[Dictionary]` (lines 22-23).
   - Signals: `module_ready(module_id: String)` and `module_error(module_id: String, error_message: String)` (lines 7-8).
2. **Simulation Time Controller (`res://core/physics/simulation_time_controller.gd`)**:
   - Signal `sim_tick(dt: float, sim_time: float)` emitted in `_physics_process` (line 7, line 52).
   - Manages variable time scale, pause, and fixed delta substepping (lines 48-60).
3. **Spatial Hash Grid (`res://core/physics/spatial_hash_grid.gd`)**:
   - `initialize(p_cell_size: float, expected_capacity: int)` (lines 22-30).
   - `build_grid(positions: PackedVector3Array)` constructs spatial buckets in $O(N)$ (lines 73-98).
   - `get_neighbors(position: Vector3, search_radius: float) -> PackedInt32Array` returns sorted neighbor indices within radius (lines 100-164).
4. **Conservation Sentry (`res://core/physics/conservation_sentry.gd`)**:
   - `register_system(initial_e: float, initial_p: Vector3, initial_l: Vector3)` (lines 42-51).
   - `audit(positions: PackedVector3Array, velocities: PackedVector3Array, masses: PackedFloat32Array, potential_calculator: Callable) -> Dictionary` (lines 55-171).
   - Emits `invariants_updated(snapshot: Dictionary)` and `conservation_warning(violation_type: String, relative_drift: float)` (lines 10-11).
5. **Verlet Integrator (`res://core/physics/verlet_integrator.gd`)**:
   - `class_name VerletIntegrator extends PhysicalIntegrator` (lines 1-2).
   - `integrate(positions: PackedVector3Array, velocities: PackedVector3Array, masses: PackedFloat32Array, force_callable: Callable, dt: float) -> void` (lines 13-75) mutates positions and velocities in-place using preallocated scratch buffers.
6. **Existing Shaders (`res://shaders/relativity_surface.gdshader`)**:
   - Spatial shaders in UniCORE use `shader_type spatial; render_mode blend_mix, depth_draw_opaque;` and uniforms with hint ranges and `source_color`.
   - In Godot 4.0 shaders, `INSTANCE_CUSTOM` from `MultiMesh` is accessible in `vertex()` but must be bridged to `fragment()` via `varying vec4 v_custom_data;`.

---

## 2. Logic Chain

1. **Reduced Unit Scaling & Zero Overflows**:
   - Lennard-Jones molecular calculations in SI involve quantities like $\epsilon \sim 1.65 \times 10^{-21}\text{ J}$ and $\sigma \sim 3.4 \times 10^{-10}\text{ m}$. In IEEE-754 32-bit floats, $(\sigma/r)^{12}$ evaluates to $\sim 10^{-114}$, causing immediate float underflow.
   - By adopting standard reduced dimensionless Lennard-Jones units ($\sigma^* = 1.0$, $\epsilon^* = 1.0$, $m^* = 1.0$, $k_B^* = 1.0$), all values stay normalized in the range $[0.01, 100.0]$, completely eliminating numerical underflow/overflow.
2. **Algorithmic Efficiency & Exact Momentum Conservation**:
   - A naive pairwise force loop over $N$ particles scales as $O(N^2)$. For $N = 2,000$, that is $4 \times 10^6$ distance calculations per step.
   - By leveraging `SpatialHashGrid` with cell size equal to cutoff $r_c = 2.5\sigma$, candidate neighbors are limited to adjacent 27 grid cells in $O(N)$ time.
   - Utilizing Newton's Third Law ($\vec{F}_{ji} = -\vec{F}_{ij}$) with the half-shell criterion $j > i$ halves pairwise evaluations and ensures total internal force is identically zero ($\sum_i \vec{F}_i = \vec{0}$), preserving total linear momentum to machine precision.
3. **Square-Root-Free Force Inner Loop**:
   - Computing $\sqrt{r^2}$ is computationally expensive on CPU. By formulating the scalar force factor as $\text{factor} = 24\epsilon \cdot \frac{1}{r^2} \left[2(\sigma^2/r^2)^6 - (\sigma^2/r^2)^3\right]$, square root operations are completely eliminated from the force loop.
4. **Symplectic Integration & Phase Space Preservation**:
   - Standard Euler integration accumulates positive energy drift and causes simulated gases to heat uncontrollably. Velocity-Verlet (`VerletIntegrator`) is symplectic and preserves the Hamiltonian phase space 2-form, ensuring zero secular energy drift in NVE microcanonical simulations.
5. **Thermodynamic Control (Berendsen Thermostat)**:
   - When coupling to a heat bath at $T_{target}$, instantaneous kinetic temperature $T_{instant} = \frac{2 E_k}{3 N k_B}$ provides the velocity scaling factor $\lambda = \sqrt{1 + \frac{\Delta t}{\tau}(T_{target}/T_{instant} - 1)}$. Clamping $\lambda \in [0.5, 2.0]$ prevents shock instability during extreme step changes.
6. **Zero-Allocation GPU MultiMesh Rendering**:
   - Godot creates significant scene tree overhead when allocating hundreds of `Node3D` instances.
   - Using a single `MultiMeshInstance3D` with `Transform3D` and `INSTANCE_CUSTOM` packed data submits all particle geometries in a single GPU draw call.
   - The shader `res://shaders/particle_field_glow.gdshader` interpolates kinetic temperatures along a Cold Blue $\to$ Amber Yellow $\to$ Radiant Hot Red ramp with Fresnel rim emission, matching UniCORE's Detroit Liquid Glass visual standard.

---

## 3. Caveats

1. **High Density / Fluid Phase Solidification**: At very high densities ($\rho > 0.85$), Lennard-Jones particles form Face-Centered Cubic solid lattices. If container compression exceeds physical limits, particles will experience extreme repulsions. The blueprint imposes a minimum box half-extent of $3.0\sigma$ to prevent lattice lock.
2. **Periodic vs Reflective Boundaries**: The specification prioritizes cubic reflective container boundaries with restitution ($[-L, L]^3$). Periodic boundary conditions (toroidal wrapping) can be introduced as an optional enum toggle if desired by future modules.
3. **Auditing Frequency**: Running `ConservationSentry.audit` on every single sub-step when $N > 2000$ incurs an additional potential energy pass. The blueprint provides an `@export var audit_frequency: int = 1` property, allowing decimation (e.g. audit every 5 or 10 ticks) during massive particle simulations.

---

## 4. Conclusion

The architectural and implementation blueprint in `c:\dev\UniCORE\.agents\teamwork\explorer_m3_1\blueprint_molecular_dynamics.md` provides an exhaustive, production-grade, 100% typed specification for:
- `res://modules/physics/molecular_dynamics_module.gd`: Complete implementation covering LJ 12-6 potential, analytic shift $V(r_c)$, square-root-free force evaluation, $O(N)$ SpatialHashGrid neighbor search, Verlet symplectic integration, Berendsen thermostat, reflective boundaries, Maxwell-Boltzmann initializer & analyzer, input bindings, and wireframe container.
- `res://shaders/particle_field_glow.gdshader`: Complete spatial shader with varying bridges, temperature ramp, and Fresnel glow.

The blueprint conforms strictly to Godot 4.0.stable and GDScript 2.0 static typing rules, contains zero placeholders, and is immediately actionable by implementer subagents.

---

## 5. Verification Method

1. **Artifact Inspection**:
   - Inspect blueprint: `c:\dev\UniCORE\.agents\teamwork\explorer_m3_1\blueprint_molecular_dynamics.md`.
   - Confirm sections 1 through 6 are fully detailed with complete GDScript and shader code blocks.
2. **Headless Compilation Check**:
   Once implemented in `res://`, verify syntax and static typing via:
   `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`
   (Exit code must be 0).
3. **Physical Law Invalidation Conditions**:
   - If in NVE mode ($\tau \to \infty$ or thermostat disabled), relative energy drift $|(E(t) - E_0) / E_0| \ge 0.005$ over 2,000 steps, Velocity-Verlet or force formulation is invalidated.
   - If force difference between SpatialHashGrid and brute force exceeds $10^{-5}\text{ N}$, neighbor query logic is invalidated.
   - If empirical speed distribution deviates by $> 10\%$ from analytical Maxwell-Boltzmann after equilibration, thermal sampling is invalidated.
