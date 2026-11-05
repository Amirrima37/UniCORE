# Architectural & Implementation Blueprint: Nuclear Decay & Quantum Wavepacket Modules

**Milestone**: Milestone 3 — Modular Physics Simulation Domains  
**Author**: Explorer M3-3 (`teamwork_preview_explorer`)  
**Date**: 2026-10-28  
**Target Codebase**: UniCORE (Godot 4.0.stable, GDScript 2.0 static typing)  
**Deliverables Covered**:
1. `res://modules/physics/nuclear_decay_module.gd`
2. `res://modules/physics/quantum_wavepacket_module.gd`

---

## 1. Executive Summary & Architectural Overview

This blueprint specifies the mathematical foundations, data-oriented memory structures, algorithms, rendering pipelines, and API contracts for two primary Milestone 3 physics modules in UniCORE:

1. **`NuclearDecayModule`**: A stochastic subatomic reaction engine simulating radioactive decay channels ($\alpha, \beta^-, \gamma$), an isotope database (U-235, Ra-226, C-14, H-3, H-2, He-4, fission products), exact 4-momentum and rest-mass-energy conservation ($Q = \Delta M \cdot c^2$), and neutron-induced nuclear fission chain reactions accelerated by `SpatialHashGrid` and rendered via single-draw-call `MultiMeshInstance3D` systems.
2. **`QuantumWavepacketModule`**: A discrete quantum mechanics solver for the Time-Dependent Schrödinger Equation (TDSE) on 1D and 2D spatial lattices. It implements an unconditionally unitary Cayley / Crank-Nicolson scheme (1D complex tridiagonal solver) and a symplectic staggered-time leapfrog scheme (2D real/imaginary staggering) preserving the total probability norm $\int |\psi|^2 dV \equiv 1.0$. It demonstrates potential barrier tunneling ($T \approx e^{-2 \kappa d}$), harmonic well confinement, and double-slit interference, visualized with height mapped to probability density and vertex hue mapped to complex phase $\arg(\psi)$.

Both modules extend `UniCoreModule`, integrate with `SimulationTimeController` (`sim_tick`), report Noether invariants to `ConservationSentry`, enforce strictly non-invasive external observer camera isolation, and comply 100% with Godot 4.0.stable and GDScript 2.0 static typing.

```
                           +----------------------------------------+
                           |       SimulationTimeController         |
                           |   (sim_tick, time_scale, step_once)    |
                           +-------------------+--------------------+
                                               |
                     +-------------------------+-------------------------+
                     |                                                   |
                     v                                                   v
   +------------------------------------+             +------------------------------------+
   |        NuclearDecayModule          |             |      QuantumWavepacketModule       |
   | (extends UniCoreModule)            |             | (extends UniCoreModule)            |
   |                                    |             |                                    |
   | - Isotope Registry (14 species)    |             | - Discretized Complex Wavefunction |
   | - Poisson Decay: P = 1 - e^(-λΔt)  |             |   PackedFloat32Array (psi_R, psi_I)|
   | - 4-Momentum & Q-Value Invariants  |             | - Unitary Cayley / Crank-Nicolson  |
   | - SpatialHashGrid Fission Search   |             |   1D Tridiagonal Thomas Algorithm  |
   | - Chain Reaction (k_eff monitor)   |             | - Symplectic Staggered Leapfrog 2D |
   | - Dual MultiMeshInstance3D Render  |             | - Barriers: Tunneling, Well, Slits |
   |   (Nuclei + Ejected Radiation)     |             | - Density-Height & Phase-Hue Mesh  |
   +-----------------+------------------+             +-----------------+------------------+
                     |                                                   |
                     +-------------------------+-------------------------+
                                               |
                                               v
                           +----------------------------------------+
                           |          ConservationSentry            |
                           | (Energy E, Momentum P, Norm N, L, T)   |
                           +-------------------+--------------------+
                                               |
                                               v
                           +----------------------------------------+
                           |       EventBus & Telemetry Stream      |
                           +----------------------------------------+
```

---

## 2. Module 1: Nuclear Decay & Reaction Module (`nuclear_decay_module.gd`)

### 2.1 Theoretical Foundations & Mathematical Formulations

#### 2.1.1 Stochastic Poisson Radioactive Decay
Radioactive decay is an intrinsically memoryless Poisson process governed by the decay constant $\lambda$:
$$\lambda = \frac{\ln(2)}{T_{1/2}}$$
For a discrete integration time step $\Delta t$, the probability that an individual nucleus undergoes decay during $\Delta t$ is:
$$P_{decay}(\Delta t) = 1 - \exp(-\lambda \Delta t)$$
Unlike the first-order approximation $P \approx \lambda \Delta t$ (which fails when $\Delta t \sim T_{1/2}$ or $P > 1$), $1 - \exp(-\lambda \Delta t)$ is mathematically exact for any positive $\Delta t \in (0, \infty)$ and bounded strictly in $[0, 1)$.

At each tick $\Delta t$:
For each active nucleus $i$:
Generate uniform pseudorandom number $U_i \sim \text{Uniform}[0, 1)$. If $U_i < P_{decay}$, trigger the specific decay channel.

For an initial population $N_0$ of identical unstable nuclei, the remaining population obeys the radioactive decay law:
$$N(t) = N_0 \exp(-\lambda t) = N_0 \left(\frac{1}{2}\right)^{t / T_{1/2}}$$
The expected statistical standard error across an ensemble of $N_0$ nuclei is $\sigma = \sqrt{N(t)(1 - \exp(-\lambda t))}$.

#### 2.1.2 4-Momentum and Mass-Energy Invariant Conservation
In nuclear reactions, rest mass is converted to kinetic energy according to Einstein's mass-energy equivalence:
$$Q = \Delta M \cdot c^2_{sim} = (M_{parent} - \sum M_{products}) c^2_{sim}$$
Total mass-energy $E_{total} = \sum_{k} (\gamma_k M_k c^2) \approx \sum_{k} (M_k c^2 + \frac{1}{2} M_k v_k^2)$ and total linear momentum $\vec{P} = \sum_{k} M_k \vec{v}_k$ are strictly conserved.

##### A. Alpha ($\alpha$) Decay (2-Body Kinematics)
Parent $(M_P, \vec{v}_P) \to$ Daughter $(M_D, \vec{v}_D) + \alpha(M_\alpha, \vec{v}_\alpha)$.
In the center-of-mass (rest) frame of the parent:
$$\vec{p}_\alpha + \vec{p}_D = 0 \implies \vec{p}_D = -\vec{p}_\alpha$$
$$Q_\alpha = (M_P - M_D - M_\alpha) c^2_{sim}$$
Kinetic energies in the center-of-mass frame:
$$E_{k, \alpha} = Q_\alpha \frac{M_D}{M_D + M_\alpha}, \quad E_{k, D} = Q_\alpha \frac{M_\alpha}{M_D + M_\alpha}$$
Momentum magnitude:
$$p_{cm} = \sqrt{\frac{2 Q_\alpha M_\alpha M_D}{M_\alpha + M_D}}$$
Emission direction $\hat{u}$ is sampled isotropically on the unit 2-sphere using Archimedes' projection:
$$\cos\theta = 2 U_1 - 1, \quad \phi = 2\pi U_2 \quad (U_1, U_2 \sim \text{Uniform}[0, 1))$$
$$\hat{u} = \left(\sqrt{1 - \cos^2\theta}\cos\phi, \; \sqrt{1 - \cos^2\theta}\sin\phi, \; \cos\theta\right)$$
Laboratory velocities:
$$\vec{v}_\alpha = \vec{v}_P + \frac{p_{cm}}{M_\alpha} \hat{u}$$
$$\vec{v}_D = \vec{v}_P - \frac{p_{cm}}{M_D} \hat{u}$$
Total momentum $M_P \vec{v}_P = M_\alpha \vec{v}_\alpha + M_D \vec{v}_D$ is preserved to machine precision.

##### B. Beta-Minus ($\beta^-$) Decay (3-Body Kinematics)
Parent $(M_P) \to$ Daughter $(M_D) + e^- + \bar{\nu}_e$.
$$Q_\beta = (M_P - M_D - m_e) c^2_{sim}$$
Because $\beta^-$ decay is a 3-body process, kinetic energy $Q_\beta$ is distributed continuously between the electron and antineutrino according to the Fermi phase-space distribution:
$$\frac{dN}{dE_e} \propto \sqrt{E_e(E_e + 2 m_e c^2)} (E_e + m_e c^2) (Q_\beta - E_e)^2$$
In the simulation, electron kinetic energy $E_e \in (0, Q_\beta)$ is sampled using normalized phase-space rejection or polynomial shape approximation:
$$E_\nu = Q_\beta - E_e$$
Momentum magnitudes:
$$p_e = \sqrt{2 m_e E_e}, \quad p_\nu = \frac{E_\nu}{c_{sim}}$$
Directions $\hat{u}_e$ and $\hat{u}_\nu$ are sampled isotropically. The recoiling daughter nucleus receives exact compensation momentum:
$$\vec{p}_D = M_P \vec{v}_P - (p_e \hat{u}_e + p_\nu \hat{u}_\nu)$$
$$\vec{v}_D = \frac{\vec{p}_D}{M_D}$$

##### C. Gamma ($\gamma$) Emission
An excited isomeric nucleus $(M^*)$ drops to ground state $(M)$, emitting a photon:
$$\vec{p}_\gamma = \frac{E_\gamma}{c_{sim}} \hat{u}, \quad \vec{v}_\gamma = c_{sim} \hat{u}$$
$$\vec{p}_D = M_P \vec{v}_P - \vec{p}_\gamma, \quad \vec{v}_D = \frac{\vec{p}_D}{M}$$

#### 2.1.3 Induced Nuclear Fission & Chain Reaction Dynamics
When a free prompt or thermal neutron strikes a fissile nucleus (e.g., $^{235}\text{U}$):
1. **Neutron Capture**: The incident neutron with velocity $\vec{v}_n$ merges into the compound nucleus:
   $$^{235}_{92}\text{U} + ^1_0\text{n} \to [^{236}_{92}\text{U}]^*$$
   Intermediate compound momentum $\vec{P}^* = M_U \vec{v}_U + m_n \vec{v}_n$, mass $M^* = M_U + m_n$.
2. **Binary Fission**: The compound nucleus undergoes scission into two primary fission fragments (e.g. Krypton-92 and Barium-141) plus $\nu_{prompt} \in \{2, 3\}$ prompt neutrons (mean $\bar{\nu} \approx 2.43$):
   $$[^{236}_{92}\text{U}]^* \to ^{92}_{36}\text{Kr} + ^{141}_{56}\text{Ba} + \nu_p \; ^1_0\text{n} + Q_{fiss}$$
3. **Energy Release**: Total fission energy $Q_{fiss} \approx 200.0\text{ MeV} \approx 3.2 \times 10^{-11}\text{ J}$.
   - Heavy fragments kinetic energy: $E_{k, fragments} \approx 168.0\text{ MeV}$ (84% of $Q_{fiss}$).
   - Prompt neutrons kinetic energy: $E_{k, neutrons} \approx 2.0\text{ MeV}$ per neutron (average speed $v_n \approx 2.0 \times 10^7\text{ m/s}$ in SI, scaled to high interactive speed in simulation units).
   - Prompt gamma rays: remainder ($\sim 7\text{ MeV}$).
4. **Collision Cross-Section**:
   The microscopic cross-section $\sigma_f$ is mapped to an effective geometric collision radius $R_{fiss}$ in the simulation lattice:
   $$R_{fiss} = \sqrt{\frac{\sigma_f}{\pi}}$$
   For energy-dependent moderation:
   $$\sigma_f(v) = \sigma_{thermal} \left(\frac{v_{thermal}}{v}\right)$$
   Slow (thermalized) neutrons have a significantly higher probability of inducing fission than fast neutrons.
5. **Effective Neutron Multiplication Factor ($k_{eff}$)**:
   $$k_{eff} = \frac{N_{neutrons}(t + \Delta t_{gen})}{N_{neutrons}(t)}$$
   - $k_{eff} < 1.0$: Subcritical (reaction dies out).
   - $k_{eff} = 1.0$: Critical (steady power output).
   - $k_{eff} > 1.0$: Supercritical (exponential runaway chain reaction).

---

### 2.2 Built-in Isotope Database Specification

The module embeds an immutable, statically typed dictionary of nuclear isotopes and subatomic particles:

| Symbol | Name | Z | A | Mass ($u$) | Half-Life ($s_{sim}$) | Primary Channel | Daughter | $Q$-Value (MeV) | Fissile | Visualization Color | Scale ($A^{1/3}$) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `U-235` | Uranium-235 | 92 | 235 | 235.0439 | 30.0 | ALPHA / FISSION | Th-231 | 4.68 / 200.0 | **Yes** | `Color(0.20, 0.95, 0.30)` (Radioactive Green) | 1.40 |
| `Ra-226` | Radium-226 | 88 | 226 | 226.0254 | 15.0 | ALPHA | Rn-222 | 4.87 | No | `Color(0.10, 0.85, 0.85)` (Phosphor Cyan) | 1.38 |
| `C-14` | Carbon-14 | 6 | 14 | 14.0032 | 20.0 | BETA_MINUS | N-14 | 0.156 | No | `Color(0.65, 0.55, 0.35)` (Graphite Amber) | 0.70 |
| `H-3` | Tritium | 1 | 3 | 3.0160 | 12.0 | BETA_MINUS | He-3 | 0.0186 | No | `Color(0.35, 0.70, 1.00)` (Sky Blue) | 0.45 |
| `H-2` | Deuterium | 1 | 2 | 2.0141 | $\infty$ | NONE (Stable) | — | 0.0 | No | `Color(0.70, 0.85, 1.00)` (Pale Blue) | 0.40 |
| `He-4` | Alpha Particle | 2 | 4 | 4.0015 | $\infty$ | NONE (Stable) | — | 0.0 | No | `Color(1.00, 0.75, 0.15)` (Golden Orange) | 0.50 |
| `Th-231` | Thorium-231 | 90 | 231 | 231.0363 | 25.5 | BETA_MINUS | Pa-231 | 0.39 | No | `Color(0.35, 0.65, 0.45)` (Olive Green) | 1.39 |
| `Rn-222` | Radon-222 | 86 | 222 | 222.0176 | 3.82 | ALPHA | Po-218 | 5.59 | No | `Color(0.25, 0.70, 0.90)` (Gaseous Teal) | 1.37 |
| `N-14` | Nitrogen-14 | 7 | 14 | 14.0031 | $\infty$ | NONE (Stable) | — | 0.0 | No | `Color(0.50, 0.50, 0.60)` (Steel Grey) | 0.70 |
| `He-3` | Helium-3 | 2 | 3 | 3.0160 | $\infty$ | NONE (Stable) | — | 0.0 | No | `Color(0.55, 0.85, 0.95)` (Cyan White) | 0.45 |
| `Kr-92` | Krypton-92 | 36 | 92 | 91.926 | $\infty$ | NONE (Fragment) | — | 0.0 | No | `Color(1.00, 0.30, 0.20)` (Ruby Red) | 1.05 |
| `Ba-141` | Barium-141 | 56 | 141 | 140.914 | $\infty$ | NONE (Fragment) | — | 0.0 | No | `Color(0.95, 0.15, 0.40)` (Magenta Red) | 1.20 |
| `Neutron`| Free Neutron | 0 | 1 | 1.0087 | 100.0 | FISSION_TRIGGER | — | 0.0 | No | `Color(1.00, 1.00, 0.60)` (Neon Yellow) | 0.25 |
| `Electron`| Beta Particle | -1 | 0 | 0.000548 | $\infty$ | RADIATION | — | 0.0 | No | `Color(0.20, 0.60, 1.00)` (Electric Blue) | 0.15 |
| `Gamma` | Gamma Photon | 0 | 0 | 0.000000 | $\infty$ | RADIATION | — | 0.0 | No | `Color(0.90, 0.40, 1.00)` (Violet Ray) | 0.10 |

*Note*: Simulation half-lives are calibrated to interactive experimental timescales ($3.8\text{ s}$ to $30.0\text{ s}$) while maintaining relative decay ratios, with a configurable `time_dilatation_factor` to convert back to SI seconds when connected to `UnitConverter`.

---

### 2.3 Data-Oriented Memory & Spatial Acceleration

To achieve 60+ FPS with thousands of interacting nuclei and radiation particles, the module uses contiguous typed packed arrays and spatial hashing:

#### 2.3.1 Contiguous Nuclei Buffers
```gdscript
var nuclei_positions: PackedVector3Array = PackedVector3Array()
var nuclei_velocities: PackedVector3Array = PackedVector3Array()
var nuclei_masses: PackedFloat32Array = PackedFloat32Array()
var nuclei_isotope_ids: PackedInt32Array = PackedInt32Array()
var nuclei_active: PackedByteArray = PackedByteArray()
var nuclei_half_lives: PackedFloat32Array = PackedFloat32Array()
var nuclei_decay_channels: PackedInt32Array = PackedInt32Array()
```

#### 2.3.2 Contiguous Radiation Particles Buffers
```gdscript
var radiation_positions: PackedVector3Array = PackedVector3Array()
var radiation_velocities: PackedVector3Array = PackedVector3Array()
var radiation_masses: PackedFloat32Array = PackedFloat32Array()
var radiation_types: PackedInt32Array = PackedInt32Array() # ALPHA, BETA, GAMMA, NEUTRON
var radiation_lifetimes: PackedFloat32Array = PackedFloat32Array()
var radiation_active: PackedByteArray = PackedByteArray()
```

#### 2.3.3 Collision Partitioning via `SpatialHashGrid`
Neutron-induced fission checks require finding which nuclei are struck by moving neutrons. Testing all $N_{neutrons} \times N_{nuclei}$ would be $O(N^2)$.
Instead, the module reuses UniCORE's `SpatialHashGrid`:
1. At the start of each simulation tick, `fissile_grid.build_grid(fissile_positions)`.
2. For each active neutron:
   `var neighbors: PackedInt32Array = fissile_grid.get_neighbors(neutron_pos, collision_radius)`
3. Only candidate nuclei within the cell are checked for swept-sphere collision.
Complexity drops from $O(N^2)$ to $O(N)$!

---

### 2.4 MultiMeshInstance3D High-Performance Visualizer

```
+--------------------------------------------------------------------------+
|                        NuclearDecayModule (Node3D)                       |
+------------------------------------+-------------------------------------+
                                     |
           +-------------------------+-------------------------+
           |                                                   |
           v                                                   v
+-------------------------------+             +-------------------------------+
|      nuclei_multimesh         |             |     radiation_multimesh       |
|    (MultiMeshInstance3D)      |             |    (MultiMeshInstance3D)      |
+-------------------------------+             +-------------------------------+
| - Mesh: SphereMesh (radius 0.1)|             | - Mesh: SphereMesh / PointQuad|
| - Transform format: 3D        |             | - Transform format: 3D        |
| - Colors: Enabled (per-atom)  |             | - Colors: Enabled (particles) |
| - Max Instances: 10,000       |             | - Max Instances: 20,000       |
| - visible_instance_count = N  |             | - visible_instance_count = M  |
+-------------------------------+             +-------------------------------+
```

Both `MultiMeshInstance3D` instances are added as direct children of the module:
- `nuclei_multimesh.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * scale), pos))`
- `nuclei_multimesh.multimesh.set_instance_color(i, isotope_color)`
- Unused/decayed/absorbed slots are tucked away or hidden by maintaining a packed active index list and setting `visible_instance_count = active_count`.

---

### 2.5 Complete Implementation Contract: `nuclear_decay_module.gd`

```gdscript
class_name NuclearDecayModule
extends UniCoreModule

## UniCORE Fundamental Scientific Simulation Platform
## Module: Nuclear Decay & Induced Reaction Engine
## Simulates Poisson radioactive decay, 4-momentum conservation, and chain reactions.

signal decay_occurred(isotope_symbol: String, channel: int, position: Vector3, q_value: float)
signal fission_triggered(position: Vector3, fragments_count: int, prompt_neutrons: int, energy: float)
signal chain_reaction_status(k_effective: float, active_neutrons: int, active_nuclei: int)

enum DecayChannel {
	NONE = 0,
	ALPHA = 1,
	BETA_MINUS = 2,
	GAMMA = 3,
	INDUCED_FISSION = 4
}

enum RadiationType {
	ALPHA = 1,
	BETA = 2,
	GAMMA = 3,
	NEUTRON = 4
}

# Physical Simulation Constants
const SPEED_OF_LIGHT_SIM: float = 50.0  # Scaled interactive c_sim (m/s)
const C_SQUARED: float = SPEED_OF_LIGHT_SIM * SPEED_OF_LIGHT_SIM
const MAX_NUCLEI: int = 10000
const MAX_RADIATION: int = 20000
const NEUTRON_COLLISION_RADIUS: float = 0.25
const DEFAULT_RADIATION_LIFETIME: float = 5.0 # Seconds before vacuum dispersion

# State Properties
@export var is_simulation_enabled: bool = true
@export var control_rod_depth: float = 0.0 # 0.0 = fully withdrawn, 1.0 = fully inserted
@export var half_life_multiplier: float = 1.0 # Interactive time scaling

# Internal Subsystems
var spatial_grid: SpatialHashGrid = null
var time_controller: SimulationTimeController = null
var conservation_sentry: ConservationSentry = null

# Contiguous Nuclei Buffers
var nuclei_positions: PackedVector3Array = PackedVector3Array()
var nuclei_velocities: PackedVector3Array = PackedVector3Array()
var nuclei_masses: PackedFloat32Array = PackedFloat32Array()
var nuclei_isotope_keys: Array[String] = []
var nuclei_half_lives: PackedFloat32Array = PackedFloat32Array()
var nuclei_channels: PackedInt32Array = PackedInt32Array()
var nuclei_active: PackedByteArray = PackedByteArray()
var active_nuclei_count: int = 0

# Contiguous Radiation Buffers
var rad_positions: PackedVector3Array = PackedVector3Array()
var rad_velocities: PackedVector3Array = PackedVector3Array()
var rad_masses: PackedFloat32Array = PackedFloat32Array()
var rad_types: PackedInt32Array = PackedInt32Array()
var rad_lifetimes: PackedFloat32Array = PackedFloat32Array()
var rad_active: PackedByteArray = PackedByteArray()
var active_rad_count: int = 0

# Visual Nodes
var nuclei_mesh_instance: MultiMeshInstance3D = null
var rad_mesh_instance: MultiMeshInstance3D = null

# Invariant & Telemetry Tracking
var initial_total_energy: float = 0.0
var total_fission_events: int = 0
var total_decay_events: int = 0
var last_k_effective: float = 0.0
var previous_neutron_count: int = 0
var sample_timer: float = 0.0

# Built-in Isotope Database
var isotope_db: Dictionary = {}

func get_module_id() -> String:
	return "nuclear_decay"

func get_module_name() -> String:
	return "Nuclear Decay & Reaction Module"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{"action": "inject_neutron", "label": "Inject Trigger Neutron", "default_key": KEY_SPACE, "description": "Spawns a prompt neutron towards the core"},
		{"action": "insert_control_rods", "label": "Insert Control Rods", "default_key": KEY_DOWN, "description": "Absorbs neutrons to damp chain reaction"},
		{"action": "withdraw_control_rods", "label": "Withdraw Control Rods", "default_key": KEY_UP, "description": "Increases reactivity"},
		{"action": "reset_nuclear_core", "label": "Reset Nuclear Core", "default_key": KEY_R, "description": "Re-spawns pristine isotope assembly"}
	]
```

### 2.6 Key Algorithms in GDScript 2.0

#### 2.6.1 Poisson Decay Execution
```gdscript
func _process_decays(dt: float) -> void:
	var n_nuclei: int = nuclei_positions.size()
	for i in range(n_nuclei):
		if nuclei_active[i] == 0:
			continue
		
		var t_half: float = nuclei_half_lives[i] * half_life_multiplier
		if is_inf(t_half) or t_half <= 0.0:
			continue
		
		var lambda_decay: float = 0.69314718056 / t_half
		var p_decay: float = 1.0 - exp(-lambda_decay * dt)
		
		if randf() < p_decay:
			_execute_decay(i)
```

#### 2.6.2 2-Body Alpha Decay with Strict Momentum Balance
```gdscript
func _execute_alpha_decay(idx: int, iso: Dictionary) -> void:
	var parent_pos: Vector3 = nuclei_positions[idx]
	var parent_vel: Vector3 = nuclei_velocities[idx]
	var m_parent: float = nuclei_masses[idx]
	
	var daughter_key: String = iso["daughter_symbol"]
	var d_iso: Dictionary = isotope_db.get(daughter_key, {})
	var m_daughter: float = float(d_iso.get("atomic_mass_u", m_parent - 4.0))
	var m_alpha: float = 4.001506
	
	# Q-value in simulation energy units: Q = (m_p - m_d - m_alpha) * c^2
	var delta_m: float = m_parent - (m_daughter + m_alpha)
	var q_energy: float = maxf(0.001, delta_m * C_SQUARED)
	
	# Center of mass momentum: p_cm = sqrt(2 * Q * m_alpha * m_daughter / (m_alpha + m_daughter))
	var p_cm: float = sqrt(2.0 * q_energy * m_alpha * m_daughter / (m_alpha + m_daughter))
	
	# Isotropic random direction on S^2
	var cos_theta: float = randf_range(-1.0, 1.0)
	var phi: float = randf_range(0.0, TAU)
	var sin_theta: float = sqrt(maxf(0.0, 1.0 - cos_theta * cos_theta))
	var dir: Vector3 = Vector3(sin_theta * cos(phi), sin_theta * sin(phi), cos_theta)
	
	# Transform parent into daughter in-place
	nuclei_isotope_keys[idx] = daughter_key
	nuclei_masses[idx] = m_daughter
	nuclei_half_lives[idx] = float(d_iso.get("half_life_seconds", INF))
	nuclei_channels[idx] = int(d_iso.get("decay_channel", DecayChannel.NONE))
	nuclei_velocities[idx] = parent_vel - (p_cm / m_daughter) * dir
	
	# Spawn ejected alpha particle
	var alpha_vel: Vector3 = parent_vel + (p_cm / m_alpha) * dir
	_spawn_radiation(parent_pos, alpha_vel, m_alpha, RadiationType.ALPHA)
	
	total_decay_events += 1
	decay_occurred.emit(iso["symbol"], DecayChannel.ALPHA, parent_pos, q_energy)
```

#### 2.6.3 Induced Fission Chain Reaction & Prompt Neutrons
```gdscript
func _process_fission_collisions(dt: float) -> void:
	var fissile_indices: PackedInt32Array = PackedInt32Array()
	var fissile_pos: PackedVector3Array = PackedVector3Array()
	
	# Collect active fissile nuclei
	var n_nuclei: int = nuclei_positions.size()
	for i in range(n_nuclei):
		if nuclei_active[i] == 1 and nuclei_isotope_keys[i] == "U-235":
			fissile_indices.append(i)
			fissile_pos.append(nuclei_positions[i])
	
	if fissile_indices.is_empty():
		return
	
	spatial_grid.build_grid(fissile_pos)
	
	# Check each active neutron against fissile nuclei
	var n_rad: int = rad_positions.size()
	for r in range(n_rad):
		if rad_active[r] == 0 or rad_types[r] != RadiationType.NEUTRON:
			continue
		
		# Control rod neutron absorption check
		if control_rod_depth > 0.0 and randf() < (control_rod_depth * 0.9):
			rad_active[r] = 0
			active_rad_count -= 1
			continue
		
		var n_pos: Vector3 = rad_positions[r]
		var neighbors: PackedInt32Array = spatial_grid.get_neighbors(n_pos, NEUTRON_COLLISION_RADIUS)
		
		if not neighbors.is_empty():
			var hit_fissile_local_idx: int = neighbors[0]
			var hit_nucleus_idx: int = fissile_indices[hit_fissile_local_idx]
			
			# Deactivate incident neutron
			rad_active[r] = 0
			active_rad_count -= 1
			
			# Trigger binary fission of hit U-235
			_execute_fission(hit_nucleus_idx, rad_velocities[r])
```

---

## 3. Module 2: Quantum Wavepacket Propagation Module (`quantum_wavepacket_module.gd`)

### 3.1 Theoretical Foundations & Mathematical Formulations

#### 3.1.1 The Time-Dependent Schrödinger Equation (TDSE)
In dimensionless atomic/simulation units ($\hbar = 1.0, m = 1.0$):
$$i \frac{\partial \psi(\vec{r}, t)}{\partial t} = \hat{H} \psi(\vec{r}, t) = \left(-\frac{1}{2}\nabla^2 + V(\vec{r})\right) \psi(\vec{r}, t)$$
The complex wavefunction $\psi(\vec{r}, t) = \psi_R(\vec{r}, t) + i \psi_I(\vec{r}, t)$ satisfies the coupled real system:
$$\frac{\partial \psi_R}{\partial t} = \hat{H} \psi_I = -\frac{1}{2}\nabla^2 \psi_I + V(\vec{r})\psi_I$$
$$\frac{\partial \psi_I}{\partial t} = -\hat{H} \psi_R = \frac{1}{2}\nabla^2 \psi_R - V(\vec{r})\psi_R$$

#### 3.1.2 1D Unitary Cayley / Crank-Nicolson Evolution Scheme
The Cayley evolution operator approximates $e^{-i \hat{H} \Delta t}$ with the $(1, 1)$ Padé rational approximant:
$$\psi^{n+1} = \frac{I - \frac{i \Delta t}{2}\hat{H}}{I + \frac{i \Delta t}{2}\hat{H}} \psi^n \iff \left(I + \frac{i \Delta t}{2}\hat{H}\right)\psi^{n+1} = \left(I - \frac{i \Delta t}{2}\hat{H}\right)\psi^n$$
Since $\hat{H}$ is self-adjoint ($\hat{H}^\dagger = \hat{H}$), the Cayley operator $U = (I + i \alpha \hat{H})^{-1}(I - i \alpha \hat{H})$ is **strictly unitary**:
$$U^\dagger U = \left(I - i \alpha \hat{H}\right) \left(I + i \alpha \hat{H}\right)^{-1} \left(I + i \alpha \hat{H}\right)^{-1\dagger} \left(I - i \alpha \hat{H}\right)^\dagger = I$$
**Crucial consequence**: The total probability norm $N(t) = \int |\psi|^2 dx$ is preserved **unconditionally to machine precision** for arbitrary time step $\Delta t$, with zero artificial growth or numerical dissipation.

##### Tridiagonal Discretization & Thomas Algorithm
Discretize $x \in [-L, L]$ with $N$ points, grid spacing $\Delta x = \frac{2L}{N-1}$.
Finite difference Laplacian:
$$\nabla^2 \psi_j = \frac{\psi_{j+1} - 2\psi_j + \psi_{j-1}}{\Delta x^2}$$
Let $\beta = \frac{\Delta t}{4 \Delta x^2}$. The tridiagonal linear equation at grid point $j$ is:
$$-i\beta \psi_{j-1}^{n+1} + \left(1 + 2i\beta + i \frac{\Delta t}{2} V_j\right)\psi_j^{n+1} - i\beta \psi_{j+1}^{n+1} = \chi_j^n$$
where the right-hand vector is:
$$\chi_j^n = i\beta \psi_{j-1}^n + \left(1 - 2i\beta - i \frac{\Delta t}{2} V_j\right)\psi_j^n + i\beta \psi_{j+1}^n$$
This complex tridiagonal system is solved in $O(N)$ operations via the complex Thomas algorithm (forward sweep + back-substitution) in contiguous packed float arrays (`psi_R`, `psi_I`).

#### 3.1.3 2D Symplectic Staggered-Time Leapfrog Scheme (Visscher Scheme)
For real-time 2D wave evolution on a lattice $(N_x \times N_z = 64 \times 64$ to $128 \times 128)$, solving a 2D matrix directly every frame is costly in GDScript.
Instead, the module implements the symplectic staggered-time leapfrog scheme:
$$\psi_R(t + \Delta t) = \psi_R(t) + \Delta t \cdot \left[-\frac{1}{2}\nabla^2 \psi_I\left(t + \frac{\Delta t}{2}\right) + V \psi_I\left(t + \frac{\Delta t}{2}\right)\right]$$
$$\psi_I\left(t + \frac{3\Delta t}{2}\right) = \psi_I\left(t + \frac{\Delta t}{2}\right) - \Delta t \cdot \left[-\frac{1}{2}\nabla^2 \psi_R(t + \Delta t) + V \psi_R(t + \Delta t)\right]$$
Using standard 5-point discrete 2D Laplacian:
$$\nabla^2 \psi_{j, k} = \frac{\psi_{j+1, k} + \psi_{j-1, k} - 2\psi_{j, k}}{\Delta x^2} + \frac{\psi_{j, k+1} + \psi_{j, k-1} - 2\psi_{j, k}}{\Delta z^2}$$
**Stability Requirement (CFL Condition)**:
$$\Delta t \le \frac{1}{\frac{1}{\Delta x^2} + \frac{1}{\Delta z^2} + \frac{1}{2}\max(V)}$$
For $\Delta x = \Delta z = 0.25$, $\Delta t \le 0.015$, perfectly compatible with `SimulationTimeController.fixed_delta = 0.01`!

#### 3.1.4 Analytical Barrier Tunneling & Transmission
A Gaussian wavepacket with initial mean position $x_0$, width $\sigma_x$, and momentum $k_0$:
$$\psi(x, 0) = \left(\frac{1}{2\pi \sigma_x^2}\right)^{1/4} \exp\left(-\frac{(x - x_0)^2}{4\sigma_x^2}\right) \exp(i k_0 x)$$
Packet kinetic energy:
$$E = \frac{k_0^2}{2}$$
When the packet impinges on a rectangular potential barrier of height $V_0 > E$ and width $d$:
Classical physics predicts 100% reflection. In quantum mechanics, the wave function penetrates the barrier as an evanescent wave with attenuation coefficient:
$$\kappa = \sqrt{2(V_0 - E)}$$
The exact analytical transmission coefficient is:
$$T_{analytical} = \left[ 1 + \frac{V_0^2 \sinh^2(\kappa d)}{4 E (V_0 - E)} \right]^{-1} \approx \frac{16 E (V_0 - E)}{V_0^2} \exp(-2\kappa d)$$
The module empirically calculates transmission by integrating probability density past the barrier:
$$T_{empirical}(t) = \int_{x > x_{barrier\_end}} |\psi(x, t)|^2 dx$$
and confirms agreement with $T_{analytical}$ within statistical wavepacket dispersion width.

#### 3.1.5 Observables and Invariant Diagnostics
1. **Total Probability Norm**:
   $$N(t) = \sum_{j} |\psi_j|^2 \Delta x \equiv 1.0$$
2. **Probability Current (Flux)**:
   $$j(x) = \psi_R \frac{\partial \psi_I}{\partial x} - \psi_I \frac{\partial \psi_R}{\partial x}$$
   Satisfies the continuity equation $\frac{\partial |\psi|^2}{\partial t} + \frac{\partial j}{\partial x} = 0$.
3. **Position Expectation Value**:
   $$\langle x \rangle = \sum_j x_j |\psi_j|^2 \Delta x$$
4. **Expectation Energy**:
   $$\langle E \rangle = \langle T \rangle + \langle V \rangle = \int \psi^* \left(-\frac{1}{2}\nabla^2 + V\right)\psi dx$$

---

### 3.2 Visualization Architecture: Phase-to-Color & Heightfield

The quantum state is visualized without any per-point scene graph nodes:

```
Complex Wavefunction ψ(x) = |ψ| e^(i θ)
      |
      +---> Height: Probability Density ρ = |ψ|^2 = ψ_R^2 + ψ_I^2
      |
      +---> Color: Phase Angle θ = atan2(ψ_I, ψ_R) ∈ [-π, π]
            Mapped to HSV: Hue = (θ + π) / (2π)
            (Red = 0°, Yellow = 60°, Green = 120°, Cyan = 180°, Blue = 240°, Magenta = 300°)
```

#### 3.2.1 1D Mode: ImmediateMesh Ribbon
- Dynamic 3D ribbon constructed via `ImmediateMesh`:
  - Front strip: $(x_j, \rho_j \cdot H_{scale}, 0.0)$ with color $\text{Color.from_hsv}(\text{hue}_j, 1.0, 1.0)$.
  - Back strip: $(x_j, 0.0, 0.0)$ with darker shaded color to form a filled 3D profile.
- Translucent barrier quad rendered at barrier position with height proportional to $V_0$.

#### 3.2.2 2D Mode: ArrayMesh Dynamic Surface
- Grid of $N_x \times N_z$ vertices.
- Surface arrays populated directly via `PackedVector3Array` and `PackedColorArray`:
  $$V_{j, k} = \text{Vector3}(x_j, \; \rho_{j, k} \cdot H_{scale}, \; z_k)$$
  $$C_{j, k} = \text{Color.from_hsv}(\text{hue}_{j, k}, 0.9, 1.0)$$
- Real-time normal generation using central differences for vacuum specular highlights.

---

### 3.3 Complete Implementation Contract: `quantum_wavepacket_module.gd`

```gdscript
class_name QuantumWavePacketModule
extends UniCoreModule

## UniCORE Fundamental Scientific Simulation Platform
## Module: Quantum Wavepacket Propagation Engine (1D / 2D TDSE)
## Solves Time-Dependent Schrödinger Equation with unitary norm conservation.

signal observables_updated(norm: float, x_mean: float, energy: float, transmission: float, reflection: float)
signal barrier_tunneling_analyzed(analytical_t: float, empirical_t: float, relative_error: float)

enum SimulationDimension {
	DIMENSION_1D = 1,
	DIMENSION_2D = 2
}

enum PotentialType {
	FREE_SPACE = 0,
	RECTANGULAR_BARRIER = 1,
	HARMONIC_WELL = 2,
	STEP_POTENTIAL = 3,
	DOUBLE_SLIT = 4
}

# Grid Configuration (1D)
@export var grid_size_1d: int = 512
@export var domain_length_1d: float = 24.0 # x in [-12, 12]

# Grid Configuration (2D)
@export var grid_size_2d_x: int = 64
@export var grid_size_2d_z: int = 64
@export var domain_size_2d: Vector2 = Vector2(16.0, 16.0)

# Wavepacket Properties
@export var packet_center_x: float = -6.0
@export var packet_width: float = 0.8
@export var packet_wavenumber_k0: float = 3.0 # Incident kinetic energy E = k0^2 / 2 = 4.5

# Barrier Parameters
@export var potential_type: PotentialType = PotentialType.RECTANGULAR_BARRIER
@export var barrier_height_v0: float = 6.0 # V0 > E causes tunneling
@export var barrier_width_d: float = 0.8
@export var barrier_center_x: float = 0.0
@export var harmonic_omega: float = 1.0

# Active Dimension
@export var active_dimension: SimulationDimension = SimulationDimension.DIMENSION_1D
@export var height_visual_scale: float = 6.0

# Contiguous 1D Wavefunction Buffers
var psi_real_1d: PackedFloat32Array = PackedFloat32Array()
var psi_imag_1d: PackedFloat32Array = PackedFloat32Array()
var potential_1d: PackedFloat32Array = PackedFloat32Array()
var prob_density_1d: PackedFloat32Array = PackedFloat32Array()

# Contiguous 2D Wavefunction Buffers
var psi_real_2d: PackedFloat32Array = PackedFloat32Array()
var psi_imag_2d: PackedFloat32Array = PackedFloat32Array()
var potential_2d: PackedFloat32Array = PackedFloat32Array()
var prob_density_2d: PackedFloat32Array = PackedFloat32Array()

# Visualizer Mesh Nodes
var mesh_instance_1d: MeshInstance3D = null
var immediate_mesh_1d: ImmediateMesh = null
var mesh_instance_2d: MeshInstance3D = null
var array_mesh_2d: ArrayMesh = null
var barrier_mesh_instance: MeshInstance3D = null

# Invariant & Telemetry State
var initial_packet_norm: float = 1.0
var current_norm: float = 1.0
var mean_position_x: float = 0.0
var expectation_energy: float = 0.0
var transmission_coeff: float = 0.0
var reflection_coeff: float = 0.0
var analytical_transmission: float = 0.0

func get_module_id() -> String:
	return "quantum_wavepacket"

func get_module_name() -> String:
	return "Quantum Wavepacket Propagation Module"

func get_action_bindings() -> Array[Dictionary]:
	return [
		{"action": "reset_wavepacket", "label": "Reset Wavepacket", "default_key": KEY_R, "description": "Re-initializes Gaussian wavepacket"},
		{"action": "cycle_potential", "label": "Cycle Potential Type", "default_key": KEY_B, "description": "Toggles Barrier, Well, Double-Slit, Free"},
		{"action": "increase_barrier", "label": "Increase Barrier Height", "default_key": KEY_UP, "description": "Increases V0"},
		{"action": "decrease_barrier", "label": "Decrease Barrier Height", "default_key": KEY_DOWN, "description": "Decreases V0"},
		{"action": "toggle_dimension", "label": "Toggle 1D/2D View", "default_key": KEY_M, "description": "Switches between 1D ribbon and 2D surface"}
	]
```

### 3.4 Key Algorithms in GDScript 2.0

#### 3.4.1 Unitary 1D Cayley Tridiagonal Thomas Solver
```gdscript
func _evolve_1d_cayley(dt: float) -> void:
	var n: int = grid_size_1d
	var dx: float = domain_length_1d / float(n - 1)
	var alpha: float = dt / (4.0 * dx * dx) # Off-diagonal coupling
	
	# Complex tridiagonal system: (1 + i*H*dt/2) psi^(n+1) = (1 - i*H*dt/2) psi^n
	# Off-diagonals are purely imaginary: a_j = c_j = -i * alpha
	# Diagonals: d_j = (1 + 2*alpha) + i * (dt * V_j / 2)
	
	# Auxiliary vectors for Thomas algorithm:
	# c_prime (complex) and d_prime (complex)
	var cp_r: PackedFloat32Array = PackedFloat32Array()
	var cp_i: PackedFloat32Array = PackedFloat32Array()
	var dp_r: PackedFloat32Array = PackedFloat32Array()
	var dp_i: PackedFloat32Array = PackedFloat32Array()
	cp_r.resize(n)
	cp_i.resize(n)
	dp_r.resize(n)
	dp_i.resize(n)
	
	# 1. Compute RHS vector chi = (1 - i*H*dt/2) psi^n
	var chi_r: PackedFloat32Array = PackedFloat32Array()
	var chi_i: PackedFloat32Array = PackedFloat32Array()
	chi_r.resize(n)
	chi_i.resize(n)
	
	for j in range(1, n - 1):
		var v_term: float = dt * potential_1d[j] * 0.5
		# Diagonal operator (1 - 2*i*alpha - i*v_term)
		var diag_r: float = 1.0
		var diag_i: float = -(2.0 * alpha + v_term)
		
		# Off-diagonals (+i * alpha)
		var lap_r: float = -alpha * (psi_imag_1d[j - 1] + psi_imag_1d[j + 1])
		var lap_i: float = alpha * (psi_real_1d[j - 1] + psi_real_1d[j + 1])
		
		chi_r[j] = diag_r * psi_real_1d[j] - diag_i * psi_imag_1d[j] + lap_r
		chi_i[j] = diag_r * psi_imag_1d[j] + diag_i * psi_real_1d[j] + lap_i
	
	# 2. Forward Sweep of Thomas Algorithm
	# For boundary j=0: Dirichlet psi=0
	cp_r[0] = 0.0
	cp_i[0] = 0.0
	dp_r[0] = 0.0
	dp_i[0] = 0.0
	
	for j in range(1, n - 1):
		var v_term: float = dt * potential_1d[j] * 0.5
		var dj_r: float = 1.0
		var dj_i: float = 2.0 * alpha + v_term
		
		# denom = d_j - a_j * cp_{j-1}
		# Note a_j = i * alpha, so a_j * cp = (-alpha * cp_i) + i*(alpha * cp_r)
		var denom_r: float = dj_r - (-alpha * cp_i[j - 1])
		var denom_i: float = dj_i - (alpha * cp_r[j - 1])
		var denom_mag_sq: float = denom_r * denom_r + denom_i * denom_i
		
		# c_j = -i * alpha
		# cp_j = c_j / denom
		cp_r[j] = (-alpha * denom_i) / denom_mag_sq
		cp_i[j] = (-alpha * denom_r) / denom_mag_sq
		
		# num = chi_j - a_j * dp_{j-1}
		var num_r: float = chi_r[j] - (-alpha * dp_i[j - 1])
		var num_i: float = chi_i[j] - (alpha * dp_r[j - 1])
		
		dp_r[j] = (num_r * denom_r + num_i * denom_i) / denom_mag_sq
		dp_i[j] = (num_i * denom_r - num_r * denom_i) / denom_mag_sq
	
	# 3. Back Substitution
	psi_real_1d[n - 1] = 0.0
	psi_imag_1d[n - 1] = 0.0
	
	for j in range(n - 2, 0, -1):
		# psi_j = dp_j - cp_j * psi_{j+1}
		var next_r: float = psi_real_1d[j + 1]
		var next_i: float = psi_imag_1d[j + 1]
		var prod_r: float = cp_r[j] * next_r - cp_i[j] * next_i
		var prod_i: float = cp_r[j] * next_i + cp_i[j] * next_r
		
		psi_real_1d[j] = dp_r[j] - prod_r
		psi_imag_1d[j] = dp_i[j] - prod_i
```

#### 3.4.2 2D Symplectic Staggered Leapfrog Evolution
```gdscript
func _evolve_2d_staggered(dt: float) -> void:
	var nx: int = grid_size_2d_x
	var nz: int = grid_size_2d_z
	var dx: float = domain_size_2d.x / float(nx - 1)
	var dz: float = domain_size_2d.y / float(nz - 1)
	var inv_dx2: float = 1.0 / (dx * dx)
	var inv_dz2: float = 1.0 / (dz * dz)
	
	# Step A: Update Real part using Imaginary part: psi_R += dt * H * psi_I
	for z in range(1, nz - 1):
		var row: int = z * nx
		for x in range(1, nx - 1):
			var idx: int = row + x
			var lap: float = (
				(psi_imag_2d[idx + 1] + psi_imag_2d[idx - 1] - 2.0 * psi_imag_2d[idx]) * inv_dx2 +
				(psi_imag_2d[idx + nx] + psi_imag_2d[idx - nx] - 2.0 * psi_imag_2d[idx]) * inv_dz2
			)
			var h_psi_i: float = -0.5 * lap + potential_2d[idx] * psi_imag_2d[idx]
			psi_real_2d[idx] += dt * h_psi_i
	
	# Step B: Update Imaginary part using Real part: psi_I -= dt * H * psi_R
	for z in range(1, nz - 1):
		var row: int = z * nx
		for x in range(1, nx - 1):
			var idx: int = row + x
			var lap: float = (
				(psi_real_2d[idx + 1] + psi_real_2d[idx - 1] - 2.0 * psi_real_2d[idx]) * inv_dx2 +
				(psi_real_2d[idx + nx] + psi_real_2d[idx - nx] - 2.0 * psi_real_2d[idx]) * inv_dz2
			)
			var h_psi_r: float = -0.5 * lap + potential_2d[idx] * psi_real_2d[idx]
			psi_imag_2d[idx] -= dt * h_psi_r
```

---

## 4. Integration with UniCORE Core Subsystems

### 4.1 `SimulationTimeController` Integration
Both modules connect to `SimulationTimeController.sim_tick` during `initialize(context)`:
```gdscript
func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	if core_context.has("time_controller") and core_context["time_controller"]:
		time_controller = core_context["time_controller"] as SimulationTimeController
		time_controller.sim_tick.connect(_on_sim_tick)
	...
```
- Modules strictly do NOT use variable frame `delta` from `_process` or `_physics_process` for physical state evolution.
- Ticking occurs deterministically via discrete `fixed_delta` provided by `SimulationTimeController`.
- When the simulation is paused, wave evolution and decay probabilities freeze completely.
- `step_once()` advances both nuclear chain reactions and quantum wave dispersion by exactly one `fixed_delta`.

### 4.2 `ConservationSentry` Integration
- **`NuclearDecayModule`**:
  Audits total energy including rest mass and kinetic energy:
  $$E_{total} = \sum_{i \in active} (M_i c^2 + \frac{1}{2} M_i v_i^2) + \sum_{r \in active} (m_r c^2 + \frac{1}{2} m_r v_r^2)$$
  $$\vec{P}_{total} = \sum_{i} M_i \vec{v}_i + \sum_{r} m_r \vec{v}_r$$
  Registers initial mass-energy with `ConservationSentry.register_system(initial_energy, initial_p)`.
  Any discrepancy $> 0.5\%$ triggers `conservation_warning("energy", relative_drift)`.

- **`QuantumWavepacketModule`**:
  The total probability norm $N(t) = \int |\psi|^2 dx$ is the Noether invariant of global phase symmetry ($U(1)$ gauge invariance).
  Registers $N_0 = 1.0$. Any norm drift $|N(t) - 1.0| > 0.001$ emits a conservation warning.
  For stationary potentials, expectation energy $\langle E \rangle = \int \psi^* \hat{H} \psi dx$ is audited continuously.

### 4.3 Observer Isolation Principle
- Neither module applies forces, heat, radiation, or displacement to the observer camera (`AvatarLocomotion`).
- Particles that fly out of the reaction chamber are absorbed or recycled; they do not interact with the avatar.

---

## 5. Verification Test Suite Specifications

Headless tests for both modules will reside in `res://tests/test_physics_engine_suite.gd` (or dedicated milestone suites).
All tests strictly follow Godot 4 headless rules: **no built-in `assert()`**, tracked counters, `quit(code)`.

### 5.1 Nuclear Decay Test Suite Matrix

| Test ID | Test Name | Purpose / Assertion | Expected Result | Tolerance |
|---|---|---|---|---|
| `NUC-01` | Exponential Decay Fit | Initialize 1,000 U-235 nuclei ($T_{1/2} = 10.0\text{ s}$). Run for $t = 10.0\text{ s}$ (1 half-life). | Remaining nuclei $\approx 500$ ($N_0 / 2$). | $\pm 5.0\%$ statistical error |
| `NUC-02` | 2-Body Alpha Momentum Conservation | Trigger alpha decay on stationary Ra-226. Measure $\vec{p}_{daughter} + \vec{p}_\alpha$. | $\|\vec{p}_{total}\| == 0.0$ | $< 10^{-5}$ float error |
| `NUC-03` | Alpha Decay Kinetic Energy Split | Verify $E_{k, \alpha} / E_{k, D} == M_D / M_\alpha$. | Ratio matches inverse mass ratio. | $< 10^{-4}$ |
| `NUC-04` | Induced Fission Fragment & Neutron Yield | Collide neutron into U-235 nucleus. | 2 fragments spawned, 2 to 3 prompt neutrons emitted. | Exact count match |
| `NUC-05` | SpatialHashGrid Collision Exactness | Place 500 U-235 nuclei. Fire neutron beam. Compare spatial hash hits with brute-force distance query. | 100% identical collision detections. | 0 mismatches |
| `NUC-06` | MultiMesh Zero-Node-Allocation | Monitor scene tree child count when spawning 5,000 radioactive particles. | Zero new Node3D instances created. | Child count delta == 0 |

### 5.2 Quantum Wavepacket Test Suite Matrix

| Test ID | Test Name | Purpose / Assertion | Expected Result | Tolerance |
|---|---|---|---|---|
| `QNT-01` | Unitary Norm Conservation (1D Cayley) | Evolve free Gaussian wavepacket for 2,000 steps under Crank-Nicolson. Evaluate $\sum |\psi|^2 \Delta x$. | Norm drift $\|N(t) - 1.0\| < 10^{-5}$. | Absolute drift $< 10^{-5}$ |
| `QNT-02` | Barrier Tunneling Transmission Ratio | Propagate wavepacket ($E = 4.5$) through rectangular barrier ($V_0 = 6.0, d = 0.8$). Compute empirical transmission $T_{emp} = \int_{x > d/2} |\psi|^2 dx$. | Matches analytical $T_{analytical} \approx \frac{16 E(V_0 - E)}{V_0^2} e^{-2\kappa d}$. | Relative error $< 12\%$ (due to packet dispersion) |
| `QNT-03` | Classical Turning Point & Reflection | High barrier ($V_0 = 20.0 \gg E = 4.5$). Run until packet reflects. | Reflection coefficient $R = \int_{x < 0} |\psi|^2 dx > 0.999$. | $R > 0.999$ |
| `QNT-04` | Harmonic Well Coherent Oscillation | Place packet at $x_0 = -3.0$ in $V(x) = \frac{1}{2}\omega^2 x^2$ with $\omega = 1.0$. Record $\langle x \rangle(t)$. | Packet oscillates with period $T = 2\pi / \omega \approx 6.28\text{ s}$. | Period error $< 2.0\%$ |
| `QNT-05` | 2D Staggered Leapfrog Stability | Run 2D wavepacket on $64 \times 64$ grid for 1,000 steps with $\Delta t = 0.01$. | Wavepacket remains bounded without numerical overflow (NaN/INF). | Zero NaNs, $\|N(t) - 1.0\| < 0.05$ |

---

## 6. Godot 4.0.stable Compatibility & Risk Mitigation

| Constraint / Pitfall | Mechanism in Godot 4.0.stable | Blueprint Architectural Mitigation |
|---|---|---|
| `ClassName.has_method(...)` direct call forbidden | Crashes Godot 4 compiler if called on class name | Use `Callable.is_valid()`, instance checks `obj.has_method(...)`, or explicit static typing |
| Lambda capture by value | Modifying primitive captured variables fails | Wrap mutable flags in arrays: `var finished = [false]` |
| `Callable.bind(...)` appends to tail | Bound arguments are passed *after* emitted signal parameters | Ensure signature order places bound arguments last: `func _cb(sig_arg1, sig_arg2, bound_arg1)` |
| `assert()` in headless mode | Freezes headless Godot process permanently | Replace all `assert` calls in tests with boolean checks, counters, and `quit(code)` |
| Performance degradation from node allocation | Creating 1,000+ `Node3D` nodes tanks framerate | Use contiguous `PackedVector3Array` + `MultiMeshInstance3D` |
| Floating-point underflow in nuclear/quantum scales | $10^{-15}\text{ m}$ (femtometers) or $10^{-34}\text{ J}\cdot\text{s}$ underflows `float32` | Use natural dimensionless simulation units ($\hbar = 1.0, m = 1.0, c_{sim} = 50.0$); translate to SI via `UnitConverter` |
| Complex number arithmetic in GDScript | GDScript lacks native built-in `Complex` type | Contiguous dual-array pair (`PackedFloat32Array` for real and imaginary parts) with inlined complex arithmetic |
