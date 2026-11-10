# Project: UniCORE Fundamental Scientific Physics Simulation Platform

## Architecture
UniCORE transforms into a fundamental computational physics simulation laboratory under the Scientific Observer Paradigm:
- **Observer Isolation**: The user/camera is strictly in an external laboratory reference frame (`avatar_locomotion.gd`), immune to gravity, heat, radiation, and relativistic dilation.
- **Sterile Vacuum Baseline**: Surface-less 3D vacuum (`SpaceManager` template), modular boundary conditions.
- **Physical Integration Core**: `SimulationTimeController` manages discrete `fixed_delta` ticks with substepping and pause. Symplectic Velocity-Verlet preserves the Hamiltonian phase-space 2-form ($d\vec{r} \wedge d\vec{p}$); RK4 provides 4th-order local accuracy for dissipative systems.
- **Conservation & Partitioning**: `ConservationSentry` continuously verifies Noether invariants ($E, \vec{P}, \vec{L}, Q$) and kinetic temperature. `SpatialHashGrid` accelerates short-range forces to $O(N)$. `BarnesHutOctree` accelerates long-range $1/r^2$ forces to $O(N \log N)$.
- **Domain Modules**: Modules inherit from `UniCoreModule`, communicate via `EventBus`, simulate packed contiguous arrays, and render thousands of particles in a single draw call via `MultiMeshInstance3D`.
- **Headless Test Suite**: `res://tests/test_physics_engine_suite.gd` extends `SceneTree`, avoids built-in `assert()`, tracks test counters, and exits with `quit(code)` compatible with `test_runner.gd`.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | SimulationTimeController | Central clock distributing fixed_delta ticks, variable scale, pause, step-by-step | M1 | ORIGINAL_REQUEST § R1 |
| 2 | step_once execution | Advances physical time by exactly fixed_delta on demand | M1 | ORIGINAL_REQUEST § R1 |
| 3 | PhysicalIntegrator base contract | Abstract interface for numerical integrators operating on packed arrays | M1 | Architecture Spec § 4 Task 2 |
| 4 | VerletIntegrator (Velocity-Verlet) | Symplectic 2nd-order integrator for Hamiltonian conservative systems | M1 | ORIGINAL_REQUEST § R1 |
| 5 | RK4Integrator (Runge-Kutta 4) | Classical 4th-order integrator for velocity-dependent/dissipative systems | M1 | ORIGINAL_REQUEST § R1 |
| 6 | UnitConverter | Conversion between SI units and reduced natural units (LJ, Planck, Astro) | M1 | Architecture Spec § 2 |
| 7 | ConservationSentry | Continuous auditor of Noether invariants (E, P, L, Q) and temperature | M2 | ORIGINAL_REQUEST § R2 |
| 8 | Adaptive Drift Feedback | Tracks energy drift ratio and emits warnings if drift > tolerance (0.005) | M2 | Architecture Spec § 4 Task 3 |
| 9 | SpatialHashGrid 3D uniform grid | 3D spatial hashing partitioning space into cubes for O(N) neighbor queries | M2 | ORIGINAL_REQUEST § R2 |
| 10 | Spatial prime hash function | Primes (ix*73856093) ^ (iy*19349663) ^ (iz*83492791) | M2 | Architecture Spec § 4 Task 4 |
| 11 | BarnesHutOctree | 3D hierarchical tree for O(N log N) gravitational/electrostatic forces | M2 | Architecture Spec § 2 |
| 12 | MolecularDynamicsModule | Lennard-Jones gas/liquid module extending UniCoreModule | M3 | ORIGINAL_REQUEST § R3 |
| 13 | Lennard-Jones 12-6 shifted potential | Pairwise interatomic force and potential with cutoff r_c = 2.5 sigma | M3 | Architecture Spec § 3.2 |
| 14 | Berendsen thermostat | Regulates kinetic temperature via velocity scaling factor lambda | M3 | ORIGINAL_REQUEST § R3 |
| 15 | Reflective elastic container | Enforces cubic boundary [-L, L]^3 with restitution elasticity | M3 | Architecture Spec § 4 Task 5 |
| 16 | Maxwell-Boltzmann speed analyzer | Empirical velocity histogram vs theoretical distribution f(v) | M3 | ORIGINAL_REQUEST § R3 |
| 17 | GPU MultiMesh kinetic color mapping | Maps particle speeds to vertex colors on single MultiMeshInstance3D | M3 | Architecture Spec § 4 Task 5 |
| 18 | NBodyGravityModule | Relativistic & Newtonian N-body gravitational module | M3 | ORIGINAL_REQUEST § R3 |
| 19 | Softened gravitational potential | Force with softening parameter epsilon_soft preventing r->0 singularity | M3 | Architecture Spec § 4 Task 6 |
| 20 | 1st Post-Newtonian (1PN) precession | Relativistic perihelion precession correction term | M3 | Architecture Spec § 4 Task 6 |
| 21 | Dynamic orbit path visualizer | Historical orbital trajectory rendering using cyclic line buffers | M3 | ORIGINAL_REQUEST § R3 |
| 22 | Relativistic speed cap & gamma | Relativistic momentum and gamma = 1/sqrt(1 - v^2/c^2) with c_sim | M3 | ORIGINAL_REQUEST § R3 |
| 23 | NuclearDecayModule | Radioactive decay channels, isotope database, induced fission | M3 | ORIGINAL_REQUEST § R3 |
| 24 | Poisson decay channels (alpha, beta, gamma) | Stochastic decay P = 1 - exp(-lambda * dt) with 4-momentum conservation | M3 | ORIGINAL_REQUEST § R3 |
| 25 | Built-in isotope database | Predefined isotopes: U-235, Ra-226, C-14, H-3, H-2, He-4, neutron | M3 | ORIGINAL_REQUEST § R3 |
| 26 | Induced fission chain reaction | Neutron collision with U-235 producing 2 fragments + prompt neutrons | M3 | ORIGINAL_REQUEST § R3 |
| 27 | QuantumWavePacketModule | Time-dependent Schrödinger equation solver on discrete grid | M3 | ORIGINAL_REQUEST § R3 |
| 28 | Unitary Cayley time evolution | Staggered evolution preserving unitary norm sum |psi|^2 dx = 1.0 | M3 | Architecture Spec § 4 Task 8 |
| 29 | Quantum tunneling & barrier potentials | Square barrier, harmonic well, double slit; computes transmission T | M3 | ORIGINAL_REQUEST § R3 |
| 30 | Quantum visualization (height & phase) | Probability density as mesh height, arg(psi) as color hue | M3 | Architecture Spec § 4 Task 8 |
| 31 | RelativisticParticleModule | Experimental module for speed of light & Lorentz boost benchmarks | M3 | Architecture Spec § 2 |
| 32 | ScientificProbeModule | Non-invasive 3D measurement probes and field spectrum analyzers | M3 | Architecture Spec § 2 |
| 33 | RelativisticMeshShader | Shader for real-time Lorentz contraction & Doppler beaming | M3 | Architecture Spec § 2 |
| 34 | ParticleFieldGlowShader | Energy/temperature gradient billboard/point glow shader | M3 | Architecture Spec § 2 |
| 35 | Automated Headless Test Suite | res://tests/test_physics_engine_suite.gd headless test runner | E2E | ORIGINAL_REQUEST § Acceptance |

---

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Central Simulation Time Engine & Integrators (R1) | SimulationTimeController, UnitConverter, PhysicalIntegrator, VerletIntegrator, RK4Integrator | none | DONE |
| M2 | Conservation Law Sentry & Spatial Partitioning (R2) | ConservationSentry, SpatialHashGrid, BarnesHutOctree | M1 | DONE |
| M3 | Modular Physics Simulation Domains (R3) | MolecularDynamicsModule, NBodyGravityModule, NuclearDecayModule, QuantumWavePacketModule, RelativisticParticleModule, ScientificProbeModule, Shaders | M1, M2 | DONE |
| E2E | E2E Headless Test Suite Track | TEST_INFRA.md, res://tests/test_physics_engine_suite.gd (Tiers 1-4), TEST_READY.md | none (parallel) | DONE |
| M4 | Final Integration, 100% E2E Test Pass & Adversarial Hardening | Phase 1: 100% E2E test pass; Phase 2: Tier 5 adversarial hardening; --check-only exit code 0 | M1, M2, M3, E2E | DONE |

---

## Interface Contracts

### M1: Simulation Time & Integrators
- `SimulationTimeController` (`res://core/physics/simulation_time_controller.gd`):
  - Signals: `sim_tick(dt: float, sim_time: float)`, `time_scale_changed(scale: float)`, `simulation_paused(is_paused: bool)`, `step_executed(sim_time: float)`
  - Methods: `set_time_scale(scale: float) -> void`, `toggle_pause() -> void`, `set_paused(paused: bool) -> void`, `step_once() -> void`, `reset() -> void`
- `PhysicalIntegrator` (`res://core/physics/physical_integrator.gd`):
  - Method: `integrate(positions: PackedVector3Array, velocities: PackedVector3Array, masses: PackedFloat32Array, force_callable: Callable, dt: float) -> void`

### M2: Conservation Sentry & Spatial Partitioning
- `ConservationSentry` (`res://core/physics/conservation_sentry.gd`):
  - Signals: `invariants_updated(snapshot: Dictionary)`, `conservation_warning(violation_type: String, relative_drift: float)`
  - Methods: `register_system(initial_energy: float) -> void`, `audit(positions: PackedVector3Array, velocities: PackedVector3Array, masses: PackedFloat32Array, potential_calculator: Callable) -> Dictionary`
  - Snapshot Dictionary: `kinetic_energy: float`, `potential_energy: float`, `total_energy: float`, `energy_drift_ratio: float`, `linear_momentum: Vector3`, `angular_momentum: Vector3`, `particle_count: int`, `temperature: float`, `is_conserved: bool`
- `SpatialHashGrid` (`res://core/physics/spatial_hash_grid.gd`):
  - Methods: `initialize(cell_size: float, expected_capacity: int = 10000) -> void`, `clear() -> void`, `insert(particle_idx: int, position: Vector3) -> void`, `get_neighbors(position: Vector3, search_radius: float) -> PackedInt32Array`

### M3: Physics Domain Modules
- All extend `UniCoreModule` (`res://core/base_module.gd`):
  - `initialize(context: Dictionary) -> bool`: extracts `event_bus`, `world_root`, connects to `sim_tick`.
  - `cleanup() -> void`: unregisters callbacks, frees MultiMesh and buffers.
  - `get_module_id() -> String`: unique identifier (`molecular_dynamics`, `n_body_gravity`, etc.).
  - `get_action_bindings() -> Array[Dictionary]`: keybindings.

---

## Code Layout
```
res://
├── core/
│   └── physics/
│       ├── simulation_time_controller.gd
│       ├── unit_converter.gd
│       ├── physical_integrator.gd
│       ├── verlet_integrator.gd
│       ├── rk4_integrator.gd
│       ├── conservation_sentry.gd
│       ├── spatial_hash_grid.gd
│       └── barnes_hut_octree.gd
├── modules/
│   └── physics/
│       ├── molecular_dynamics_module.gd
│       ├── n_body_gravity_module.gd
│       ├── relativistic_particle_module.gd
│       ├── nuclear_decay_module.gd
│       ├── quantum_wavepacket_module.gd
│       └── scientific_probe_module.gd
├── shaders/
│   ├── relativistic_mesh.gdshader
│   └── particle_field_glow.gdshader
└── tests/
    └── test_physics_engine_suite.gd
```
