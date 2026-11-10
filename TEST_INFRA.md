# UniCORE Scientific Physics Engine: Test Infrastructure & Verification Architecture

## 1. Test Philosophy & Principles

The UniCORE Scientific Physics Platform operates under a **deterministic, invariant-preserving, requirement-driven, opaque-box testing philosophy**. The goal is not merely to check whether code runs without throwing errors, but to rigorously verify mathematical and physical truth against exact analytical oracles and computational benchmarks.

### Core Principles
1. **Opaque-Box Physical Requirement Verification**: Tests treat classes as black boxes adhering to immutable mathematical contracts (Newton's laws, Noether's theorem, symplectic phase-space volume conservation, Hamiltonian invariant preservation).
2. **Explicit Authoritative Oracles**: Expected outputs are derived analytically from classical mechanics equations:
   - Harmonic oscillator analytic solutions ($E = \frac{1}{2} m v^2 + \frac{1}{2} k x^2$)
   - 2-Body Keplerian orbital mechanics ($E = -\frac{G m_1 m_2}{2a}$, $L = \vec{r} \times \vec{p}$)
   - Dimensionless unit scaling laws ($[L], [M], [T]$ dimensional analysis)
   - Spatial partition geometry ($O(N)$ lattice hashing vs $O(N^2)$ brute-force ground truth)
   - Multipole expansion potentials ($U = -\frac{1}{2}\sum \frac{G m_i m_j}{r_{ij}}$)
3. **Strict Headless Godot 4.0 Compliance**:
   - Built-in `assert()` is **strictly forbidden** in headless runs as it freezes/aborts process execution without error reports. Custom assertion wrappers track counters and emit standard diagnostics.
   - String formatting avoids `%e` (which is prone to Godot 4 formatting bugs); `%f`, `%.6f`, or `str()` are used exclusively.
   - Dynamic reflection adheres to `Callable` and instance invocation rules without forbidden static `ClassName.has_method()` calls.
4. **Self-Contained & Deterministic**: Each test seeds any PRNG (`RandomNumberGenerator.seed`), allocates its own state, executes deterministically, and cleans up after itself.

---

## 2. Test Architecture & Runner Infrastructure

### 2.1 Headless Execution Harness
The test runner is implemented as a standalone Godot `SceneTree` script:
- Target File: `res://tests/test_physics_engine_suite.gd`
- Execution Command:
  ```powershell
  & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd
  ```
- Exit Code Protocol: Returns `quit(0)` if and only if 100% of test assertions pass; returns `quit(1)` on any failure.
- Aggregator Discovery: Because the file ends with `_suite.gd`, it is automatically discovered and executed by `res://tests/test_runner.gd`.

### 2.2 Diagnostic & Metric Capture
The harness captures:
- Assertion counts (passed, failed, total).
- Execution timing via `Time.get_ticks_usec()` for algorithmic complexity benchmarks.
- Energy drift ratios, momentum drift norms, and relative numerical errors.
- Failure message trails with expected vs actual values.

---

## 3. Feature Inventory & Coverage Mapping

| Component | Target File | Core Responsibilities | Test Target Count |
|---|---|---|---|
| **SimulationTimeController** | `res://core/physics/simulation_time_controller.gd` | Central clock, variable time scale (0.001x-1000x), pause/resume, fixed_delta accumulator, step_once execution, lag death-spiral capping | >= 5 tests |
| **UnitConverter** | `res://core/physics/unit_converter.gd` | SI <-> reduced units (Lennard-Jones, Planck, Astronomical), dimensional conversion for vectors and scalars, parameter customizer | >= 5 tests |
| **PhysicalIntegrator** | `res://core/physics/physical_integrator.gd` | Base contract, dimensional validation, zero-allocation buffer interface, 1-arg & 2-arg Callable arity auto-probing | >= 5 tests |
| **VerletIntegrator** | `res://core/physics/verlet_integrator.gd` | Symplectic Velocity-Verlet, preallocated acceleration buffer, energy preservation in conservative fields | >= 5 tests |
| **RK4Integrator** | `res://core/physics/rk4_integrator.gd` | Classical 4th-order Runge-Kutta, O(dt^4) local convergence, velocity-dependent damping forces, scratch buffer reuse | >= 5 tests |
| **ConservationSentry** | `res://core/physics/conservation_sentry.gd` | Noether invariant auditor (E, P, L), kinetic temperature equipartition, relative drift tracking, warning signals | >= 5 tests |
| **SpatialHashGrid** | `res://core/physics/spatial_hash_grid.gd` | 3D lattice spatial hashing, prime hash coordinates, floor quantization on negative coordinates, O(N) neighbor searches | >= 5 tests |
| **BarnesHutOctree** | `res://core/physics/barnes_hut_octree.gd` | Hierarchical 3D octree, Multipole Acceptance Criterion (theta), iterative stack traversal, coincident particles handling, node pool recycling | >= 5 tests |

---

## 4. Multi-Tiered Verification Methodology

The test suite is structured into 4 hierarchical validation tiers:

### Tier 1: Feature Coverage (Unit & Contract Verification)
Verifies that every method, property, signal, and mathematical conversion in each of the 8 core components behaves according to specification under nominal conditions. Minimum 5 distinct test cases per component (>= 40 tests).

### Tier 2: Boundary & Corner Cases (Adversarial Robustness)
Subjects each component to extreme numerical edge cases:
- Degenerate/empty arrays (empty positions, velocities, masses).
- Dimension parity mismatches.
- Zero mass ($m = 0$) and near-zero mass ($m < 10^{-12}$) clamping.
- Negative coordinates, large coordinates ($> 10^8$), and coincident particles ($r_i = r_j$).
- Extreme time scales ($dt = 10^{-6}$, $dt = 1000$, $\text{scale} = 0.001$, $\text{scale} = 1000$).
- Division-by-zero safeguards when baseline invariants ($E_0 = 0$, $P_0 = 0$, $L_0 = 0$) are zero.
- Runaway search radii clamping in spatial grids.

### Tier 3: Cross-Feature Combinations (Subsystem Integration)
Verifies multi-component workflows:
- `SimulationTimeController` driving fixed ticks into `VerletIntegrator`.
- `ConservationSentry` auditing multi-particle systems integrated by `VerletIntegrator` and `RK4Integrator`.
- `SpatialHashGrid` driving short-range pair forces while `BarnesHutOctree` computes long-range gravitational fields.
- `UnitConverter` transforming physical states before integration and after telemetry auditing.

### Tier 4: Real-World Application Scenarios (Empirical Rigor)
Simulates actual physical problems with strict acceptance thresholds:
1. **Harmonic Spring Oscillator (10,000 steps)**: Symplectic Velocity-Verlet must maintain energy drift $\left|\frac{E(t) - E_0}{E_0}\right| < 10^{-4}$ with zero secular divergence.
2. **Closed 2-Body Keplerian Orbit (5,000 steps)**: Symplectic integration under Newtonian gravity must keep orbital energy drift $< 0.001$ (0.1%) and total angular momentum strictly constant.
3. **5,000-Particle SpatialHashGrid Neighbor Benchmark**: Neighbor search across 5,000 randomly scattered particles must complete in $< 10\text{ ms}$ and match brute-force ground truth 100%.
4. **Barnes-Hut Multipole Gravitational Cluster**: Octree with $\theta = 0.0$ must match direct $O(N^2)$ acceleration within numerical tolerance ($< 10^{-5}$ relative error), and $\theta = 0.5$ must provide $> 98\%$ accuracy while accelerating force computation.
5. **Node Recycling & Zero Leakage**: Octree and Integrators must reuse buffers across repeated simulation frames without memory growth.

---

## 5. Verification Commands

| Action | Command Line |
|---|---|
| **E2E Test Runner** | `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd` |
| **Static Script Verification** | `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only` |
| **All Test Suites Aggregator** | `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_runner.gd` |
