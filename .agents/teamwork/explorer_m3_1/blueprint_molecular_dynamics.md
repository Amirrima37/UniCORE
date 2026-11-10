# UniCORE Architecture Blueprint: Molecular Dynamics Simulation Module & Particle Field Glow Shader

**Document ID**: `M3-BP-01-MD`  
**Milestone**: Milestone 3 (Modular Physics Simulation Domains)  
**Author**: Explorer M3-1 (`teamwork_preview_explorer`)  
**Target Files**:
- `res://modules/physics/molecular_dynamics_module.gd`
- `res://shaders/particle_field_glow.gdshader`  
**Compatibility**: Godot 4.0.stable (official 92bee43ad), GDScript 2.0 Strict Static Typing

---

## 1. Executive Summary & System Overview

The **Molecular Dynamics Module** (`MolecularDynamicsModule`) is UniCORE's primary computational physics module for microscopic many-body thermodynamics and fluid mechanics. It simulates thousands of interacting classical particles governed by the **Lennard-Jones 12-6 potential**, integrated through **symplectic Velocity-Verlet numerical mechanics**, accelerated via **3D Spatial Hashing (`SpatialHashGrid`)**, regulated by the **Berendsen thermostat**, audited in real time by the **Conservation Law Sentry (`ConservationSentry`)**, and rendered in a **single GPU draw call** via `MultiMeshInstance3D` using a specialized thermodynamic glow shader (`particle_field_glow.gdshader`).

### Fundamental Architectural Tenets
1. **The Scientific Observer Paradigm**: The user/camera remains in an external, inertial laboratory frame (`avatar_locomotion.gd`), immune to physical fields, thermodynamic heat, and boundary forces.
2. **Natural / Reduced Lennard-Jones Units**: Microscopic constants ($\sigma \sim 3.4\text{ \AA}$, $\epsilon \sim 1.65 \times 10^{-21}\text{ J}$, $m \sim 6.63 \times 10^{-26}\text{ kg}$) are scaled to dimensionless units ($\sigma^* = 1.0$, $\epsilon^* = 1.0$, $m^* = 1.0$, $k_B^* = 1.0$) using `UnitConverter`, guaranteeing zero IEEE-754 float underflow/overflow.
3. **Data-Oriented Zero-Allocation Performance**: All particle positions, velocities, masses, and forces are stored in contiguous `PackedVector3Array` and `PackedFloat32Array` buffers. No `Node3D` nodes are allocated per particle.
4. **Symplectic Phase-Space Preservation**: When the thermostat is disabled (Microcanonical $NVE$ ensemble), Velocity-Verlet preserves total energy and phase-space volume ($d\vec{r} \wedge d\vec{p}$) with zero secular drift.
5. **Decoupled Event-Driven Telemetry**: Thermodynamic states ($T, P, E_k, E_p, E_{total}, \text{drift}$) are published via `EventBus` and audited by `ConservationSentry`.

---

## 2. Mathematical Foundations & Numerical Formulations

### 2.1 Lennard-Jones 12-6 Potential & Analytic Shift
The interatomic potential between particles $i$ and $j$ separated by distance $r = |\vec{r}_{ij}| = |\vec{r}_i - \vec{r}_j|$ is given by:

$$V(r) = 4\epsilon \left[ \left(\frac{\sigma}{r}\right)^{12} - \left(\frac{\sigma}{r}\right)^6 \right]$$

To eliminate long-range evaluation overhead and maintain $O(N)$ complexity, interactions are truncated at cutoff radius $r_c = 2.5\sigma$. To prevent discontinuity in energy when particles cross $r_c$, the potential is shifted:

$$V_{shift}(r) = \begin{cases} V(r) - V(r_c), & r \le r_c \\ 0, & r > r_c \end{cases}$$

At cutoff $r_c = 2.5\sigma$:
$$\frac{\sigma}{r_c} = \frac{1}{2.5} = 0.4$$
$$\left(\frac{\sigma}{r_c}\right)^6 = 0.4^6 = 0.004096$$
$$\left(\frac{\sigma}{r_c}\right)^{12} = (0.004096)^2 = 1.6777216 \times 10^{-5}$$
$$V(r_c) = 4\epsilon \left[ 1.6777216 \times 10^{-5} - 0.004096 \right] = 4\epsilon (-0.0040792228) \approx -0.0163168911 \epsilon$$

### 2.2 Interatomic Force Vector Formulation
The force $\vec{F}_{ij}$ acting on particle $i$ due to particle $j$ is the negative gradient of $V(r_{ij})$ with respect to $\vec{r}_i$:

$$\vec{F}_{ij} = -\nabla_{\vec{r}_i} V(r) = -\frac{dV}{dr} \frac{\vec{r}_{ij}}{r}$$

Evaluating the derivative:
$$\frac{dV}{dr} = 4\epsilon \left[ -12 \frac{\sigma^{12}}{r^{13}} + 6 \frac{\sigma^6}{r^7} \right] = -24 \frac{\epsilon}{r} \left[ 2\left(\frac{\sigma}{r}\right)^{12} - \left(\frac{\sigma}{r}\right)^6 \right]$$

Thus:
$$\vec{F}_{ij} = 24 \frac{\epsilon}{r^2} \left[ 2\left(\frac{\sigma}{r}\right)^{12} - \left(\frac{\sigma}{r}\right)^6 \right] \vec{r}_{ij} = 24 \frac{\epsilon}{\sigma^2} \left[ 2\left(\frac{\sigma}{r}\right)^{14} - \left(\frac{\sigma}{r}\right)^8 \right] \vec{r}_{ij}$$

Where $\vec{r}_{ij} = \vec{r}_i - \vec{r}_j$.

**Sign and Physical Behavior:**
- When $r < 2^{1/6}\sigma \approx 1.12246\sigma$: The term $\left[2(\sigma/r)^{12} - (\sigma/r)^6\right] > 0$, rendering $\vec{F}_{ij}$ directed along $+\vec{r}_{ij}$ (repulsive away from $j$).
- When $r > 2^{1/6}\sigma$: The term $< 0$, rendering $\vec{F}_{ij}$ directed along $-\vec{r}_{ij}$ (attractive toward $j$).
- Newton's Third Law is exact: $\vec{F}_{ji} = -\vec{F}_{ij}$.

### 2.3 Computational Force Optimization (Square-Root-Free Inner Loop)
To maximize execution speed across thousands of particles:
1. Distance squared $r^2 = |\vec{r}_i - \vec{r}_j|^2$ is evaluated first.
2. If $r^2 \ge r_c^2$ ($6.25\sigma^2$), the pair interaction is strictly zero and skipped.
3. Singularity guard: $r^2 = \max(r^2, 0.04\sigma^2)$ preventing division by zero or float explosion if particles collide.
4. Let $s_2 = \sigma^2 / r^2$, $s_6 = s_2^3$, and $s_{12} = s_6^2$.
5. The scalar force factor is:
   $$\text{factor} = 24.0 \times \epsilon \times \frac{1}{r^2} \times \left(2.0 s_{12} - s_6\right)$$
   $$\vec{F}_{ij} = \text{factor} \times (\vec{r}_i - \vec{r}_j)$$
6. Zero square root operations are executed during force evaluation.

### 2.4 $O(N)$ Acceleration via `SpatialHashGrid`
Using `SpatialHashGrid` (`res://core/physics/spatial_hash_grid.gd`):
- Grid cell size: $d_{cell} = r_c = 2.5\sigma$.
- Prior to force calculation, `_spatial_grid.build_grid(positions)` registers all particles in $O(N)$ time.
- Pairwise traversal uses **Newton's Third Law half-shell optimization**:
  For each particle $i \in [0, N-1]$:
  Query neighbor indices $j$ from `_spatial_grid.get_neighbors(positions[i], r_c)`.
  Filter for $j > i$:
  $$\vec{F}_{ij} = \text{compute\_lj\_force}(\vec{r}_i, \vec{r}_j)$$
  $$\vec{F}_i \leftarrow \vec{F}_i + \vec{F}_{ij}$$
  $$\vec{F}_j \leftarrow \vec{F}_j - \vec{F}_{ij}$$
- Every interacting pair is evaluated **exactly once**.
- Total internal force $\sum_i \vec{F}_i = \vec{0}$ holds to IEEE-754 precision, guaranteeing linear momentum conservation.

### 2.5 Symplectic Velocity-Verlet Integration
The time evolution of positions and velocities over step $\Delta t$ follows:

$$\vec{r}(t + \Delta t) = \vec{r}(t) + \vec{v}(t)\Delta t + \frac{1}{2}\vec{a}(t)\Delta t^2$$
$$\vec{a}(t + \Delta t) = \frac{1}{m} \sum \vec{F}(\vec{r}(t + \Delta t))$$
$$\vec{v}(t + \Delta t) = \vec{v}(t) + \frac{1}{2}\left[\vec{a}(t) + \vec{a}(t + \Delta t)\right]\Delta t$$

Implemented via `VerletIntegrator` (`res://core/physics/verlet_integrator.gd`) or the module's fused symplectic stepper.

### 2.6 Berendsen Thermostat (Canonical $NVT$ Ensemble)
To simulate gas/liquid thermodynamics at an equilibrium temperature $T_{target}$, the system is coupled to a weak thermal bath.
Instantaneous kinetic temperature $T_{instant}$ for $N$ particles in 3D:

$$T_{instant} = \frac{2 E_k}{3 N k_B} = \frac{\sum_{i=1}^N m_i |\vec{v}_i|^2}{3 N k_B}$$

The Berendsen thermostat modifies particle velocities by scaling factor $\lambda$:

$$\lambda = \sqrt{1 + \frac{\Delta t}{\tau} \left(\frac{T_{target}}{T_{instant}} - 1\right)}$$

$$\vec{v}_i \leftarrow \lambda \vec{v}_i \quad \forall i \in [0, N-1]$$

Where:
- $\tau$ is the coupling time constant (default $\tau = 0.2\text{ s}$).
- $\Delta t$ is the simulation time step.
- Safeguards:
  - If $T_{instant} < 10^{-9}$, $T_{instant}$ is clamped to $10^{-9}$.
  - The radicand is clamped to $\max(\text{arg}, 0.0)$.
  - Velocity scaling $\lambda$ is clamped to $[0.5, 2.0]$ per step to prevent shock spikes during extreme temperature adjustments.

### 2.7 Cubic Reflective Boundary Container & Elasticity
The particles are confined to a 3D box $[-L_x, L_x] \times [-L_y, L_y] \times [-L_z, L_z]$ (default $L = 10.0\sigma$).
Taking finite particle radius $R_p = 0.2\sigma$ into account, the effective boundary for particle centers is $W_k = L_k - R_p$.
Upon contact with boundary wall $W_k$:
- If $r_k > W_k$:
  $$r_k \leftarrow W_k - (r_k - W_k) \cdot e$$
  $$v_k \leftarrow -v_k \cdot e$$
- If $r_k < -W_k$:
  $$r_k \leftarrow -W_k + (-W_k - r_k) \cdot e$$
  $$v_k \leftarrow -v_k \cdot e$$
- Where $e \in (0, 1]$ is the restitution coefficient ($e = 1.0$ for purely elastic walls).
- Dynamic compression (`KEY_P`): $L \leftarrow \max(L \cdot 0.95, 3.0\sigma)$, decreasing container volume $V$ and increasing density $\rho = N / V$ and pressure $P$.

### 2.8 Maxwell-Boltzmann Speed Distribution Initializer & Analyzer
In 3D thermal equilibrium at temperature $T$, velocity components follow Gaussian distributions $v_k \sim \mathcal{N}(0, \sigma_v^2)$ with variance $\sigma_v^2 = \frac{k_B T}{m}$.
The speed magnitude $v = |\vec{v}|$ follows the Maxwell-Boltzmann probability density function:

$$f(v) = 4\pi \left(\frac{m}{2\pi k_B T}\right)^{3/2} v^2 \exp\left(-\frac{m v^2}{2 k_B T}\right)$$

Key statistical speeds:
- Most probable speed: $v_{mp} = \sqrt{\frac{2 k_B T}{m}}$
- Mean speed: $\langle v \rangle = \sqrt{\frac{8 k_B T}{\pi m}} \approx 1.5958 \sqrt{\frac{k_B T}{m}}$
- Root-mean-square speed: $v_{rms} = \sqrt{\frac{3 k_B T}{m}} \approx 1.7321 \sqrt{\frac{k_B T}{m}}$

**Initializer Algorithm:**
1. Generate Cartesian components using the Box-Muller transform:
   $$z_0 = \sqrt{-2\ln u_1}\cos(2\pi u_2), \quad z_1 = \sqrt{-2\ln u_1}\sin(2\pi u_2)$$
   $$v_x = \sigma_v z_0, \quad v_y = \sigma_v z_1, \quad v_z = \sigma_v z_2$$
2. Compute center of mass velocity $\vec{v}_{cm} = \frac{1}{\sum m_i} \sum m_i \vec{v}_i$ and subtract $\vec{v}_i \leftarrow \vec{v}_i - \vec{v}_{cm}$ (eliminating net momentum drift).
3. Rescale velocities by $\sqrt{T_{target} / T_{instant}}$ to establish exact initial temperature.

**Statistical Analyzer:**
Method `compute_velocity_distribution(num_bins: int, max_speed: float)` generates normalized empirical histograms alongside theoretical $f(v)$ curves for automated test verification and UI graphing.

### 2.9 Initial Spatial Lattice Placement
To avoid particle overlaps ($r \to 0$) that would cause infinite repulsive forces on step 1, particles are initialized on a Simple Cubic lattice inside $[-0.75L, 0.75L]^3$ with lattice spacing $a \ge 1.15\sigma$ (near the Lennard-Jones potential minimum $r_{min} = 2^{1/6}\sigma \approx 1.122\sigma$). A small random jitter ($\pm 0.02\sigma$) is applied to break artificial symmetry while maintaining minimum spacing $d > 0.95\sigma$.

---

## 3. Architecture & Interface Contract

```
┌────────────────────────────────────────────────────────────────────────┐
│                        SimulationTimeController                        │
│                 emits sim_tick(dt: float, sim_time: float)             │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        MolecularDynamicsModule                         │
│                      (extends UniCoreModule)                           │
│  ┌────────────────────────┐  ┌────────────────┐  ┌──────────────────┐  │
│  │    SpatialHashGrid     │  │VerletIntegrator│  │ConservationSentry│  │
│  │ (O(N) neighbor lookup) │  │  (Symplectic)  │  │(Noether Invariants│ │
│  └────────────────────────┘  └────────────────┘  └──────────────────┘  │
│                                   │                                    │
│  ┌────────────────────────────────┴─────────────────────────────────┐  │
│  │ MultiMeshInstance3D (1 draw call, SphereMesh, Instanced Custom) │  │
│  └────────────────────────────────┬─────────────────────────────────┘  │
└───────────────────────────────────┼────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                       particle_field_glow.gdshader                     │
│        (Kinetic temperature gradient: Blue -> Amber -> Hot Red)        │
└────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Class Definition & File Path
- Class: `MolecularDynamicsModule`
- Extends: `UniCoreModule`
- File: `res://modules/physics/molecular_dynamics_module.gd`

### 3.2 Exported & Configurable Properties
| Property | Type | Default | Description |
|---|---|---|---|
| `particle_count` | `int` | `500` | Number of simulated Lennard-Jones particles |
| `sigma` | `float` | `1.0` | LJ distance parameter $\sigma$ |
| `epsilon` | `float` | `1.0` | LJ potential well depth $\epsilon$ |
| `particle_mass` | `float` | `1.0` | Mass of individual particle $m$ |
| `particle_radius` | `float` | `0.2` | Visual and collision radius $R_p$ |
| `cutoff_radius` | `float` | `2.5` | Truncation cutoff $r_c = 2.5\sigma$ |
| `box_half_extent` | `Vector3` | `Vector3(10, 10, 10)` | Half dimensions of cubic container $L$ |
| `restitution` | `float` | `1.0` | Wall collision elasticity coefficient $e$ |
| `target_temperature`| `float` | `1.0` | Thermostat equilibrium temperature $T_{target}$ |
| `thermostat_tau` | `float` | `0.2` | Berendsen thermostat coupling constant $\tau$ |
| `thermostat_enabled`| `bool` | `true` | Enables NVT (true) or NVE (false) ensemble |
| `audit_frequency` | `int` | `1` | Frequency (in ticks) of ConservationSentry audits |

### 3.3 Action Bindings (InputMapper Integration)
| Action ID | Key Code | Label | Description |
|---|---|---|---|
| `md_heat_up` | `KEY_UP` | `MD: Нагреть газ (+Temp)` | Increases $T_{target}$ by $+0.2$ |
| `md_cool_down` | `KEY_DOWN` | `MD: Охладить газ (-Temp)` | Decreases $T_{target}$ by $-0.2$ (min $0.1$) |
| `md_compress_box` | `KEY_P` | `MD: Сжать контейнер` | Compresses container by $5\%$ ($L \leftarrow 0.95L$) |

---

## 4. Production-Grade GDScript Implementation Blueprint

Below is the complete implementation for `res://modules/physics/molecular_dynamics_module.gd`.

```gdscript
class_name MolecularDynamicsModule
extends UniCoreModule

## Molecular Dynamics Simulation Module for UniCORE.
## Implements Lennard-Jones 12-6 pairwise interactions, SpatialHashGrid acceleration,
## Velocity-Verlet symplectic integration, Berendsen thermostat, reflective cubic boundaries,
## Maxwell-Boltzmann distribution, and single MultiMeshInstance3D GPU rendering.

# --- Physical Constants & Parameters ---
@export_group("Lennard-Jones Parameters")
@export var particle_count: int = 500
@export var sigma: float = 1.0
@export var epsilon: float = 1.0
@export var particle_mass: float = 1.0
@export var particle_radius: float = 0.2
@export var cutoff_radius: float = 2.5

@export_group("Thermodynamics & Boundaries")
@export var box_half_extent: Vector3 = Vector3(10.0, 10.0, 10.0)
@export var restitution: float = 1.0
@export var target_temperature: float = 1.0
@export var thermostat_tau: float = 0.2
@export var thermostat_enabled: bool = true
@export var boltzmann_constant: float = 1.0

@export_group("Engine Integration")
@export var audit_frequency: int = 1
@export var speed_scale_visual: float = 3.0

# --- State Buffers (Contiguous Packed Arrays) ---
var _positions: PackedVector3Array = PackedVector3Array()
var _velocities: PackedVector3Array = PackedVector3Array()
var _masses: PackedFloat32Array = PackedFloat32Array()
var _forces: PackedVector3Array = PackedVector3Array()

# --- Precalculated Lennard-Jones Constants ---
var _sigma_sq: float = 1.0
var _cutoff_sq: float = 6.25
var _potential_shift: float = 0.0 # V(r_c)

# --- Subsystem References ---
var _spatial_grid: SpatialHashGrid = null
var _integrator: VerletIntegrator = null
var _sentry: ConservationSentry = null
var _time_controller: SimulationTimeController = null
var _event_bus: Node = null

# --- Visual Nodes ---
var _multimesh_instance: MultiMeshInstance3D = null
var _multimesh: MultiMesh = null
var _container_mesh_instance: MeshInstance3D = null
var _particle_shader_material: ShaderMaterial = null

# --- Internal Bookkeeping ---
var _step_counter: int = 0
var _force_callable: Callable = Callable()
var _potential_callable: Callable = Callable()

# ==============================================================================
# 1. UniCoreModule Contract
# ==============================================================================

func get_module_id() -> String:
	return "molecular_dynamics"

func get_module_name() -> String:
	return "Молекулярная динамика (Lennard-Jones)"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{
			"action": "md_heat_up",
			"label": "MD: Нагреть газ (+Temp)",
			"default_key": KEY_UP,
			"description": "Повысить целевую температуру термостата Берендсена"
		},
		{
			"action": "md_cool_down",
			"label": "MD: Охладить газ (-Temp)",
			"default_key": KEY_DOWN,
			"description": "Понизить целевую температуру термостата Берендсена"
		},
		{
			"action": "md_compress_box",
			"label": "MD: Сжать контейнер",
			"default_key": KEY_P,
			"description": "Уменьшить объем контейнера (повышение плотности и давления)"
		}
	]

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	
	# Cache precomputed potential shift and squared cutoffs
	_update_lj_constants()
	
	# 1. Initialize Subsystems
	_spatial_grid = SpatialHashGrid.new()
	_spatial_grid.initialize(cutoff_radius, particle_count * 2)
	
	_integrator = VerletIntegrator.new()
	_force_callable = Callable(self, "compute_forces")
	_potential_callable = Callable(self, "compute_potential_energy")
	
	# 2. Extract or Instantiate ConservationSentry
	if context.has("conservation_sentry") and context["conservation_sentry"] is ConservationSentry:
		_sentry = context["conservation_sentry"] as ConservationSentry
	else:
		_sentry = ConservationSentry.new()
		_sentry.name = "MD_ConservationSentry"
		_sentry.boltzmann_constant = boltzmann_constant
		add_child(_sentry)
	
	# 3. Extract or Connect SimulationTimeController
	if context.has("time_controller") and context["time_controller"] is SimulationTimeController:
		_time_controller = context["time_controller"] as SimulationTimeController
		_time_controller.sim_tick.connect(_on_sim_tick)
	elif get_tree() and get_tree().root.has_node("SimulationTimeController"):
		_time_controller = get_tree().root.get_node("SimulationTimeController") as SimulationTimeController
		_time_controller.sim_tick.connect(_on_sim_tick)
	
	# 4. Extract EventBus
	if context.has("event_bus") and context["event_bus"] is Node:
		_event_bus = context["event_bus"] as Node
	
	# 5. Build GPU MultiMesh Rendering Pipeline
	_setup_multimesh_renderer()
	
	# 6. Build Boundary Visualizer
	_setup_container_visual()
	
	# 7. Reset & Initialize Physical Particle Ensemble
	reset_simulation()
	
	return true

func cleanup() -> void:
	if _time_controller and is_instance_valid(_time_controller):
		var callable := Callable(self, "_on_sim_tick")
		if _time_controller.sim_tick.is_connected(callable):
			_time_controller.sim_tick.disconnect(callable)
	
	if _multimesh_instance and is_instance_valid(_multimesh_instance):
		_multimesh_instance.queue_free()
	
	if _container_mesh_instance and is_instance_valid(_container_mesh_instance):
		_container_mesh_instance.queue_free()
	
	if _integrator:
		_integrator.clear_buffers()
	
	if _spatial_grid:
		_spatial_grid.clear()
	
	_positions.clear()
	_velocities.clear()
	_masses.clear()
	_forces.clear()
	
	super.cleanup()

# ==============================================================================
# 2. Simulation Lifecycle & Particle Initialization
# ==============================================================================

func _update_lj_constants() -> void:
	_sigma_sq = sigma * sigma
	_cutoff_sq = cutoff_radius * cutoff_radius
	
	# Compute shift V(r_c) = 4*epsilon * ((sigma/r_c)^12 - (sigma/r_c)^6)
	var sr2: float = _sigma_sq / _cutoff_sq
	var sr6: float = sr2 * sr2 * sr2
	var sr12: float = sr6 * sr6
	_potential_shift = 4.0 * epsilon * (sr12 - sr6)

func reset_simulation() -> void:
	if particle_count <= 0:
		return
	
	_update_lj_constants()
	
	# Allocate packed particle buffers
	_positions.resize(particle_count)
	_velocities.resize(particle_count)
	_masses.resize(particle_count)
	_forces.resize(particle_count)
	
	for i in range(particle_count):
		_masses[i] = particle_mass
		_forces[i] = Vector3.ZERO
	
	# 1. Place particles on uniform lattice to guarantee overlap-free initial state
	_initialize_lattice_positions()
	
	# 2. Sample velocities from Maxwell-Boltzmann distribution
	_initialize_maxwell_boltzmann_velocities()
	
	# 3. Synchronize MultiMesh instance count and initial transforms
	if _multimesh:
		_multimesh.instance_count = particle_count
		update_multimesh_visuals()
	
	# 4. Register initial physical state with ConservationSentry
	if _sentry:
		_sentry.reset()
		var initial_ek: float = 0.0
		for i in range(particle_count):
			initial_ek += 0.5 * _masses[i] * _velocities[i].length_squared()
		var initial_ep: float = compute_potential_energy(_positions)
		_sentry.register_system(initial_ek + initial_ep)

func _initialize_lattice_positions() -> void:
	var n: int = particle_count
	var side: int = int(ceil(pow(float(n), 1.0 / 3.0)))
	var spacing: float = 1.25 * sigma
	var half_span: float = float(side - 1) * spacing * 0.5
	
	var idx: int = 0
	for ix in range(side):
		for iy in range(side):
			for iz in range(side):
				if idx >= n:
					break
				var pos := Vector3(
					float(ix) * spacing - half_span,
					float(iy) * spacing - half_span,
					float(iz) * spacing - half_span
				)
				# Tiny jitter to break symmetry without causing overlaps
				var jitter := Vector3(
					randf_range(-0.02, 0.02),
					randf_range(-0.02, 0.02),
					randf_range(-0.02, 0.02)
				) * sigma
				_positions[idx] = pos + jitter
				idx += 1
			if idx >= n:
				break
		if idx >= n:
			break

func _initialize_maxwell_boltzmann_velocities() -> void:
	var n: int = particle_count
	var kb: float = boltzmann_constant if boltzmann_constant > 0.0 else 1.0
	var sigma_v: float = sqrt(kb * target_temperature / maxf(particle_mass, 1e-9))
	var total_p := Vector3.ZERO
	
	# Box-Muller Gaussian sampling for independent Cartesian components
	for i in range(n):
		var u1: float = maxf(randf(), 1e-12)
		var u2: float = randf()
		var u3: float = maxf(randf(), 1e-12)
		var u4: float = randf()
		
		var r1: float = sqrt(-2.0 * log(u1))
		var theta1: float = 2.0 * PI * u2
		var z0: float = r1 * cos(theta1)
		var z1: float = r1 * sin(theta1)
		
		var r2: float = sqrt(-2.0 * log(u3))
		var theta2: float = 2.0 * PI * u4
		var z2: float = r2 * cos(theta2)
		
		var v := Vector3(z0 * sigma_v, z1 * sigma_v, z2 * sigma_v)
		_velocities[i] = v
		total_p += v * particle_mass
	
	# Eliminate center-of-mass momentum drift
	var v_cm: Vector3 = total_p / (float(n) * particle_mass)
	for i in range(n):
		_velocities[i] -= v_cm
	
	# Rescale to match exact target temperature
	var current_t: float = compute_instantaneous_temperature()
	if current_t > 1e-9:
		var scale: float = sqrt(target_temperature / current_t)
		for i in range(n):
			_velocities[i] *= scale

# ==============================================================================
# 3. Physics Integration & Core Step
# ==============================================================================

func _on_sim_tick(dt: float, _sim_time: float) -> void:
	step(dt)

func step(dt: float) -> void:
	if not is_initialized or _positions.is_empty() or dt <= 0.0:
		return
	
	# 1. Symplectic Velocity-Verlet Integration
	_integrator.integrate(_positions, _velocities, _masses, _force_callable, dt)
	
	# 2. Reflective Cubic Container Boundaries
	enforce_boundaries()
	
	# 3. Berendsen Thermostat (NVT regulation)
	if thermostat_enabled:
		apply_berendsen_thermostat(dt)
	
	# 4. Update GPU MultiMesh Transforms and Glow Colors
	update_multimesh_visuals()
	
	# 5. Invariant Auditing via ConservationSentry
	_step_counter += 1
	if _sentry and (_step_counter % audit_frequency == 0):
		var snapshot: Dictionary = _sentry.audit(
			_positions,
			_velocities,
			_masses,
			_potential_callable
		)
		if _event_bus and not snapshot.is_empty():
			_event_bus.emit("md_telemetry_updated", snapshot)

# ==============================================================================
# 4. Force & Potential Calculations (Lennard-Jones + Spatial Hash)
# ==============================================================================

func compute_forces(pos: PackedVector3Array) -> PackedVector3Array:
	var n: int = pos.size()
	if n == 0:
		return PackedVector3Array()
	
	if _forces.size() != n:
		_forces.resize(n)
	for i in range(n):
		_forces[i] = Vector3.ZERO
	
	# Build 3D spatial hash grid in O(N)
	_spatial_grid.build_grid(pos)
	
	var eps24: float = 24.0 * epsilon
	var sig2: float = _sigma_sq
	var rc_sq: float = _cutoff_sq
	var min_r_sq: float = 0.04 * sig2 # Overlap clamp
	
	# Half-shell pairwise loop: Newton's Third Law (F_ji = -F_ij)
	for i in range(n):
		var pos_i: Vector3 = pos[i]
		var neighbors: PackedInt32Array = _spatial_grid.get_neighbors(pos_i, cutoff_radius)
		var n_neighbors: int = neighbors.size()
		
		for k in range(n_neighbors):
			var j: int = neighbors[k]
			if j > i: # Pair visited exactly once
				var r_vec: Vector3 = pos_i - pos[j]
				var r_sq: float = r_vec.length_squared()
				
				if r_sq < rc_sq:
					r_sq = maxf(r_sq, min_r_sq)
					var inv_r2: float = 1.0 / r_sq
					var sr2: float = sig2 * inv_r2
					var sr6: float = sr2 * sr2 * sr2
					var sr12: float = sr6 * sr6
					
					var factor: float = eps24 * inv_r2 * (2.0 * sr12 - sr6)
					var f_ij: Vector3 = r_vec * factor
					
					_forces[i] += f_ij
					_forces[j] -= f_ij
	
	return _forces

func compute_potential_energy(pos: PackedVector3Array) -> float:
	var n: int = pos.size()
	if n == 0:
		return 0.0
	
	_spatial_grid.build_grid(pos)
	
	var total_v: float = 0.0
	var eps4: float = 4.0 * epsilon
	var sig2: float = _sigma_sq
	var rc_sq: float = _cutoff_sq
	var shift: float = _potential_shift
	var min_r_sq: float = 0.04 * sig2
	
	for i in range(n):
		var pos_i: Vector3 = pos[i]
		var neighbors: PackedInt32Array = _spatial_grid.get_neighbors(pos_i, cutoff_radius)
		var n_neighbors: int = neighbors.size()
		
		for k in range(n_neighbors):
			var j: int = neighbors[k]
			if j > i:
				var r_sq: float = pos_i.distance_squared_to(pos[j])
				if r_sq < rc_sq:
					r_sq = maxf(r_sq, min_r_sq)
					var inv_r2: float = 1.0 / r_sq
					var sr2: float = sig2 * inv_r2
					var sr6: float = sr2 * sr2 * sr2
					var sr12: float = sr6 * sr6
					
					var v_shift: float = eps4 * (sr12 - sr6) - shift
					total_v += v_shift
	
	return total_v

# ==============================================================================
# 5. Thermodynamics & Berendsen Thermostat
# ==============================================================================

func compute_instantaneous_temperature() -> float:
	var n: int = _velocities.size()
	if n == 0:
		return 0.0
	var total_ek: float = 0.0
	for i in range(n):
		total_ek += 0.5 * _masses[i] * _velocities[i].length_squared()
	var kb: float = boltzmann_constant if boltzmann_constant > 0.0 else 1.0
	return (2.0 * total_ek) / (3.0 * float(n) * kb)

func apply_berendsen_thermostat(dt: float) -> float:
	var n: int = _velocities.size()
	if n == 0 or dt <= 0.0:
		return 1.0
	
	var t_inst: float = compute_instantaneous_temperature()
	if t_inst < 1e-9:
		t_inst = 1e-9
	
	var tau: float = maxf(thermostat_tau, 1e-4)
	var factor: float = 1.0 + (dt / tau) * ((target_temperature / t_inst) - 1.0)
	var lambda_scale: float = sqrt(maxf(factor, 0.0))
	
	# Clamp velocity multiplier to prevent numerical shock waves
	lambda_scale = clampf(lambda_scale, 0.5, 2.0)
	
	for i in range(n):
		_velocities[i] *= lambda_scale
	
	return lambda_scale

func heat_up(delta_temp: float = 0.2) -> void:
	target_temperature += delta_temp
	if _event_bus:
		_event_bus.emit("md_target_temp_changed", {"target_temperature": target_temperature})

func cool_down(delta_temp: float = 0.2) -> void:
	target_temperature = maxf(target_temperature - delta_temp, 0.05)
	if _event_bus:
		_event_bus.emit("md_target_temp_changed", {"target_temperature": target_temperature})

# ==============================================================================
# 6. Container Boundaries & Compression
# ==============================================================================

func enforce_boundaries() -> void:
	var n: int = _positions.size()
	var eff_box: Vector3 = box_half_extent - Vector3(particle_radius, particle_radius, particle_radius)
	var e: float = clampf(restitution, 0.0, 1.0)
	
	for i in range(n):
		var pos: Vector3 = _positions[i]
		var vel: Vector3 = _velocities[i]
		
		# Axis X
		if pos.x > eff_box.x:
			pos.x = eff_box.x - (pos.x - eff_box.x) * e
			vel.x = -vel.x * e
		elif pos.x < -eff_box.x:
			pos.x = -eff_box.x + (-eff_box.x - pos.x) * e
			vel.x = -vel.x * e
		
		# Axis Y
		if pos.y > eff_box.y:
			pos.y = eff_box.y - (pos.y - eff_box.y) * e
			vel.y = -vel.y * e
		elif pos.y < -eff_box.y:
			pos.y = -eff_box.y + (-eff_box.y - pos.y) * e
			vel.y = -vel.y * e
		
		# Axis Z
		if pos.z > eff_box.z:
			pos.z = eff_box.z - (pos.z - eff_box.z) * e
			vel.z = -vel.z * e
		elif pos.z < -eff_box.z:
			pos.z = -eff_box.z + (-eff_box.z - pos.z) * e
			vel.z = -vel.z * e
		
		# Final clamping safeguard
		pos.x = clampf(pos.x, -eff_box.x, eff_box.x)
		pos.y = clampf(pos.y, -eff_box.y, eff_box.y)
		pos.z = clampf(pos.z, -eff_box.z, eff_box.z)
		
		_positions[i] = pos
		_velocities[i] = vel

func compress_container(scale_factor: float = 0.95) -> void:
	var target_box: Vector3 = box_half_extent * scale_factor
	var min_dim: float = 3.0 * sigma
	target_box.x = maxf(target_box.x, min_dim)
	target_box.y = maxf(target_box.y, min_dim)
	target_box.z = maxf(target_box.z, min_dim)
	
	box_half_extent = target_box
	enforce_boundaries()
	_update_container_mesh()
	
	if _event_bus:
		_event_bus.emit("md_container_compressed", {"box_half_extent": box_half_extent})

# ==============================================================================
# 7. Maxwell-Boltzmann Speed Distribution Analysis
# ==============================================================================

func compute_velocity_distribution(num_bins: int = 20, max_speed: float = 0.0) -> Dictionary:
	var n: int = _velocities.size()
	if n == 0 or num_bins <= 0:
		return {}
	
	var speeds := PackedFloat32Array()
	speeds.resize(n)
	var max_v: float = 0.0
	var sum_v: float = 0.0
	var sum_v2: float = 0.0
	
	for i in range(n):
		var spd: float = _velocities[i].length()
		speeds[i] = spd
		max_v = maxf(max_v, spd)
		sum_v += spd
		sum_v2 += spd * spd
	
	if max_speed <= 0.0:
		max_speed = maxf(max_v * 1.15, 1.0)
	
	var bin_width: float = max_speed / float(num_bins)
	var counts := PackedInt32Array()
	counts.resize(num_bins)
	
	for i in range(n):
		var b: int = int(floor(speeds[i] / bin_width))
		b = clampi(b, 0, num_bins - 1)
		counts[b] += 1
	
	var bin_centers := PackedFloat32Array()
	bin_centers.resize(num_bins)
	var empirical_pdf := PackedFloat32Array()
	empirical_pdf.resize(num_bins)
	var theoretical_pdf := PackedFloat32Array()
	theoretical_pdf.resize(num_bins)
	
	var temp: float = compute_instantaneous_temperature()
	var kb: float = boltzmann_constant if boltzmann_constant > 0.0 else 1.0
	var m: float = particle_mass
	
	# Analytical prefactor 4*PI * (m / (2*PI*kb*T))^(3/2)
	var prefactor: float = 0.0
	if temp > 1e-6:
		var beta: float = m / (2.0 * PI * kb * temp)
		prefactor = 4.0 * PI * pow(beta, 1.5)
	
	var norm: float = 1.0 / (float(n) * bin_width)
	for b in range(num_bins):
		var v_c: float = (float(b) + 0.5) * bin_width
		bin_centers[b] = v_c
		empirical_pdf[b] = float(counts[b]) * norm
		if temp > 1e-6:
			var exponent: float = -(m * v_c * v_c) / (2.0 * kb * temp)
			theoretical_pdf[b] = prefactor * v_c * v_c * exp(exponent)
		else:
			theoretical_pdf[b] = 0.0
	
	var mean_spd: float = sum_v / float(n)
	var rms_spd: float = sqrt(sum_v2 / float(n))
	var mp_spd: float = sqrt(2.0 * kb * temp / m) if temp > 1e-6 else 0.0
	
	return {
		"bin_centers": bin_centers,
		"empirical_pdf": empirical_pdf,
		"theoretical_pdf": theoretical_pdf,
		"bin_width": bin_width,
		"mean_speed": mean_spd,
		"rms_speed": rms_spd,
		"most_probable_speed": mp_spd,
		"temperature": temp,
		"particle_count": n
	}

# ==============================================================================
# 8. GPU MultiMesh Rendering Pipeline & Container Visualizer
# ==============================================================================

func _setup_multimesh_renderer() -> void:
	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.name = "ParticleMultiMeshInstance"
	
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	
	var sphere := SphereMesh.new()
	sphere.radius = particle_radius
	sphere.height = particle_radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	
	# Load or construct specialized particle glow shader material
	var shader := load("res://shaders/particle_field_glow.gdshader") as Shader
	if shader:
		_particle_shader_material = ShaderMaterial.new()
		_particle_shader_material.shader = shader
		sphere.material = _particle_shader_material
	else:
		# Fallback standard material if shader not loaded yet
		var std_mat := StandardMaterial3D.new()
		std_mat.albedo_color = Color(0.2, 0.6, 1.0)
		std_mat.emission_enabled = true
		std_mat.emission = Color(0.1, 0.4, 0.9)
		sphere.material = std_mat
	
	_multimesh.mesh = sphere
	_multimesh_instance.multimesh = _multimesh
	add_child(_multimesh_instance)

func update_multimesh_visuals() -> void:
	if not _multimesh or _positions.is_empty():
		return
	
	var n: int = _positions.size()
	var spd_scale: float = speed_scale_visual if speed_scale_visual > 0.0 else 3.0
	
	for i in range(n):
		var pos: Vector3 = _positions[i]
		var vel: Vector3 = _velocities[i]
		var spd: float = vel.length()
		var t_norm: float = clampf(spd / spd_scale, 0.0, 1.0)
		
		# Set instance transform in laboratory frame
		_multimesh.set_instance_transform(i, Transform3D(Basis(), pos))
		
		# Set instance custom data: r=normalized_speed, g=raw_speed, b=kinetic_energy, a=mass
		var e_k: float = 0.5 * _masses[i] * spd * spd
		_multimesh.set_instance_custom_data(i, Color(t_norm, spd, e_k, _masses[i]))
		
		# Set instance vertex color fallback (smooth cold-blue to warm-red)
		var col: Color = Color(t_norm, 0.5 * (1.0 - t_norm), 1.0 - t_norm, 1.0)
		_multimesh.set_instance_color(i, col)

func _setup_container_visual() -> void:
	_container_mesh_instance = MeshInstance3D.new()
	_container_mesh_instance.name = "ContainerBoundaryWireframe"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_container_mesh_instance.material_override = mat
	add_child(_container_mesh_instance)
	_update_container_mesh()

func _update_container_mesh() -> void:
	if not _container_mesh_instance:
		return
	
	var im: ImmediateMesh = _container_mesh_instance.mesh as ImmediateMesh
	if im == null:
		im = ImmediateMesh.new()
		_container_mesh_instance.mesh = im
	
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var b: Vector3 = box_half_extent
	
	# Bottom 4 edges (-Y)
	im.surface_add_vertex(Vector3(-b.x, -b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x, -b.y, -b.z))
	
	# Top 4 edges (+Y)
	im.surface_add_vertex(Vector3(-b.x,  b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y,  b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x,  b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x,  b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x,  b.y, -b.z))
	
	# Vertical 4 pillars
	im.surface_add_vertex(Vector3(-b.x, -b.y, -b.z))
	im.surface_add_vertex(Vector3(-b.x,  b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y, -b.z))
	im.surface_add_vertex(Vector3( b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3( b.x,  b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x, -b.y,  b.z))
	im.surface_add_vertex(Vector3(-b.x,  b.y,  b.z))
	
	im.surface_end()

# ==============================================================================
# 9. Input & Interactive Control
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized:
		return
	
	if event.is_action_pressed("md_heat_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_UP):
		heat_up(0.2)
	elif event.is_action_pressed("md_cool_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_DOWN):
		cool_down(0.2)
	elif event.is_action_pressed("md_compress_box") or (event is InputEventKey and event.pressed and event.keycode == KEY_P):
		compress_container(0.95)
```

---

## 5. Production-Grade Shader Implementation Blueprint

Below is the complete implementation for `res://shaders/particle_field_glow.gdshader`.

```glsl
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// =============================================================================
// UniCORE Particle Field Glow Shader
// Milestone 3: Modular Physics Simulation Domains
// Visualizes particle kinetic energy/temperature gradient with incandescent glow
// and Fresnel rim radiance in the Detroit Liquid Glass visual aesthetic.
// =============================================================================

// Thermodynamic Spectral Colors
uniform vec4 cold_color : source_color = vec4(0.08, 0.45, 1.0, 1.0);     // Cold cyan-blue
uniform vec4 medium_color : source_color = vec4(1.0, 0.82, 0.12, 1.0);   // Thermal amber-yellow
uniform vec4 hot_color : source_color = vec4(1.0, 0.15, 0.05, 1.0);      // High-energy radiant red

// Lighting & Shading Uniforms
uniform float emission_intensity : hint_range(0.0, 10.0) = 2.5;
uniform float glow_falloff : hint_range(0.5, 8.0) = 2.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.25;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform bool enable_billboard = false;

// Varying bridge between vertex instance data and fragment shader
varying vec4 v_custom_data;

void vertex() {
	// Bridge MultiMesh INSTANCE_CUSTOM to fragment stage
	v_custom_data = INSTANCE_CUSTOM;
	
	if (enable_billboard) {
		// Spherical billboard preserving model scaling
		mat4 billboard_matrix = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0],
			INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]
		);
		MODELVIEW_MATRIX = billboard_matrix;
	}
}

vec3 evaluate_temperature_ramp(float t) {
	float s = clamp(t, 0.0, 1.0);
	if (s < 0.5) {
		// Low to medium temperature transition (Cold Blue -> Warm Amber)
		return mix(cold_color.rgb, medium_color.rgb, s * 2.0);
	} else {
		// Medium to high temperature transition (Warm Amber -> Radiant Hot Red)
		return mix(medium_color.rgb, hot_color.rgb, (s - 0.5) * 2.0);
	}
}

void fragment() {
	// Extract normalized kinetic temperature/speed parameter t
	float t = 0.0;
	if (v_custom_data.a > 0.0) {
		// Reading normalized speed from INSTANCE_CUSTOM.r
		t = clamp(v_custom_data.r, 0.0, 1.0);
	} else if (COLOR.a > 0.0) {
		// Fallback to vertex COLOR.r attribute
		t = clamp(COLOR.r, 0.0, 1.0);
	}
	
	vec3 base_color = evaluate_temperature_ramp(t);
	
	// Fresnel rim glow calculation for Detroit Liquid Glass aesthetic
	float n_dot_v = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - n_dot_v, glow_falloff);
	
	ALBEDO = base_color * 0.75;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	// HDR Incandescent Glow: core emission + intense rim edge radiance
	EMISSION = base_color * emission_intensity * (0.8 + rim * 3.2);
}
```

---

## 6. Verification & Automated Test Strategy

To guarantee numerical and algorithmic compliance with UniCORE's acceptance criteria, the following tests must be implemented in `res://tests/test_physics_engine_suite.gd`:

### Test 1: Isolated 2-Particle Lennard-Jones Energy Conservation (NVE)
- Place two particles along the X-axis separated by $r = 1.15\sigma$ ($E_p \approx -\epsilon$) with small initial velocities directed opposite to each other.
- Disable thermostat (`thermostat_enabled = false`).
- Integrate for 2,000 steps under `VerletIntegrator`.
- **Assertion**: Total energy drift $|(E(t) - E_0) / E_0| < 0.001$ over 2,000 steps without secular drift.

### Test 2: SpatialHashGrid Acceleration Parity ($O(N)$ vs $O(N^2)$)
- Scatter 1,000 random particles inside a box.
- Compute forces using `SpatialHashGrid` half-shell iteration.
- Compute forces using naive brute-force $O(N^2)$ double loop.
- **Assertion**: Maximum absolute force difference across all components $|\vec{F}_{grid} - \vec{F}_{brute}| < 10^{-5}\text{ N}$.

### Test 3: Berendsen Thermostat Exponential Relaxation
- Initialize 300 particles at initial temperature $T_0 = 0.5$.
- Set `target_temperature = 2.0` and `thermostat_tau = 0.2`.
- Step the simulation for 100 steps with $\Delta t = 0.01$.
- Verify that temperature approaches $T_{target}$ following $\frac{dT}{dt} \approx \frac{T_{target} - T}{\tau}$.
- **Assertion**: $|T(t) - T_{target}| < 0.15$ after $5\tau$ duration.

### Test 4: Elastic Container Boundary Reflection
- Fire a particle at velocity $(5.0, 0, 0)$ towards the $+X$ wall with $e = 1.0$.
- Step across the boundary collision.
- **Assertion**: $v_x \to -5.0 \pm 10^{-4}$ and position remains within $[-L_x + R_p, L_x - R_p]$.

### Test 5: Maxwell-Boltzmann Velocity Distribution Convergence
- Allow 500 particles to equilibrate under the thermostat at $T = 1.0$ for 500 steps.
- Query `compute_velocity_distribution(num_bins = 20)`.
- **Assertion**: Empirical mean speed $\langle v \rangle$ matches theoretical $\sqrt{8 k_B T / (\pi m)}$ within $5\%$.

### Test 6: Engine Static Check & Zero Allocation Verification
- Run `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`.
- **Assertion**: Exit code 0, zero compilation errors, zero warnings.
