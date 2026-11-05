# UniCORE Fundamental Scientific Physics Simulation Platform
## Complete Specification Inventory & Architecture Analysis

**Authoritative Sources**:
- `ORIGINAL_REQUEST.md` (`c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md`)
- `scientific_simulation_architecture_spec.md` (`c:\Users\Amirrima37\.gemini\antigravity\brain\51a93ace-161d-4812-aeda-bc1b959a8496\scientific_simulation_architecture_spec.md`)
- `ARCHITECTURE.md` & `GEMINI.md` (`c:\dev\UniCORE\`)

---

## 1. Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | R1: Time Engine | `SimulationTimeController` | Central physical clock manager distributing deterministic `fixed_delta` ticks, variable time scaling ($0.001\times$ to $1000\times$), pause/unpause, step-once frame ticking, and lag death-spiral protection. | `delta: float`, `time_scale: float`, `fixed_delta: float`, `is_paused: bool` | Signals: `sim_tick(dt, sim_time)`, `time_scale_changed(scale)`, `simulation_paused(is_paused)`, `step_executed(sim_time)` | Clamps `time_scale` to $[0.001, 1000.0]$; drops excess lag if accumulated time exceeds `fixed_delta * max_substeps` | ORIGINAL_REQUEST.md § R1, Architecture Spec § 4 Task 1 |
| 2 | R1: Time Engine | `step_once()` execution | Advances physical simulation by exactly one `fixed_delta` slice on demand while paused or running. | None | Signals: `sim_tick`, `step_executed`; advances `sim_time` by exactly `fixed_delta` | No-op error prevention if `fixed_delta <= 0` | ORIGINAL_REQUEST.md § R1, Architecture Spec § 4 Task 1 |
| 3 | R1: Integrators | `PhysicalIntegrator` Base Contract | Abstract base interface for numerical integrators operating on contiguous packed buffers for zero-allocation performance. | `positions: PackedVector3Array`, `velocities: PackedVector3Array`, `masses: PackedFloat32Array`, `force_callable: Callable`, `dt: float` | In-place updates to `positions` and `velocities` | Pushes error if abstract base `integrate()` is called directly; checks array size parity | ORIGINAL_REQUEST.md § R1, Architecture Spec § 4 Task 2 |
| 4 | R1: Integrators | `VerletIntegrator` (Velocity-Verlet) | Symplectic second-order numerical integrator for conservative Hamiltonian systems ($H=T+V$), ensuring exact phase-space volume preservation and zero secular energy drift. | `positions`, `velocities`, `masses`, `force_callable`, `dt: float` | Mutates `positions` and `velocities` in-place | Rejects empty arrays, guards against $m_i \le 0$ with $10^{-12}$ minimum mass clamping | ORIGINAL_REQUEST.md § R1, Architecture Spec § 3.1 & § 4 Task 2 |
| 5 | R1: Integrators | `RK4Integrator` (Runge-Kutta 4th Order) | Classical fourth-order integrator with $O(\Delta t^4)$ local error for non-conservative, damping, velocity-dependent, or transient systems. | `positions`, `velocities`, `masses`, `force_callable`, `dt: float` | In-place updates to `positions` and `velocities` | Checks array parity, handles zero division on zero masses | ORIGINAL_REQUEST.md § R1, Architecture Spec § 4 Task 2 |
| 6 | R2: Conservation | `ConservationSentry` (Noether Watchdog) | Continuous real-time auditor of conserved quantities (total energy $E$, linear momentum $\vec{P}$, angular momentum $\vec{L}$, charge $Q$) and kinetic temperature $T$. | `positions`, `velocities`, `masses`, `potential_calculator: Callable` | Returns `Dictionary` snapshot; emits `invariants_updated`, `conservation_warning` | Triggers warning signal if $|E(t)-E(0)|/|E(0)| > energy\_tolerance$ (default $0.005$) | ORIGINAL_REQUEST.md § R2, Architecture Spec § 4 Task 3 |
| 7 | R2: Conservation | Adaptive Drift Feedback & System Registration | Registers initial baseline invariants and tracks relative drift ratio over thousands of steps. | `initial_energy: float`, `initial_linear_momentum: Vector3`, `initial_angular_momentum: Vector3` | Internal baseline state registration | Self-initializes on first audit if uninitialized; guards against division by zero ($E_0=0$) | Architecture Spec § 4 Task 3 |
| 8 | R2: Spatial Partition | `SpatialHashGrid` 3D Uniform Grid | 3D spatial hashing structure partitioning continuous space into uniform cubes of side $L=cell\_size$ for $O(N)$ short-range neighbor queries. | `cell_size: float`, `expected_capacity: int`, `particle_idx: int`, `position: Vector3`, `search_radius: float` | Returns `PackedInt32Array` of neighbor indices | Re-initializes on invalid cell size $\le 0$; handles negative spatial coordinates via floor division | ORIGINAL_REQUEST.md § R2, Architecture Spec § 4 Task 4 |
| 9 | R2: Spatial Partition | Spatial Prime Hash Function | Computes integer hash using large prime multipliers: $(ix \cdot 73856093) \oplus (iy \cdot 19349663) \oplus (iz \cdot 83492791)$. | `ix: int`, `iy: int`, `iz: int` | `int` 64-bit hash key | Correctly handles negative grid indices via integer XOR | Architecture Spec § 4 Task 4 |
| 10 | R3: Molecular Dynamics | `MolecularDynamicsModule` | Simulates microscopic Lennard-Jones 12-6 fluid/gas with Berendsen thermostat, reflective boundaries, and Maxwell-Boltzmann speed distribution rendered via `MultiMeshInstance3D`. | `UniCoreModule` context, `sim_tick(dt, sim_time)` | Visual particles, speed histogram, thermodynamics | Clamps minimum distance $r \ge 0.1\sigma$ to avoid infinite force repulsion | ORIGINAL_REQUEST.md § R3, Architecture Spec § 3.2, 3.4 & § 4 Task 5 |
| 11 | R3: Molecular Dynamics | Lennard-Jones 12-6 Shifted Potential | Computes pairwise interatomic force and potential with smooth cutoff at $r_c = 2.5\sigma$ and shifted potential $V_{shift}(r) = V(r) - V(r_c)$. | Pairwise particle distances $\vec{r}_{ij}$ | Force vectors $\vec{F}_{ij}$, potential energy $V$ | Zero force applied for $r > r_c$; minimum distance clamp prevents $r=0$ singularity | Architecture Spec § 3.2 & § 4 Task 5 |
| 12 | R3: Molecular Dynamics | Berendsen Thermostat | Regulates instantaneous kinetic temperature towards $T_{target}$ via velocity scaling factor $\lambda = \sqrt{1 + \frac{\Delta t}{\tau}(\frac{T_{target}}{T_{instant}} - 1)}$. | `target_temperature: float`, `coupling_time: float` | Scaled velocities $\vec{v}_i \leftarrow \lambda \vec{v}_i$ | If $T_{instant} \le 10^{-12}$, sets $\lambda = 1.0$ to avoid zero division | Architecture Spec § 3.4 & § 4 Task 5 |
| 13 | R3: Molecular Dynamics | Reflective Elastic Container | Enforces cubic boundary $[-L, L]^3$ with restitution elasticity $e_{refl}$. | Particle positions and velocities, box half-size $L$ | Clamped positions, reflected velocities | Prevents tunneling by clamping positions to inner surface | Architecture Spec § 4 Task 5 |
| 14 | R3: Molecular Dynamics | Maxwell-Boltzmann Speed Analyzer | Computes empirical velocity histogram of particles and compares with theoretical distribution $f(v) \propto v^2 \exp(-mv^2 / 2k_BT)$. | `bin_count: int` | `Dictionary` containing bin centers, counts, theoretical PDF | Handles zero temperature / stationary particles gracefully | Architecture Spec § 4 Task 5 |
| 15 | R3: Molecular Dynamics | GPU MultiMesh Kinetic Color Mapping | Visualizes particle speeds via `MultiMeshInstance3D` instance vertex colors (Cyan/Blue $\to$ Amber/Yellow $\to$ Red/Magenta). | Particle speeds $v_i$ | MultiMesh instance transforms and colors | Low-allocation updates directly to MultiMesh buffer | Architecture Spec § 4 Task 5 |
| 16 | R3: Relativistic N-Body | `NBodyGravityModule` | Simulates $N$-body gravitational dynamics with configurable speed of light $c_{sim}$, relativistic mass increase, Lorentz factor $\gamma$, and orbit trail visualizers. | `UniCoreModule` context, `c_sim: float`, particle masses and positions | Updated orbital trajectories, relativistic energy | Clamps $v \le 0.999 c_{sim}$ to prevent imaginary $\gamma = 1/\sqrt{1-v^2/c^2}$ | ORIGINAL_REQUEST.md § R3, Architecture Spec § 3.3 & § 4 Task 6 |
| 17 | R3: Relativistic N-Body | Softened Gravitational Potential | Evaluates gravitational force with softening parameter $\epsilon_{soft}$: $\vec{F}_{ij} = -G \frac{m_i m_j}{(r^2 + \epsilon_{soft}^2)^{3/2}} \vec{r}_{ij}$. | Particle positions, masses, softening radius | Force vectors $\vec{F}$ | Prevents $r \to 0$ numerical singularity during close encounters | Architecture Spec § 4 Task 6 |
| 18 | R3: Relativistic N-Body | 1st Post-Newtonian (1PN) Precession | Adds Einsteinian general relativistic perihelion precession correction term $\Delta \vec{a}_{1PN}$ to classical Newtonian acceleration. | Positions $\vec{r}$, velocities $\vec{v}$, central mass $M$, $c_{sim}$ | Correction acceleration vector $\Delta \vec{a}_{1PN}$ | Seamlessly transitions to purely Newtonian if post-Newtonian flag is disabled | Architecture Spec § 4 Task 6 |
| 19 | R3: Relativistic N-Body | Dynamic Orbit Path Visualizer | Renders historical orbital trajectories using cyclic line buffers (`ImmediateMesh` / `ArrayMesh`). | Particle positions history | 3D trajectory lines in laboratory frame | Clears/recycles trail buffer to prevent memory leakage | Architecture Spec § 4 Task 6 |
| 20 | R3: Nuclear Decay | `NuclearDecayModule` | Simulates stochastic Poisson radioactive decays ($\alpha$, $\beta^-$, $\gamma$), isotope library, and induced fission chain reactions. | Isotope parameters, decay probabilities, neutron collisions | Emitted particles, daughter isotopes, reaction energy | Conserves 4-momentum and rest mass-energy $Q = \Delta M c^2$ | ORIGINAL_REQUEST.md § R3, Architecture Spec § 3.5 & § 4 Task 7 |
| 21 | R3: Nuclear Decay | Poisson Decay Channels ($\alpha, \beta^-, \gamma$) | Discrete stochastic decay evaluation: $P_{decay} = 1 - e^{-\lambda \Delta t}$ with $\lambda = \ln 2 / T_{1/2}$. | Half-life $T_{1/2}$, elapsed time $\Delta t$, uniform random $U \in [0, 1)$ | Decay event trigger, daughter creation, particle ejection | When $\Delta t \ll T_{1/2}$, avoids underflow; when $\Delta t \gg T_{1/2}$, $P_{decay} \to 1.0$ | Architecture Spec § 3.5 & § 4 Task 7 |
| 22 | R3: Nuclear Decay | Built-in Isotope Database | Predefined physical isotopes: $^{235}\text{U}$, $^{226}\text{Ra}$, $^{14}\text{C}$, $^3\text{H}$ (Tritium), $^2\text{H}$ (Deuterium), $^4\text{He}$ ($\alpha$), free neutron. | Isotope name/key | Mass $A$, atomic number $Z$, half-life $T_{1/2}$, decay mode, $Q$-value | Fallback to generic radioactive isotope if unknown key queried | Architecture Spec § 4 Task 7 |
| 23 | R3: Nuclear Decay | Induced Fission Chain Reaction | Simulates neutron capture by $^{235}\text{U}$, splitting nucleus into 2 fragments plus 2-3 free prompt neutrons. | Neutron collision within capture cross-section $\sigma_f$ | Fragment particles, ejected neutrons, $Q \approx 200\text{ MeV}$ | Caps maximum active particle count to prevent engine out-of-memory | Architecture Spec § 4 Task 7 |
| 24 | R3: Quantum Wavepacket | `QuantumWavePacketModule` | Simulates time-dependent Schrödinger equation $i\hbar \frac{\partial \psi}{\partial t} = -\frac{\hbar^2}{2m}\nabla^2\psi + V\psi$ for complex wavefunction on discrete lattice. | Spatial grid resolution, potential profile $V(x)$, initial $\psi(x, 0)$ | Probability density $|\psi|^2$, phase angle $\arg(\psi)$, transmission $T$ | Preserves unitary norm $\sum |\psi_j|^2 \Delta x = 1.0$ | ORIGINAL_REQUEST.md § R3, Architecture Spec § 4 Task 8 |
| 25 | R3: Quantum Wavepacket | Unitary Cayley / Staggered Time Evolution | Propagates real and imaginary components of $\psi$ maintaining exact norm conservation and stability. | $\psi_R$, $\psi_I$, potential $V$, grid spacing $\Delta x$, $\Delta t$ | Updated $\psi(t + \Delta t)$ | Satisfies Courant-Friedrichs-Lewy (CFL) stability criterion $\frac{\hbar \Delta t}{2m \Delta x^2} \le 0.5$ | Architecture Spec § 4 Task 8 |
| 26 | R3: Quantum Wavepacket | Quantum Tunneling & Barrier Potentials | Configurable potentials (square barrier $V_0$, harmonic well, double slit); computes transmission coefficient $T \approx e^{-2\kappa d}$. | Barrier height $V_0$, barrier width $d$, wavepacket energy $E$ | Transmitted vs reflected wave components | Bounded reflection/transmission ratios $[0.0, 1.0]$ | Architecture Spec § 4 Task 8 |
| 27 | R3: Quantum Wavepacket | Quantum Visualization (Height & Phase) | Visualizes probability density as mesh height/displacement and quantum phase angle $\phi = \text{atan2}(\psi_I, \psi_R)$ as cyclic color hue. | Complex $\psi(x)$ array | 3D surface/ribbon with phase-mapped vertex colors | Normalizes visual scale to prevent mesh clipping | Architecture Spec § 4 Task 8 |
| 28 | Related: Unit Scaling | `UnitConverter` | Bidirectional conversion between SI units and reduced natural/simulation units (Lennard-Jones, Planck, Astronomical). | Physical quantities in SI or Simulation units | Scaled float values in safe IEEE-754 range | Throws clear error on unknown unit system or negative scale | Architecture Spec § 2 & § 1 Tenet 4 |
| 29 | Related: Spatial Partition | `BarnesHutOctree` | 3D hierarchical octree for long-range $O(N \log N)$ gravitational and electrostatic $1/r^2$ forces with multipole opening angle $\theta = s/d$. | Spatial bounds, particle positions and masses, $\theta_{crit} \approx 0.5$ | Approximated long-range forces | Gracefully handles empty child nodes and coincident particle positions | Architecture Spec § 2 & § 1 Tenet 5 |
| 30 | Related: Special Relativity | `RelativisticParticleModule` | Specialized testbench for relativistic mechanics, Lorentz boost transformations, and Doppler beaming. | Particle velocity $\vec{v}$, lab coordinates | Boosted 4-vectors $(ct', \vec{r}')$, Doppler factor $D$ | Clamps speed below $c_{sim}$ | Architecture Spec § 2 & § 3.3 |
| 31 | Related: Probing | `ScientificProbeModule` | Non-invasive 3D measurement probes and field spectrum analyzers placed in space. | Probe coordinates, target field callables | Recorded local field measurements $(E, B, T, \Phi)$ | Non-perturbing: does not exert force on measured particles | Architecture Spec § 2 |
| 32 | Related: Shaders | `RelativisticMeshShader` | Vertex and fragment shader rendering real-time Lorentz contraction and Doppler color shifting on 3D meshes. | Mesh vertices, velocity vector $\vec{v}$, camera vector $\hat{k}$ | Deformed vertex positions, Doppler-shifted fragment color | Clamps $\beta < 1.0$ in shader uniform | Architecture Spec § 2 & § 3.3 |
| 33 | Related: Shaders | `ParticleFieldGlowShader` | Energy/temperature gradient billboard/point shader for massive particle rendering. | Vertex colors, temperature scalar | Glowing radial Gaussian particle billboards | Zero expensive texture lookups, purely analytical | Architecture Spec § 2 |
| 34 | Related: Environment | Sterile Vacuum Space Baseline | Default laboratory environment in `SpaceManager`: surface-less 3D vacuum, zero arbitrary gravity, external observer frame. | Space manifest parameters | Vacuum world root, floating reference grid | Observer camera immune to all physical forces | Architecture Spec § 1 Tenet 1, 2 |
| 35 | Related: Testing | Automated Headless Test Suite | Comprehensive headless test suite verifying all integrators, sentries, grids, and modules. | Test scenarios (harmonic oscillator, Kepler, 5000-particle grid, Poisson decay, tunneling) | Assertion counts, pass/fail exit code ($0$ or $1$) | Banned `assert()`: uses custom `assert_true` and `quit(code)` | GEMINI.md § 3, Architecture Spec § 5 |

---

## 2. Component Technical Specifications & API Contracts

### 2.1 SimulationTimeController
- **Target Path**: `res://core/physics/simulation_time_controller.gd`
- **Class Name**: `SimulationTimeController`
- **Extends**: `Node`
- **Public Properties**:
  ```gdscript
  @export var time_scale: float = 1.0       # Clamp: [0.001, 1000.0]
  @export var fixed_delta: float = 0.01     # Base simulation step in seconds (10 ms)
  @export var is_paused: bool = false       # Simulation pause toggle
  @export var max_substeps: int = 10        # Max fixed-delta ticks per physics frame
  var sim_time: float = 0.0                 # Total accumulated physical simulation time
  var _accumulator: float = 0.0             # Internal frame time accumulator
  ```
- **Signals**:
  ```gdscript
  signal sim_tick(dt: float, sim_time: float)
  signal time_scale_changed(new_scale: float)
  signal simulation_paused(is_paused: bool)
  signal step_executed(sim_time: float)
  ```
- **Public Methods**:
  ```gdscript
  func set_time_scale(scale: float) -> void
  func toggle_pause() -> void
  func set_paused(paused: bool) -> void
  func step_once() -> void
  func reset() -> void
  func _physics_process(delta: float) -> void
  ```
- **Algorithmic Contract**:
  - `_physics_process(delta)`:
    - If `is_paused`: return.
    - `_accumulator += delta * time_scale`
    - `var steps: int = 0`
    - `while _accumulator >= fixed_delta and steps < max_substeps:`
      - `_accumulator -= fixed_delta`
      - `sim_time += fixed_delta`
      - `sim_tick.emit(fixed_delta, sim_time)`
      - `steps += 1`
    - If `_accumulator > fixed_delta * float(max_substeps)`:
      - `_accumulator = 0.0` # Drop excess lag to prevent death spiral.
  - `step_once()`:
    - `sim_time += fixed_delta`
    - `sim_tick.emit(fixed_delta, sim_time)`
    - `step_executed.emit(sim_time)`

---

### 2.2 Numerical Integrators Hierarchy

#### 2.2.1 PhysicalIntegrator (Abstract Base)
- **Target Path**: `res://core/physics/physical_integrator.gd`
- **Class Name**: `PhysicalIntegrator`
- **Extends**: `RefCounted`
- **Public Methods**:
  ```gdscript
  func integrate(
      positions: PackedVector3Array,
      velocities: PackedVector3Array,
      masses: PackedFloat32Array,
      force_callable: Callable,
      dt: float
  ) -> void:
      push_error("PhysicalIntegrator.integrate() is abstract and must be overridden")
  ```

#### 2.2.2 VerletIntegrator (Velocity-Verlet)
- **Target Path**: `res://core/physics/verlet_integrator.gd`
- **Class Name**: `VerletIntegrator`
- **Extends**: `PhysicalIntegrator`
- **Algorithm & Signatures**:
  ```gdscript
  func integrate(
      positions: PackedVector3Array,
      velocities: PackedVector3Array,
      masses: PackedFloat32Array,
      force_callable: Callable,
      dt: float
  ) -> void
  ```
- **Symplectic Step Equations**:
  1. $\vec{F}_0 = force\_callable.call(positions)$
  2. $\vec{a}_0[i] = \vec{F}_0[i] / \max(masses[i], 10^{-12})$
  3. $\vec{r}_{new}[i] = \vec{r}_0[i] + \vec{v}_0[i] \cdot \Delta t + 0.5 \cdot \vec{a}_0[i] \cdot \Delta t^2$
  4. Write $\vec{r}_{new}$ back to `positions`.
  5. $\vec{F}_{new} = force\_callable.call(positions)$
  6. $\vec{a}_{new}[i] = \vec{F}_{new}[i] / \max(masses[i], 10^{-12})$
  7. $\vec{v}_{new}[i] = \vec{v}_0[i] + 0.5 \cdot (\vec{a}_0[i] + \vec{a}_{new}[i]) \cdot \Delta t$
  8. Write $\vec{v}_{new}$ back to `velocities`.
- **Invariants**:
  - Symplectic: Preserves phase space 2-form $d\vec{r} \wedge d\vec{p}$.
  - Harmonic oscillator relative energy drift $|(E(t) - E_0)/E_0| < 0.001$ over 5,000 steps.

#### 2.2.3 RK4Integrator (Runge-Kutta 4th Order)
- **Target Path**: `res://core/physics/rk4_integrator.gd`
- **Class Name**: `RK4Integrator`
- **Extends**: `PhysicalIntegrator`
- **Algorithm & Signatures**:
  ```gdscript
  func integrate(
      positions: PackedVector3Array,
      velocities: PackedVector3Array,
      masses: PackedFloat32Array,
      force_callable: Callable,
      dt: float
  ) -> void
  ```
- **Four-Stage Classical ODE Solver**:
  - $k_{1,v} = \vec{F}(positions) / m$, $k_{1,r} = velocities$
  - Intermediate 1: $pos_1 = positions + 0.5 \Delta t k_{1,r}$, $vel_1 = velocities + 0.5 \Delta t k_{1,v}$
  - $k_{2,v} = \vec{F}(pos_1) / m$, $k_{2,r} = vel_1$
  - Intermediate 2: $pos_2 = positions + 0.5 \Delta t k_{2,r}$, $vel_2 = velocities + 0.5 \Delta t k_{2,v}$
  - $k_{3,v} = \vec{F}(pos_2) / m$, $k_{3,r} = vel_2$
  - Intermediate 3: $pos_3 = positions + \Delta t k_{3,r}$, $vel_3 = velocities + \Delta t k_{3,v}$
  - $k_{4,v} = \vec{F}(pos_3) / m$, $k_{4,r} = vel_3$
  - Final Update:
    $positions += \frac{\Delta t}{6} (k_{1,r} + 2 k_{2,r} + 2 k_{3,r} + k_{4,r})$
    $velocities += \frac{\Delta t}{6} (k_{1,v} + 2 k_{2,v} + 2 k_{3,v} + k_{4,v})$

---

### 2.3 ConservationSentry
- **Target Path**: `res://core/physics/conservation_sentry.gd`
- **Class Name**: `ConservationSentry`
- **Extends**: `Node`
- **Properties**:
  ```gdscript
  @export var energy_tolerance: float = 0.005              # 0.5% relative error threshold
  @export var momentum_tolerance: float = 0.01            # 1.0% momentum drift threshold
  @export var angular_momentum_tolerance: float = 0.01    # 1.0% angular momentum drift
  var initial_energy: float = 0.0
  var initial_linear_momentum: Vector3 = Vector3.ZERO
  var initial_angular_momentum: Vector3 = Vector3.ZERO
  var is_registered: bool = false
  ```
- **Signals**:
  ```gdscript
  signal invariants_updated(snapshot: Dictionary)
  signal conservation_warning(violation_type: String, relative_drift: float)
  ```
- **Methods**:
  ```gdscript
  func register_system(initial_e: float, initial_p: Vector3 = Vector3.ZERO, initial_l: Vector3 = Vector3.ZERO) -> void
  func audit(
      positions: PackedVector3Array,
      velocities: PackedVector3Array,
      masses: PackedFloat32Array,
      potential_calculator: Callable
  ) -> Dictionary
  func reset() -> void
  ```
- **Audit Equations**:
  - $E_{kin} = \sum_{i=0}^{N-1} \frac{1}{2} masses[i] \cdot |\vec{v}_i|^2$
  - $E_{pot} = potential\_calculator.call(positions)$
  - $E_{total} = E_{kin} + E_{pot}$
  - $\text{drift} = \frac{|E_{total} - initial\_energy|}{\max(|initial\_energy|, 10^{-12})}$
  - $\vec{P} = \sum_{i=0}^{N-1} masses[i] \cdot \vec{v}_i$
  - $\vec{L} = \sum_{i=0}^{N-1} \vec{r}_i \times (masses[i] \cdot \vec{v}_i)$
  - $T = \frac{2}{3 N k_B} E_{kin}$ (reduced units $k_B = 1.0$)
  - `is_conserved = (drift <= energy_tolerance)`
  - Returns Dictionary matching spec schema.

---

### 2.4 SpatialHashGrid
- **Target Path**: `res://core/physics/spatial_hash_grid.gd`
- **Class Name**: `SpatialHashGrid`
- **Extends**: `RefCounted`
- **Properties & Constants**:
  ```gdscript
  const P1: int = 73856093
  const P2: int = 19349663
  const P3: int = 83492791
  var cell_size: float = 1.0
  var inverse_cell_size: float = 1.0
  var _grid: Dictionary = {}  # int (hash) -> PackedInt32Array
  ```
- **Methods**:
  ```gdscript
  func initialize(p_cell_size: float, expected_capacity: int = 10000) -> void
  func clear() -> void
  func insert(particle_idx: int, position: Vector3) -> void
  func build_grid(positions: PackedVector3Array) -> void
  func get_neighbors(position: Vector3, search_radius: float) -> PackedInt32Array
  func get_neighbors_in_radius(position: Vector3, search_radius: float, positions: PackedVector3Array) -> PackedInt32Array
  func hash_coords(ix: int, iy: int, iz: int) -> int
  ```
- **Mathematical Coordinate Mapping**:
  - $ix = \text{int}(\text{floor}(position.x \cdot inverse\_cell\_size))$
  - $iy = \text{int}(\text{floor}(position.y \cdot inverse\_cell\_size))$
  - $iz = \text{int}(\text{floor}(position.z \cdot inverse\_cell\_size))$
  - $hash = (ix \cdot P1) \text{ \^{} } (iy \cdot P2) \text{ \^{} } (iz \cdot P3)$
- **Neighbor Search Box**:
  - $min\_ix = \text{int}(\text{floor}((position.x - search\_radius) \cdot inverse\_cell\_size))$
  - $max\_ix = \text{int}(\text{floor}((position.x + search\_radius) \cdot inverse\_cell\_size))$
  - Same for $y$ and $z$.
  - Iterates through the cubic subgrid, retrieves candidate particle indices, and returns filtered set within radius.

---

### 2.5 MolecularDynamicsModule
- **Target Path**: `res://modules/physics/molecular_dynamics_module.gd`
- **Class Name**: `MolecularDynamicsModule`
- **Extends**: `UniCoreModule`
- **Configurable Parameters & Properties**:
  ```gdscript
  @export var particle_count: int = 500
  @export var epsilon: float = 1.0           # Potential well depth (energy scale)
  @export var sigma: float = 1.0             # Finite distance at which inter-particle potential is zero
  @export var cutoff_radius: float = 2.5     # r_c = 2.5 * sigma
  @export var target_temperature: float = 1.0
  @export var thermostat_tau: float = 0.5    # Berendsen thermostat coupling constant
  @export var box_half_extent: float = 10.0  # Container bounds [-L, L]^3
  @export var restitution: float = 1.0       # Container wall restitution elasticity
  ```
- **Internal State & Structures**:
  ```gdscript
  var positions: PackedVector3Array
  var velocities: PackedVector3Array
  var masses: PackedFloat32Array
  var multimesh_instance: MultiMeshInstance3D
  var integrator: VerletIntegrator
  var spatial_grid: SpatialHashGrid
  var sentry: ConservationSentry
  ```
- **Physical Equations**:
  - **Lennard-Jones Force Vector**:
    $$\vec{F}_{ij} = 24 \frac{\epsilon}{\sigma^2} \left[ 2 \left(\frac{\sigma}{r}\right)^{14} - \left(\frac{\sigma}{r}\right)^8 \right] \vec{r}_{ij}$$
    Cutoff: For $r > r_c$, $\vec{F}_{ij} = 0$.
    Singularity clamp: $r_{clamped} = \max(r, 0.1\sigma)$.
  - **Shifted LJ Potential**:
    $$V_{shift}(r) = 4\epsilon \left[ \left(\frac{\sigma}{r}\right)^{12} - \left(\frac{\sigma}{r}\right)^6 \right] - V(r_c)$$
  - **Berendsen Thermostat Velocity Scaling**:
    $$\lambda = \sqrt{1 + \frac{\Delta t}{\tau} \left(\frac{T_{target}}{T_{instant}} - 1\right)}, \quad \vec{v}_i \leftarrow \lambda \vec{v}_i$$
- **Action Bindings (`get_action_bindings`)**:
  - `KEY_UP` ("md_heat_up"): $T_{target} \leftarrow T_{target} \times 1.1$
  - `KEY_DOWN` ("md_cool_down"): $T_{target} \leftarrow T_{target} \times 0.9$
  - `KEY_P` ("md_compress_box"): $box\_half\_extent \leftarrow \max(2.0, box\_half\_extent \times 0.9)$
  - `KEY_O` ("md_expand_box"): $box\_half\_extent \leftarrow box\_half\_extent \times 1.1$

---

### 2.6 NBodyGravityModule
- **Target Path**: `res://modules/physics/n_body_gravity_module.gd`
- **Class Name**: `NBodyGravityModule`
- **Extends**: `UniCoreModule`
- **Properties**:
  ```gdscript
  @export var gravitational_constant: float = 1.0     # Scaled G
  @export var speed_of_light: float = 50.0             # c_sim (5.0 to 100.0 for visible relativity)
  @export var softening_parameter: float = 0.05       # epsilon_soft
  @export var enable_post_newtonian: bool = true       # 1PN precession toggle
  @export var max_trail_points: int = 200              # Trail history length per body
  ```
- **Equations**:
  - Newtonian Gravitational Acceleration with Softening:
    $$\vec{a}_{N, i} = \sum_{j \neq i} -G \frac{m_j}{(|\vec{r}_i - \vec{r}_j|^2 + \epsilon_{soft}^2)^{3/2}} (\vec{r}_i - \vec{r}_j)$$
  - Relativistic Lorentz Factor & Momentum:
    $$\beta = \frac{|\vec{v}|}{c_{sim}}, \quad \gamma = \frac{1}{\sqrt{\max(1.0 - \beta^2, 10^{-6})}}, \quad \vec{p} = \gamma m \vec{v}$$
  - Relativistic Velocity Cap:
    $$|\vec{v}| \le 0.999 \cdot c_{sim}$$
  - 1st Post-Newtonian Precession:
    $$\Delta \vec{a}_{1PN, i} = \sum_{j \neq i} \frac{G m_j}{c_{sim}^2 r_{ij}^3} \left[ \left(4 \frac{G m_j}{r_{ij}} - |\vec{v}_i|^2\right) \vec{r}_{ij} + 4 (\vec{r}_{ij} \cdot \vec{v}_i) \vec{v}_i \right]$$
- **Visualizer**:
  - MultiMesh for celestial spheres.
  - Orbit path line renderer (`ImmediateMesh` or line nodes) displaying recent trajectory.

---

### 2.7 NuclearDecayModule
- **Target Path**: `res://modules/physics/nuclear_decay_module.gd`
- **Class Name**: `NuclearDecayModule`
- **Extends**: `UniCoreModule`
- **Properties**:
  ```gdscript
  @export var simulation_timescale_years: float = 1.0   # Mapping from sim_time seconds to physical years/seconds
  @export var initial_u235_count: int = 500
  @export var initial_ra226_count: int = 500
  @export var fission_neutron_yield_min: int = 2
  @export var fission_neutron_yield_max: int = 3
  @export var fission_cross_section_radius: float = 0.3 # Collision distance for induced fission
  ```
- **Isotope Database Schema (`Dictionary`)**:
  ```gdscript
  {
      "U235": { "name": "Uranium-235", "Z": 92, "A": 235, "half_life": 7.04e8, "mode": "alpha_fission", "q_value_mev": 4.68, "fissile": true },
      "Ra226": { "name": "Radium-226", "Z": 88, "A": 226, "half_life": 1600.0, "mode": "alpha", "q_value_mev": 4.87, "fissile": false },
      "C14": { "name": "Carbon-14", "Z": 6, "A": 14, "half_life": 5730.0, "mode": "beta_minus", "q_value_mev": 0.156, "fissile": false },
      "H3": { "name": "Tritium", "Z": 1, "A": 3, "half_life": 12.32, "mode": "beta_minus", "q_value_mev": 0.0186, "fissile": false },
      "H2": { "name": "Deuterium", "Z": 1, "A": 2, "half_life": -1.0, "mode": "stable", "q_value_mev": 0.0, "fissile": false },
      "He4": { "name": "Helium-4 (Alpha)", "Z": 2, "A": 4, "half_life": -1.0, "mode": "stable", "q_value_mev": 0.0, "fissile": false },
      "Neutron": { "name": "Free Neutron", "Z": 0, "A": 1, "half_life": 880.0, "mode": "beta_minus", "q_value_mev": 0.782, "fissile": false }
  }
  ```
- **Decay Probability Formula**:
  $$\lambda = \frac{\ln 2}{T_{1/2}}, \quad P_{decay} = 1.0 - \exp(-\lambda \cdot \Delta t)$$
  If random $U \in [0.0, 1.0) < P_{decay}$:
  - Spawn daughter nucleus and ejected particle ($\alpha$ particle or electron/neutrino).
  - Apply 4-momentum conservation: $\vec{p}_{daughter} = -\vec{p}_{ejected}$, with kinetic energy from $Q$-value.
- **Induced Fission**:
  When a free neutron passes within `fission_cross_section_radius` of a fissile nucleus ($^{235}\text{U}$), trigger fission:
  - Remove original nucleus and projectile neutron.
  - Spawn 2 fission fragments (e.g., $^{141}\text{Ba}$, $^{92}\text{Kr}$).
  - Eject 2 to 3 fast prompt neutrons with isotropic directions.

---

### 2.8 QuantumWavePacketModule
- **Target Path**: `res://modules/physics/quantum_wavepacket_module.gd`
- **Class Name**: `QuantumWavePacketModule`
- **Extends**: `UniCoreModule`
- **Properties**:
  ```gdscript
  @export var grid_size: int = 256            # Spatial lattice points
  @export var dx: float = 0.1                 # Lattice step
  @export var hbar: float = 1.0               # Scaled Planck constant
  @export var particle_mass: float = 1.0      # Scaled mass
  @export var barrier_type: String = "square" # "none", "square", "harmonic", "double_barrier"
  @export var barrier_height: float = 2.0     # V_0
  @export var barrier_center: float = 0.0     # Center position
  @export var barrier_width: float = 1.0      # Thickness d
  @export var wavepacket_x0: float = -6.0     # Initial packet center
  @export var wavepacket_sigma: float = 0.8   # Packet spatial width
  @export var wavepacket_k0: float = 3.0      # Initial wave number (E = hbar^2 k0^2 / 2m)
  ```
- **Wavefunction Representation**:
  ```gdscript
  var psi_real: PackedFloat32Array
  var psi_imag: PackedFloat32Array
  var potential_v: PackedFloat32Array
  ```
- **Algorithms**:
  - **Initial Gaussian Wavepacket**:
    $$\psi(x_j) = \frac{1}{(2\pi \sigma^2)^{1/4}} \exp\left(-\frac{(x_j - x_0)^2}{4\sigma^2}\right) \cdot \left[\cos(k_0 x_j) + i \sin(k_0 x_j)\right]$$
  - **Unitary Staggered Leapfrog Evolution**:
    $$\hat{H}\psi(x_j) = -\frac{\hbar^2}{2m} \frac{\psi(x_{j+1}) - 2\psi(x_j) + \psi(x_{j-1})}{\Delta x^2} + V(x_j)\psi(x_j)$$
    $$\psi_R(t + \Delta t) = \psi_R(t) + \frac{\Delta t}{\hbar} \hat{H}\psi_I\left(t + \frac{\Delta t}{2}\right)$$
    $$\psi_I\left(t + \frac{3\Delta t}{2}\right) = \psi_I\left(t + \frac{\Delta t}{2}\right) - \frac{\Delta t}{\hbar} \hat{H}\psi_R(t + \Delta t)$$
  - **Observables**:
    - Probability density: $\rho(x_j) = \psi_R^2(x_j) + \psi_I^2(x_j)$
    - Total probability: $P_{tot} = \sum_j \rho(x_j) \Delta x \approx 1.0$
    - Transmission probability: $T = \sum_{x_j > x_{barrier\_end}} \rho(x_j) \Delta x$
    - Reflection probability: $R = \sum_{x_j < x_{barrier\_start}} \rho(x_j) \Delta x$

---

## 3. Edge Cases & Numerical Robustness Analysis

| # | Feature | Input / Condition | Observed / Required Behavior |
|---|---------|-------------------|-----------------------------|
| 1 | `SimulationTimeController` | `time_scale = 0.0` or negative | Clamped to minimum $0.001$; avoids zero or backward time step corruption. |
| 2 | `SimulationTimeController` | Sudden frame drop ($\Delta t > 1.0\text{ s}$) | Substep loop capped at `max_substeps = 10`; remaining accumulator clamped to 0 to prevent death spiral. |
| 3 | `SimulationTimeController` | `step_once()` called while paused | Advances `sim_time` by exactly `fixed_delta`; emits `sim_tick` and `step_executed`; accumulator unaffected. |
| 4 | `VerletIntegrator` | Empty arrays ($N = 0$) | Immediate safe return with no errors or null pointer exceptions. |
| 5 | `VerletIntegrator` | Mismatched array sizes (`positions.size() != velocities.size()`) | Aborts step with `push_error`; does not mutate arrays partially. |
| 6 | `VerletIntegrator` | Particle mass $m_i \le 0.0$ | Clamped to $10^{-12}$ to avoid IEEE-754 division by zero / `INF` acceleration. |
| 7 | `SpatialHashGrid` | Particles with negative coordinates ($x < 0, y < 0, z < 0$) | Uses `floor()` before casting to integer coordinates; prime XOR hash handles negative integers without out-of-bounds error. |
| 8 | `SpatialHashGrid` | Search radius $R \le 0$ or `cell_size <= 0` | If `cell_size <= 0`, defaults to $1.0$; if $R \le 0$, returns empty or self-only index array. |
| 9 | `SpatialHashGrid` | Coincident particles ($r_{ij} = 0$) | Both particles placed in identical bucket; distance check handles $r = 0$ safely without division by zero. |
| 10 | `MolecularDynamicsModule` | Interatomic collision with $r_{ij} \to 0$ | Distance $r$ clamped to $r_{min} = 0.1\sigma$; prevents Lennard-Jones $r^{-14}$ potential explosion to infinity. |
| 11 | `MolecularDynamicsModule` | Zero temperature ($T_{instant} = 0$) in Berendsen Thermostat | Thermostat scale factor $\lambda$ defaults to $1.0$; skips zero division. |
| 12 | `MolecularDynamicsModule` | High velocity particle hitting container wall | Position clamped exactly to boundary surface $[-L, L]$; velocity component flipped with restitution factor. |
| 13 | `NBodyGravityModule` | Relativistic speed approaches $c_{sim}$ ($v \to c$) | Velocity magnitude clamped to $0.999 \cdot c_{sim}$; prevents negative radical in $\gamma = 1/\sqrt{1 - v^2/c^2}$. |
| 14 | `NBodyGravityModule` | Celestial collision / near-miss ($r \to 0$) | Gravitational acceleration softened with $\epsilon_{soft} > 0$; forces remain finite and smooth. |
| 15 | `NuclearDecayModule` | Time step $\Delta t$ larger than isotope half-life $T_{1/2}$ | Probability $P_{decay} = 1 - e^{-\lambda \Delta t}$ smoothly approaches $1.0$; does not exceed $1.0$. |
| 16 | `NuclearDecayModule` | Fission chain reaction runaway ($N \to \infty$) | Particle count capped at safe upper threshold (e.g. 5,000 particles); excess neutrons absorbed to prevent OOM crash. |
| 17 | `QuantumWavePacketModule` | Grid spacing violates CFL stability condition | Time step $\Delta t$ verified against $\Delta t \le \frac{m \Delta x^2}{\hbar}$; warning logged if unstable. |
| 18 | `QuantumWavePacketModule` | Wavepacket reaches edge of spatial grid | Dirichlet or absorbing imaginary potential boundary conditions prevent spurious reflection from simulation domain boundaries. |

---

## 4. Acceptance Criteria & Exact Verification Formulas

### 4.1 Numerical Rigor & Phase-Space Conservation
1. **Harmonic Oscillator Symplectic Test**:
   - Equation of motion: $\ddot{x} = -\frac{k}{m} x$ with $k=1.0, m=1.0$, initial $x(0) = 1.0, v(0) = 0.0$.
   - Energy: $E(t) = \frac{1}{2} m v(t)^2 + \frac{1}{2} k x(t)^2$. Initial energy $E_0 = 0.5$.
   - **Acceptance Criterion**: Over 5,000 steps with $\Delta t = 0.01$, relative energy drift:
     $$\text{drift} = \frac{|E(5000) - E_0|}{E_0} < 0.001 \quad (0.1\%)$$
2. **2-Body Kepler Orbit Test**:
   - Gravitational 2-body system in circular orbit: $r = 1.0, v = \sqrt{G M / r} = 1.0$.
   - Total energy $E = \frac{1}{2}\mu v^2 - \frac{G M \mu}{r}$ and angular momentum $\vec{L} = \vec{r} \times \vec{p}$.
   - **Acceptance Criterion**: ConservationSentry verifies $\text{drift} < 0.001$ and $\vec{L} \approx \text{const}$ over multiple orbits.

### 4.2 Spatial Partitioning Complexity & Benchmark
1. **5,000 Particle Neighbor Query Performance**:
   - Uniform random distribution in $50 \times 50 \times 50$ box ($N = 5000$).
   - Search radius $R = 2.5$.
   - **Acceptance Criterion 1 (Equivalence)**: `SpatialHashGrid.get_neighbors(pos, R)` returns exact same set of particle indices as brute-force $O(N^2)$ distance scan $\forall j: |\vec{r}_j - \vec{r}| \le R$.
   - **Acceptance Criterion 2 (Timing)**: Total grid build and full neighbor queries for 5,000 particles execute within 10 ms (or single query benchmark $< 0.05$ ms, showing clear $O(N)$ vs $O(N^2)$ scaling).

### 4.3 Simulation Time Stepping & Determinism
1. **Discrete Accumulation & Pause**:
   - When paused, engine emits 0 `sim_tick` signals during `_physics_process`.
   - Single call to `step_once()` advances `sim_time` by exactly `fixed_delta` (e.g. $0.0 + 0.01 = 0.0100000$).
   - Emits exactly 1 `sim_tick` and 1 `step_executed` signal.

### 4.4 Engine Compatibility & Static Typing
1. **Zero Untyped Variants**:
   - GDScript 2.0 strict static typing on all classes, methods, parameters, and return types.
   - Project validation check:
     `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`
     Must terminate with exit code 0 and zero warnings.
2. **Data-Oriented Particle Architecture**:
   - Particle systems use `MultiMeshInstance3D` exclusively. Zero individual `Node3D` nodes allocated per particle.
3. **Observer Immunity**:
   - External observer avatar/camera is unaffected by forces, fields, and radiation.
