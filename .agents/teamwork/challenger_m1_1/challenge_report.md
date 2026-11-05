# Adversarial Challenge Report: Milestone 1 (M1-1)

**Challenger**: `challenger_m1_1` (Empirical Challenger)  
**Parent / Orchestrator**: `e9e803a1-ad51-4bb6-bbd9-5c64a9f0d796`  
**Date**: 2026-10-28  
**Scope**: Central Simulation Time Engine & Numerical Integrators  
**Verdict**: **FAIL**  
**Overall Risk Assessment**: **CRITICAL**

---

## 1. Executive Summary

Empirical verification of Milestone 1 under official Godot 4.0.stable (`C:\Godot\Godot_v4.0-stable_win64_console.exe`) revealed that while `SimulationTimeController` and `UnitConverter` are functionally sound and performant, **the core numerical integrators (`PhysicalIntegrator`, `VerletIntegrator`, and `RK4Integrator`) FAIL TO COMPILE**.

The worker relied on a non-existent method `Callable.get_argument_count()` on line 66 of `res://core/physics/physical_integrator.gd`, which is not part of the Godot 4.0.stable API (introduced in later Godot versions). Because the base class fails to parse, both `VerletIntegrator` and `RK4Integrator` cannot be instantiated or loaded. As a result, the primary acceptance criterion—running 5,000 steps of harmonic oscillation under `VerletIntegrator`—cannot execute in the current codebase.

Mathematical evaluation of the underlying Velocity-Verlet equations in an isolated test proved that the numerical formulation is symplectically sound ($|(E(5000) - E_0)/E_0| \approx 5.46 \times 10^{-6} \ll 0.001$), but the worker's implementation is blocked by this fatal API incompatibility.

---

## 2. Adversarial Challenges & Findings

### [CRITICAL] Challenge 1: Non-Existent API `Callable.get_argument_count()` in Godot 4.0.stable
- **Target**: `res://core/physics/physical_integrator.gd:66`
- **Assumption Challenged**: Worker assumed `force_callable.get_argument_count()` can be called in Godot 4.0.stable to inspect lambda parameter counts.
- **Attack Scenario & Observation**:
  Executing syntax inspection on the file:
  ```powershell
  & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE --check-only -s res://core/physics/physical_integrator.gd
  ```
  Result:
  ```
  SCRIPT ERROR: Parse Error: Cannot find property "get_argument_count" on base "Callable".
            at: GDScript::reload (res://core/physics/physical_integrator.gd:66)
  SCRIPT ERROR: Parse Error: Function "get_argument_count()" not found in base Callable.
            at: GDScript::reload (res://core/physics/physical_integrator.gd:66)
  ```
- **Blast Radius**:
  1. `PhysicalIntegrator` is unparseable and uninstantiable.
  2. `VerletIntegrator` fails with `SCRIPT ERROR: Parse Error: Could not resolve class "PhysicalIntegrator"`.
  3. `RK4Integrator` fails with `SCRIPT ERROR: Parse Error: Could not resolve class "PhysicalIntegrator"`.
  4. The entire physics integration layer is inoperable across all dependent milestones (M2 sentries, M3 molecular dynamics, N-body gravity).
- **Remediation**:
  In `res://core/physics/physical_integrator.gd`, replace the `get_argument_count()` dispatch with a compatible call strategy. In Godot 4.0.stable:
  - For standard force callables: `var result: Variant = force_callable.call(pos)`
  - If velocity is optionally needed (e.g. for RK4 dissipative forces): define the contract such that callables accept `(pos, vel)` with an optional default parameter `func(p: PackedVector3Array, _v: PackedVector3Array = PackedVector3Array()) -> PackedVector3Array`, or provide explicit 1-arg and 2-arg integrator evaluation paths without calling `.get_argument_count()`.

---

### [HIGH] Challenge 2: False-Negative Verification Protocol in Worker Handoff
- **Target**: `c:\dev\UniCORE\.agents\teamwork\worker_m1_1\handoff.md`
- **Assumption Challenged**: Worker claimed `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only` with code 0 proved that all 5 files were verified and bug-free.
- **Attack Scenario & Observation**:
  Godot's `--check-only` CLI without `-s <script_path>` only checks the main entry scene (`res://core/app_shell.tscn`), completely ignoring standalone class files in `res://core/physics/`. The worker never ran any unit tests or scripts referencing `PhysicalIntegrator`, `VerletIntegrator`, or `RK4Integrator`.
- **Blast Radius**: Defective code was reported as production-ready and passed to QA and subsequent milestones without empirical execution.
- **Remediation**:
  The orchestrator and Sentinel must mandate execution of concrete test scripts via `-s <script>` rather than bare `--check-only`.

---

### [MEDIUM] Challenge 3: Global Script Class Cache Desynchronization in Headless Mode
- **Target**: `.godot/global_script_class_cache.cfg`
- **Assumption Challenged**: New classes declared with `class_name` become globally resolvable immediately.
- **Attack Scenario & Observation**:
  In Godot 4.0 headless mode, newly created `class_name` declarations are not automatically added to `.godot/global_script_class_cache.cfg` unless explicitly refreshed or loaded. Scripts referencing bare class names before cache synchronization fail with `Parse Error: Identifier "..." not declared in current scope`.
- **Remediation**:
  Ensure test suites and class references either register in the cache or test runners use explicit `preload()` / `load()` calls for robustness.

---

## 3. Empirical Stress Test Results

Test execution harness: `res://tests/empirical_challenge_m1.gd`  
Engine binary: `C:\Godot\Godot_v4.0-stable_win64_console.exe`

| # | Test Scenario | Expected Behavior | Actual Behavior | Result |
|---|---------------|-------------------|-----------------|:------:|
| 1 | SimulationTimeController: `step_once()` | Advances `sim_time` by exactly `fixed_delta` (0.01s), emits 1 tick | `sim_time` = 0.01s, 1 `sim_tick`, 1 `step_executed` | **PASS** |
| 2 | SimulationTimeController: Pause | No ticks emitted, `sim_time` frozen during `_physics_process` | 0 ticks emitted, time frozen | **PASS** |
| 3 | SimulationTimeController: Unpause | Resumes tick emissions on next process frame | 2 ticks emitted for 0.02s delta | **PASS** |
| 4 | SimulationTimeController: Time Scale Clamping | Clamped to [0.001, 1000.0] | Clamped to 0.001 and 1000.0 | **PASS** |
| 5 | SimulationTimeController: Lag Spike Substepping Cap | Under 1.0s lag (100x `fixed_delta`), ticks capped at `max_substeps` (10) | Executed exactly 10 ticks, `sim_time` = 0.10s | **PASS** |
| 6 | SimulationTimeController: Anti-Death-Spiral Backlog Drop | Excess 90-step backlog discarded; next 0.01s frame runs 1 tick | Executed exactly 1 tick in next frame; no cascading stall | **PASS** |
| 7 | UnitConverter: SI to LJ Scalar Length | 3.40e-10 m converts to 1.0 reduced length | Got 1.0 | **PASS** |
| 8 | UnitConverter: LJ Round-Trip Conservation | Ratio between round-trip value and original = 1.0 | Preserved within float precision | **PASS** |
| 9 | UnitConverter: Vector3 Force Translation | Round-trip difference < 1e-15 | Diff: 0.0 | **PASS** |
| 10 | Worker File: `physical_integrator.gd` Load | Compiles and instantiates without errors | **Parse Error: Function "get_argument_count()" not found in base Callable** | **FAIL** |
| 11 | Worker File: `verlet_integrator.gd` Load | Compiles and instantiates without errors | **Parse Error: Could not resolve class "PhysicalIntegrator"** | **FAIL** |
| 12 | Worker File: `rk4_integrator.gd` Load | Compiles and instantiates without errors | **Parse Error: Could not resolve class "PhysicalIntegrator"** | **FAIL** |
| 13 | Velocity-Verlet Algorithm Mathematical Audit | 5,000 steps SHO (m=1, k=1, dt=0.01): relative energy drift < 0.001 | Final drift = 0.00000546 (0.000546%), Peak drift = 0.00002902 (0.002902%) | **PASS (Math)** |

---

## 4. Unchallenged Areas
- Full N-body relativistic dynamics (assigned to M3).
- Barnes-Hut octree long-range scaling (assigned to M2).
- SpatialHashGrid neighbor queries (assigned to M2).

---

## 5. Verdict and Recommendation

**VERDICT: FAIL**

The Milestone 1 work product **CANNOT BE APPROVED** in its current state.
The orchestrator must reject worker handoff M1-1 and instruct the worker to:
1. Fix `res://core/physics/physical_integrator.gd:66` by removing `force_callable.get_argument_count()` and replacing it with a Godot 4.0.stable-compatible force evaluation mechanism.
2. Re-run `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/empirical_challenge_m1.gd` until exit code is 0.
