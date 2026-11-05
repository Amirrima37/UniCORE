# Challenge Report: Milestone 3 Modular Physics Simulation Domains

## Challenge Summary
- **Target Deliverables**:
  1. `res://modules/physics/molecular_dynamics_module.gd`
  2. `res://shaders/particle_field_glow.gdshader`
  3. `res://modules/physics/n_body_gravity_module.gd`
  4. `res://shaders/relativistic_mesh.gdshader`
  5. `res://core/physics/spatial_hash_grid.gd` (critical dependency)
- **Overall Risk Assessment**: **CRITICAL**
- **Verdict**: **REQUEST_CHANGES** (Godot Headless exit code: 1, 5 test asserts failed, runtime GDScript errors observed)

---

## Empirical Verification Summary

- **Total Asserts**: 49
- **Passed**: 44
- **Failed**: 5
- **GDScript Out-of-Bounds & Engine Errors**:
  - `SCRIPT ERROR: Out of bounds get index '0' (on base: 'PackedVector3Array') at: MolecularDynamicsModule.compute_potential_energy (res://modules/physics/molecular_dynamics_module.gd:535)`
  - `ERROR: VerletIntegrator: force_callable returned invalid array size at Step 1`
  - `ERROR: VerletIntegrator: force_callable returned invalid array size at Step 3`

---

## Detailed Vulnerability & Defect Findings

### [CRITICAL] Finding 1: In-Place Mutation and Destruction of Particle Coordinates in `SpatialHashGrid.build_grid()`

- **Assumption Challenged**:
  `SpatialHashGrid.build_grid(positions)` safely stores and indexes particle coordinates across successive simulation time steps without corrupting the caller's array.
- **Root Cause Analysis**:
  In `res://core/physics/spatial_hash_grid.gd`:
  ```gdscript
  func clear() -> void:
      _grid.clear()
      _positions.clear() # In-place mutation of the referenced buffer!
      _particle_count = 0

  func build_grid(positions: PackedVector3Array) -> void:
      clear()
      var n: int = positions.size()
      if n == 0:
          return
      _positions = positions
  ```
  In Godot 4.0 GDScript, `PackedVector3Array` assignments are copy-on-write references.
  On the first call, `_positions = positions` points `_positions` to the caller's array.
  On the second call (e.g., Step 3 of `VerletIntegrator.integrate`, or the next time step in `MolecularDynamicsModule.step`), `clear()` invokes `_positions.clear()`.
  Because `_positions` shares the buffer with the caller's `positions` (which is `MolecularDynamicsModule._positions`), calling `_positions.clear()` **empties the caller's array to size 0 in-place**!
  Immediately after, `var n: int = positions.size()` evaluates to 0, returning an empty grid and leaving `MolecularDynamicsModule._positions` completely wiped out.
- **Empirical Proof**:
  - Isolated diagnostic test:
    ```
    Original arr size: 2
    After build_grid 1, arr size: 2
    After build_grid 2, arr size: 0
    ```
  - `MolecularDynamicsModule.step(dt)` fails at Step 3 of Velocity-Verlet on the very first time step:
    `ERROR: VerletIntegrator: force_callable returned invalid array size at Step 3`
  - Peak NVE relative energy drift reaches **295.02%** (`drift = 2.950185`, threshold `< 0.005`).
  - Berendsen thermostat cannot equilibrate because particle buffers are empty (instantaneous temperature stuck at 2.9000).
- **Blast Radius**:
  Completely breaks continuous physical simulation in `MolecularDynamicsModule`. Prevents any multi-step MD trajectory from evolving.
- **Mitigation**:
  In `SpatialHashGrid.clear()`, do NOT call `_positions.clear()`. Instead, reassign `_positions = PackedVector3Array()`, or store `positions.duplicate()` in `build_grid()`.

---

### [HIGH] Finding 2: 1PN Post-Newtonian Cross-Velocity Sign Error and Double Relativistic Damping in `NBodyGravityModule`

- **Assumption Challenged**:
  `NBodyGravityModule`'s 1PN relativistic correction term produces the analytical Einstein perihelion advance ($\Delta\phi = \frac{6\pi GM}{a(1-e^2)c^2}$) in the orbital direction.
- **Root Cause Analysis**:
  Two interacting defects exist in `res://modules/physics/n_body_gravity_module.gd`:
  1. **Cross-Term Sign Inversion in `_compute_1pn_pair` (lines 404-417)**:
     ```gdscript
     var r_vec: Vector3 = pos_j - pos_i # Inward vector pointing towards central mass
     var v_rel: Vector3 = vel_i - vel_j # Planet velocity relative to central mass
     var radial_coeff: float = (4.0 * g_m / dist) - v_rel_sq
     var cross_coeff: float = 4.0 * r_vec.dot(v_rel)
     return (r_vec * radial_coeff + v_rel * cross_coeff) * prefactor
     ```
     The standard Einstein-Infeld-Hoffmann (EIH) 1PN acceleration for an outward position vector $\vec{r} = \vec{r}_i - \vec{r}_j$ is:
     $$\Delta \vec{a}_{1PN} = \frac{GM}{c^2 r^3} \left[ -\left(\frac{4GM}{r} - v^2\right)\vec{r} + 4(\vec{r}\cdot\vec{v})\vec{v} \right]$$
     Because `r_vec` was defined as `pos_j - pos_i = -\vec{r}$ (inward), substituting $\vec{r} = -\vec{r}_{vec}$ yields:
     $$\Delta \vec{a}_{1PN} = \frac{GM}{c^2 r^3} \left[ \left(\frac{4GM}{r} - v^2\right)\vec{r}_{vec} - 4(\vec{r}_{vec}\cdot\vec{v})\vec{v} \right]$$
     Notice that the cross-velocity coefficient in front of $\vec{v}$ must be **$-4(\vec{r}_{vec}\cdot\vec{v})$**, whereas the code implemented **$+4(\vec{r}_{vec}\cdot\vec{v})$**.
  2. **Double-Application of Relativistic Inertia Tensor in `_evaluate_forces_barnes_hut` (lines 378-386)**:
     ```gdscript
     a_eff += a_1pn
     if enable_relativity:
         var a_dot_v: float = a_eff.dot(vel_i)
         var a_rel: Vector3 = (a_eff - (vel_i * (a_dot_v / c_sim_sq))) / gamma
         a_eff = a_rel
     ```
     The 1PN EIH acceleration is already the full coordinate acceleration in the laboratory frame, derived directly from the geodesic equation including all $O(c^{-2})$ kinematic terms. Passing $\vec{a}_{eff} = \vec{a}_N + \vec{a}_{1PN}$ through the Special Relativistic acceleration tensor divides $\vec{a}$ by $\gamma$, damping the gravitational force at high speeds and flipping the advance into a **retrograde precession**.
- **Empirical Proof**:
  - Analytical 1PN Precession: $+1.00531$ rad ($+57.60^\circ$ per orbit).
  - Simulated 1PN Advance in `NBodyGravityModule`: **$-0.83611$ rad ($-47.91^\circ$ per orbit)** (retrograde).
  - When mapped to $[0, 2\pi)$: $5.44723$ rad ($312.10^\circ$).
  - Relative error vs analytical formula: **441.85%** (`err = 4.4185`, threshold `< 0.25`).
  - Isolated math verification test with corrected cross-term sign (`-4.0 * r_in.dot(v)`) and without SR double-damping confirms positive forward precession in the orbital direction.
- **Blast Radius**:
  Relativistic planetary simulation exhibits retrograde orbital decay and opposite perihelion precession direction instead of General Relativistic advance.
- **Mitigation**:
  1. In `_compute_1pn_pair`, change `var cross_coeff: float = -4.0 * r_vec.dot(v_rel)`.
  2. Do not pass the 1PN acceleration through the Special Relativistic $\frac{1}{\gamma}$ acceleration tensor, or apply the SR tensor only when 1PN is disabled (pure SR regime).

---

## Stress Test Results Table

| # | Test Scenario | Expected Outcome | Actual Outcome | Status |
|---|---------------|------------------|----------------|--------|
| 1 | SpatialHashGrid empty positions | Returns empty forces array | `forces.is_empty() == true` | **PASS** |
| 2 | SpatialHashGrid single particle | Zero force | `forces[0] == Vector3.ZERO` | **PASS** |
| 3 | SpatialHashGrid beyond cutoff ($r=3.0 > r_c=2.5$) | Zero force and zero potential | $F = 0$, $V = 0$ | **PASS** |
| 4 | SpatialHashGrid sub-equilibrium pair ($r=1.0$) | Repulsive force, Newton's 3rd Law | $F_0 = -F_1$, repulsive | **PASS** |
| 5 | SpatialHashGrid half-shell vs Brute Force ($N=100$) | Max vector diff $< 10^{-4}$ | $\Delta F_{max} = 0.000000$ | **PASS** |
| 6 | MD Newton's 3rd Law net force balance | $\sum F_i / \max|F| < 10^{-4}$ | $\text{rel\_net\_force} = 0.000000$ | **PASS** |
| 7 | MD NVE Energy Conservation (1000 steps, $dt=0.002$) | Drift $< 0.005$ | Drift = **2.950185** (295.0%) | **FAIL** |
| 8 | MD Berendsen Thermostat Cooling ($T: 3.0 \to 1.0$) | $T_{final} \approx 1.0 \pm 0.08$ | $T_{final} = \mathbf{2.9000}$ | **FAIL** |
| 9 | MD Berendsen Thermostat Heating ($T: 1.0 \to 2.5$) | $T_{final} \approx 2.5 \pm 0.12$ | $T_{final} = \mathbf{2.9000}$ | **FAIL** |
| 10 | MD Interactive Thermostat (`heat_up`, `cool_down`) | Changes $T_{target}$ by delta | Target updated exactly | **PASS** |
| 11 | MD Maxwell-Boltzmann distribution mean speed | Within 5% of theoretical $\langle v \rangle$ | Error = **0.62%** ($1.9665$ vs $1.9544$) | **PASS** |
| 12 | MD Maxwell-Boltzmann distribution RMS speed | Within 5% of theoretical $v_{rms}$ | Error = **0.00%** ($2.1213$ vs $2.1213$) | **PASS** |
| 13 | MD Empirical PDF normalization | Integral $\approx 1.0 \pm 0.05$ | Integral = **1.0000** | **PASS** |
| 14 | MD Empirical PDF L1 total variation | $L_1 < 0.25$ | $L_1 = \mathbf{0.1110}$ | **PASS** |
| 15 | MD Elastic boundary reflection | Inverted inward, clamped inside box | $x \le 4.8$, $v_x = -2.0$ | **PASS** |
| 16 | MD Container compression | Box half-extent scaled by factor | Scaled correctly | **PASS** |
| 17 | N-Body Singularity Plunge ($M=10000$) | Zero NaN/Inf, $v < c_{sim}$ | Max speed = **49.9750** ($< 50.0$) | **PASS** |
| 18 | N-Body Relativistic Asymptote Guard | $v \le 0.9995 \cdot c_{sim}$ | $\beta = 0.9995$ respected | **PASS** |
| 19 | N-Body Newtonian Singular Plunge Baseline | Breaches $c_{sim}$ without relativity | Max speed = **906.1710** | **PASS** |
| 20 | N-Body Newtonian Perihelion Precession (1PN OFF) | Closed orbit, drift $< 0.08$ rad | Closed orbit ($0.00$ deg drift) | **PASS** |
| 21 | N-Body 1PN Precession Advance Match | Matches analytical within 25% | Error = **441.85%** (Retrograde) | **FAIL** |
| 22 | N-Body Barnes-Hut ($\theta=0.5$) vs Direct All-Pairs | Avg relative error $< 3\%$ | Avg relative error = **0.59%** | **PASS** |
| 23 | N-Body Barnes-Hut ($\theta=0.0$) Direct Summation | Exact match ($< 10^{-4}$) | Absolute error = **0.000000** | **PASS** |
| 24 | N-Body Kepler 2-body orbit energy drift (500 steps) | Drift $< 0.001$ | Drift = **0.000001** | **PASS** |
| 25 | N-Body Figure-8 3-body choreography preset | Loads 3 bodies | 3 bodies loaded | **PASS** |
| 26 | N-Body Circular Orbit Trail Buffers | Trail history bounded by `trail_length` | All 3 bodies bounded $\le 50$ | **PASS** |
| 27 | N-Body ImmediateMesh Trail Rendering Lifecycle | Draws lines without crash | Rendered cleanly | **PASS** |
| 28 | N-Body MultiMesh & Buffer Teardown | `clear_particles` clears all | State completely reset | **PASS** |
| 29 | Shader AST: `particle_field_glow.gdshader` | Compiles & uniforms accessible | Uniforms verified | **PASS** |
| 30 | Shader AST: `relativistic_mesh.gdshader` | Compiles & uniforms accessible | Uniforms verified | **PASS** |

---

## Unchallenged Areas

- **QuantumWavePacketModule & NuclearDecayModule**: Outside Milestone 3-1 scope (part of separate worker milestone tracks).
- **GPU Visual Frame Rasterization**: Shaders were verified structurally and compiled headless; visual frame buffer pixels require display window.
