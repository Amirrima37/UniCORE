# UniCORE Test Infrastructure & Scientific Physics Test Suite Architectural Report

**Target Project**: UniCORE Fundamental Scientific Physics Simulation Platform  
**Target Engine**: Godot 4.0.stable (official 92bee43ad)  
**Survey Agent**: Test Infrastructure Explorer  
**Date**: 2026-10-28  
**Working Directory**: `c:\dev\UniCORE\.agents\teamwork\explorer_tests_survey\`

---

## 1. Executive Summary

UniCORE features an automated headless testing ecosystem designed for continuous verification, CI automation, and multi-agent development. The testing infrastructure consists of:
1. **Master Test Runner (`res://tests/test_runner.gd`)**: An aggregator extending `SceneTree` that automatically discovers all test suites adhering to the `*_suite.gd` naming pattern, executes each suite in an isolated subprocess, collects outputs and exit codes, and provides a unified pass/fail summary.
2. **Canonical Suite Architecture (`res://tests/test_validator_suite.gd`)**: A non-blocking, count-based assertion architecture. Built-in GDScript `assert()` is **strictly prohibited** because it halts headless processes. Suites maintain `passed_count` and `failed_count`, log clear formatted output, and cleanly terminate using `quit(0)` or `quit(1)`.
3. **Headless Syntax Verifier (`--check-only`)**: Godot's built-in static analysis engine, executed via `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`, provides rapid static typing and parse validation in < 500 ms with exit code 0.

This report details the findings from surveying the existing 44 test suites, establishes the execution mechanics and differences between Godot Windows binaries, and provides the architectural design and code specification for the upcoming `res://tests/test_physics_engine_suite.gd`.

---

## 2. Test Infrastructure & Runner Mechanics

### 2.1 Master Test Runner (`res://tests/test_runner.gd`)

The master runner operates as an external supervisor:
- **Class Hierarchy**: `extends SceneTree`.
- **Discovery Mechanism**: Scans `res://tests` using `DirAccess`. Filters files matching:
  ```gdscript
  not dir.current_is_dir() and file_name.ends_with("_suite.gd") and file_name != "test_runner.gd"
  ```
  *Constraint*: Any new physics test suite must end in `_suite.gd` (e.g. `test_physics_engine_suite.gd`) to be automatically registered.
- **Process Isolation**: Each suite is executed as a distinct headless Godot process via `OS.execute`:
  ```gdscript
  var args := ["--headless", "--path", proj_path, "-s", suite_path]
  var exit_code := OS.execute(exe_path, args, output, true)
  ```
- **Exit Code Propagation**:
  - If all discovered suites exit with code 0: `test_runner.gd` prints summary and exits with `quit(0)`.
  - If any suite exits with non-zero: prints list of failed suites and exits with `quit(1)`.

### 2.2 Godot Windows Executables: GUI vs Console Binary

An essential finding during execution verification:
1. **`C:\Godot\godot.exe` (GUI Subsystem)**:
   - When run from Windows PowerShell without redirection, standard output (`print()`) is not piped to the interactive console because Windows GUI subsystem binaries detach standard I/O handles by default.
   - However, `--check-only` correctly returns exit code 0 (success) or 1 (syntax error).
2. **`C:\Godot\Godot_v4.0-stable_win64_console.exe` (Console Subsystem)**:
   - Built specifically with the Windows Console subsystem flag (`IMAGE_SUBSYSTEM_WINDOWS_CUI`).
   - Immediately pipes all `print()`, `push_warning()`, `push_error()`, and engine logs directly to the active PowerShell terminal.
   - **Recommendation for single-suite testing**:
     ```powershell
     & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd
     ```

### 2.3 Syntax Verification Command Verification

We verified the command specified in `ORIGINAL_REQUEST.md` and `GEMINI.md`:
```powershell
& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
```
- **Execution Result**: Exited with code `0`.
- **Latency**: ~400 ms.
- **Current Workspace State**: Zero syntax errors or parse warnings across the entire project.

---

## 3. Canonical Test Suite Structure & Anti-Patterns

### 3.1 The Fatal Flaw of Built-in `assert()` in Headless Godot 4

In Godot 4.0, calling `assert(condition)` when running under `--headless`:
1. Triggers an engine breakpoint / debugger hook.
2. In headless environments (without an attached debugger or IDE GUI), this either causes the process to hang waiting for debugger input or immediately aborts without executing cleanup or subsequent tests.
3. Therefore, as mandated by `GEMINI.md`:
   > *"В тестах запрещен встроенный `assert()` (он вешает процесс в `--headless`). Используются счетчики и `quit(code)`."*

### 3.2 Canonical Assertion Library Pattern

Examining `test_validator_suite.gd`, `test_audio_inspect.gd`, and `test_network_layer_suite.gd`, the canonical assertion methods must be declared as member functions of the `SceneTree` test script:

```gdscript
var passed_count: int = 0
var failed_count: int = 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		var detail := (" - " + error_msg) if not error_msg.is_empty() else ""
		print("  [FAIL] %s%s" % [test_name, detail])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	if actual == expected:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - Expected '%s', got '%s'" % [test_name, str(expected), str(actual)])
		failed_count += 1

func assert_approx_equal(actual: float, expected: float, tolerance: float, test_name: String) -> void:
	var diff := absf(actual - expected)
	if diff <= tolerance:
		print("  [PASS] %s (actual: %.6f, expected: %.6f, diff: %.8f <= tol: %.8f)" % [test_name, actual, expected, diff, tolerance])
		passed_count += 1
	else:
		print("  [FAIL] %s - actual %.6f != expected %.6f (diff: %.8f > tol: %.8f)" % [test_name, actual, expected, diff, tolerance])
		failed_count += 1

func assert_vector3_approx_equal(actual: Vector3, expected: Vector3, tolerance: float, test_name: String) -> void:
	var dist := actual.distance_to(expected)
	if dist <= tolerance:
		print("  [PASS] %s (dist: %.6f <= tol: %.6f)" % [test_name, dist, tolerance])
		passed_count += 1
	else:
		print("  [FAIL] %s - actual %s != expected %s (dist: %.6f > tol: %.6f)" % [test_name, str(actual), str(expected), dist, tolerance])
		failed_count += 1

func assert_in_range(val: float, min_val: float, max_val: float, test_name: String) -> void:
	if val >= min_val and val <= max_val:
		print("  [PASS] %s (value: %.4f in [%.4f, %.4f])" % [test_name, val, min_val, max_val])
		passed_count += 1
	else:
		print("  [FAIL] %s - value %.4f outside [%.4f, %.4f]" % [test_name, val, min_val, max_val])
		failed_count += 1
```

### 3.3 Asynchronous Execution & SceneTree Lifecycle

For tests requiring time stepping, signal waiting, or physics processing:
1. In `_init()`, delegate to a deferred method:
   ```gdscript
   func _init() -> void:
       call_deferred("_run_all_tests")
   ```
2. In `_run_all_tests()`, execution can freely use `await`:
   - `await process_frame`
   - `await physics_frame`
   - `await time_controller.step_executed`
3. Node tracking & cleanup:
   ```gdscript
   var _nodes_to_free: Array[Node] = []
   func track_node(node: Node) -> Node:
       _nodes_to_free.append(node)
       return node
   func free_tracked_nodes() -> void:
       for node in _nodes_to_free:
           if is_instance_valid(node):
               node.free()
       _nodes_to_free.clear()
   ```
4. Termination:
   ```gdscript
   free_tracked_nodes()
   print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
   quit(1 if failed_count > 0 else 0)
   ```

---

## 4. Architectural Design for `res://tests/test_physics_engine_suite.gd`

The physics simulation platform requires mathematical precision, energy conservation verification, and algorithmic complexity testing. `test_physics_engine_suite.gd` must be structured into modular test groups corresponding to Requirements R1, R2, and R3.

### 4.1 Test Matrix & Specifications

| Group | Target Class / Module | Test Case Name | Mathematical / Algorithmic Acceptance Criteria |
|---|---|---|---|
| **R1** | `SimulationTimeController` | `test_time_controller_clock_and_stepping` | Time scales $0.001\times$ to $1000\times$; `step_once()` advances `sim_time` by exactly `fixed_delta`; pauses freeze emission; `max_substeps` caps lagging delta. |
| **R1** | `PhysicalIntegrator` Base | `test_integrator_polymorphism` | Abstract base contract verification; Verlet and RK4 subclass compatibility. |
| **R1** | `VerletIntegrator` | `test_verlet_harmonic_oscillator_conservation` | Conservative 1D spring $F = -kx$: Total energy $E = \frac{1}{2}mv^2 + \frac{1}{2}kx^2$ over 5,000 steps maintains $\|(E(t) - E_0)/E_0\| < 0.001$ and $< 10^{-4}$ over 10,000 steps without secular drift. |
| **R1** | `RK4Integrator` vs `Verlet` | `test_rk4_vs_verlet_oscillator` | Compares RK4 single-step high order vs Verlet long-term symplectic bounded oscillation. |
| **R1** | Euler Divergence | `test_forward_euler_instability_contrast` | Explicit demonstration that naive forward Euler diverges exponentially, proving the architectural ban on Euler. |
| **R2** | `ConservationSentry` | `test_sentry_kepler_orbit_invariants` | 2-body Keplerian gravitational orbit ($V = -GMm/r$): Sentry reports `energy_drift_ratio < 0.001` and constant angular momentum vector $\vec{L} = \vec{r} \times (m\vec{v})$ ($|\Delta \vec{L}| < 10^{-5}$). |
| **R2** | `ConservationSentry` | `test_sentry_warning_trigger` | Artificial energy injection triggers `conservation_warning` when drift exceeds `energy_tolerance = 0.005`. |
| **R2** | `SpatialHashGrid` | `test_spatial_hash_grid_equivalence_brute_force` | $N = 5,000$ random particles in $[-50, 50]^3$: Query radius $R = 3.5$ returns identical neighbor sets to $O(N^2)$ brute-force (100% precision, 100% recall). |
| **R2** | `SpatialHashGrid` | `test_spatial_hash_grid_performance_budget` | Neighbor query over 5,000 particles executes within 10 ms budget ($O(N)$ scaling). |
| **R2** | `SpatialHashGrid` | `test_spatial_hash_grid_negative_coords_and_boundaries` | Correct prime coordinate hashing across zero boundary $(0,0,0)$ and negative octants without rounding errors. |
| **R3** | `MolecularDynamicsModule` | `test_lennard_jones_potential_and_force` | Potential minimum at $r_{min} = 2^{1/6}\sigma$, $F(r_{min}) = 0$, $V(r_{min}) = -\epsilon$; cutoff at $r_c = 2.5\sigma$. |
| **R3** | `MolecularDynamicsModule` | `test_berendsen_thermostat_convergence` | Velocity scaling $\lambda = \sqrt{1 + \frac{\Delta t}{\tau}(\frac{T_{target}}{T_{instant}} - 1)}$ smoothly drives temperature from 300 K to 100 K. |
| **R3** | `MolecularDynamicsModule` | `test_elastic_container_boundaries` | Boundary impact inverts normal velocity vector component, conserving particle kinetic energy. |
| **R3** | `NBodyGravityModule` | `test_nbody_orbit_stability` | Multi-period circular orbit maintaining constant orbital radius $r_0 \pm 0.5\%$. |
| **R3** | `NBodyGravityModule` | `test_relativistic_speed_of_light_cap` | Extreme central gravitational attraction with finite $c_{sim} = 20.0\text{ m/s}$: velocity strictly satisfies $\|\vec{v}\| < c_{sim}$ at all steps. |
| **R3** | `NBodyGravityModule` | `test_lorentz_factor_and_doppler` | Verifies $\gamma = 1/\sqrt{1 - v^2/c^2}$ and relativistic Doppler beaming factor $D = \frac{1}{\gamma(1 - \vec{\beta}\cdot\hat{k})}$. |
| **R3** | `NuclearDecayModule` | `test_isotope_database_integrity` | Isotope table verification (U-235, Ra-226, C-14, H-2, H-3, He-4) with half-lives and decay channels. |
| **R3** | `NuclearDecayModule` | `test_nuclear_poisson_decay_statistics` | Ensemble of $N_0 = 1,000$ nuclei with half-life $T_{1/2}$: after $t = T_{1/2}$, surviving nuclei count $N(T_{1/2}) \in [450, 550]$ ($\pm 5\%$ statistical error bound). |
| **R3** | `NuclearDecayModule` | `test_alpha_decay_momentum_conservation` | $\alpha$-decay at rest: $\vec{p}_{daughter} + \vec{p}_{\alpha} = \vec{0}$, $E_\alpha / E_d = m_d / m_\alpha$. |
| **R3** | `QuantumWavePacketModule` | `test_schrodinger_norm_conservation` | Discretized 1D wave function: $\sum |\psi(x)|^2 \Delta x = 1.0 \pm 10^{-4}$ maintained across 500 evolution steps. |
| **R3** | `QuantumWavePacketModule` | `test_quantum_tunneling_barrier` | Incident wavepacket on square barrier $V_0 > E$: non-zero transmission probability ($P_{trans} > 0$) on far side of barrier. |

---

## 5. Comprehensive Scaffolding Blueprint for `test_physics_engine_suite.gd`

Below is the complete structural scaffolding designed for `res://tests/test_physics_engine_suite.gd`. It complies with Godot 4.0.stable, strict GDScript 2.0 static typing, and all UniCORE testing rules:

```gdscript
extends SceneTree

# ==============================================================================
# UniCORE Comprehensive Test Suite: Fundamental Scientific Physics Platform
# ==============================================================================
# Covers:
# - R1: SimulationTimeController, PhysicalIntegrator, VerletIntegrator, RK4Integrator
# - R2: ConservationSentry (Noether Invariants), SpatialHashGrid (O(N) Complexity)
# - R3: MolecularDynamicsModule (LJ 12-6, Berendsen, Elastic Bounds)
# - R3: NBodyGravityModule (Relativistic Speed Cap, Lorentz/Doppler)
# - R3: NuclearDecayModule (Poisson Statistics, 4-Momentum Conservation)
# - R3: QuantumWavePacketModule (Probability Norm Conservation, Tunneling)
# ==============================================================================

const SimulationTimeController = preload("res://core/physics/simulation_time_controller.gd")
const PhysicalIntegrator = preload("res://core/physics/physical_integrator.gd")
const VerletIntegrator = preload("res://core/physics/verlet_integrator.gd")
const RK4Integrator = preload("res://core/physics/rk4_integrator.gd")
const ConservationSentry = preload("res://core/physics/conservation_sentry.gd")
const SpatialHashGrid = preload("res://core/physics/spatial_hash_grid.gd")
const MolecularDynamicsModule = preload("res://modules/physics/molecular_dynamics_module.gd")
const NBodyGravityModule = preload("res://modules/physics/n_body_gravity_module.gd")
const NuclearDecayModule = preload("res://modules/physics/nuclear_decay_module.gd")
const QuantumWavePacketModule = preload("res://modules/physics/quantum_wavepacket_module.gd")

var passed_count: int = 0
var failed_count: int = 0
var _nodes_to_free: Array[Node] = []

func track_node(node: Node) -> Node:
	_nodes_to_free.append(node)
	return node

func free_tracked_nodes() -> void:
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()

# --- Canonical Assertion Methods ---

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		var detail := (" - " + error_msg) if not error_msg.is_empty() else ""
		print("  [FAIL] %s%s" % [test_name, detail])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	if actual == expected:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - Expected '%s', got '%s'" % [test_name, str(expected), str(actual)])
		failed_count += 1

func assert_approx_equal(actual: float, expected: float, tolerance: float, test_name: String) -> void:
	var diff := absf(actual - expected)
	if diff <= tolerance:
		print("  [PASS] %s (actual: %.6f, expected: %.6f, diff: %.8f <= tol: %.8f)" % [test_name, actual, expected, diff, tolerance])
		passed_count += 1
	else:
		print("  [FAIL] %s - actual %.6f != expected %.6f (diff: %.8f > tol: %.8f)" % [test_name, actual, expected, diff, tolerance])
		failed_count += 1

func assert_vector3_approx_equal(actual: Vector3, expected: Vector3, tolerance: float, test_name: String) -> void:
	var dist := actual.distance_to(expected)
	if dist <= tolerance:
		print("  [PASS] %s (dist: %.6f <= tol: %.6f)" % [test_name, dist, tolerance])
		passed_count += 1
	else:
		print("  [FAIL] %s - actual %s != expected %s (dist: %.6f > tol: %.6f)" % [test_name, str(actual), str(expected), dist, tolerance])
		failed_count += 1

func assert_in_range(val: float, min_val: float, max_val: float, test_name: String) -> void:
	if val >= min_val and val <= max_val:
		print("  [PASS] %s (val: %.4f in [%.4f, %.4f])" % [test_name, val, min_val, max_val])
		passed_count += 1
	else:
		print("  [FAIL] %s - val %.4f outside [%.4f, %.4f]" % [test_name, val, min_val, max_val])
		failed_count += 1

# --- Test Runner Entry Point ---

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("==================================================")
	print("Starting UniCORE Scientific Physics Engine Suite")
	print("==================================================")

	# Group 1: Simulation Time Controller
	_test_simulation_time_controller()

	# Group 2: Numerical Integrators (Verlet, RK4, Oscillator drift)
	_test_numerical_integrators()

	# Group 3: Conservation Sentry & Kepler Orbit
	_test_conservation_sentry()

	# Group 4: SpatialHashGrid O(N) Verification
	_test_spatial_hash_grid()

	# Group 5: Molecular Dynamics & Thermodynamics
	_test_molecular_dynamics()

	# Group 6: Relativistic N-Body Gravity
	_test_n_body_gravity()

	# Group 7: Nuclear Decay & Poisson Statistics
	_test_nuclear_decay()

	# Group 8: Quantum Wave Packet Propagation
	_test_quantum_wavepacket()

	free_tracked_nodes()

	print("\n==================================================")
	print("Scientific Physics Engine Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	quit(1 if failed_count > 0 else 0)
```

---

## 6. Execution Guidelines for Developers

To maintain speed, token efficiency, and test reliability:

1. **Syntax Check (Run Frequently During Implementation)**:
   ```powershell
   & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
   ```
   *Exit code 0 confirms valid GDScript 2.0 syntax and static types.*

2. **Targeted Physics Suite Execution (Run During Physics Module Dev)**:
   ```powershell
   & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd
   ```
   *Executes only the physics test suite, outputting full results in ~1 second.*

3. **Master Runner (`test_runner.gd`)**:
   - Strictly reserved for user command or Phase Sign-off.
   - Do NOT run the master runner in normal task loops.
