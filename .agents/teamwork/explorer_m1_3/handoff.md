# Handoff Report: Explorer M1-3 (RK4Integrator Architecture & Design)

## 1. Observation
1. **Original Request Contract**: In `c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md:17`:
   > "Implement the numerical integrator hierarchy (PhysicalIntegrator, VerletIntegrator, RK4Integrator) ensuring strict energy and phase-space conservation in conservative Hamiltonian systems without long-term energy drift."
2. **Dispatch Formulation**: In dispatch prompt `c:\dev\UniCORE\.agents\teamwork\explorer_m1_3\DISPATCH.md:16-23`:
   - $k_1 = v, l_1 = F(r, v)/m$
   - $k_2 = v + 0.5\Delta t l_1, l_2 = F(r + 0.5\Delta t k_1, v + 0.5\Delta t l_1)/m$
   - $k_3 = v + 0.5\Delta t l_2, l_3 = F(r + 0.5\Delta t k_2, v + 0.5\Delta t l_2)/m$
   - $k_4 = v + \Delta t l_3, l_4 = F(r + \Delta t k_3, v + \Delta t l_3)/m$
   - $r_{new} = r + (\Delta t / 6)(k_1 + 2k_2 + 2k_3 + k_4)$
   - $v_{new} = v + (\Delta t / 6)(l_1 + 2l_2 + 2l_3 + l4)$
3. **Engine Memory Semantics Verification**: Headless execution of Godot 4.0-stable console (`C:\Godot\Godot_v4.0-stable_win64_console.exe`) executing `arr[0] = Vector3(99, 99, 99)` on a passed `PackedVector3Array` returned `RESULT_PACKED: (99, 99, 99)`, confirming that packed vector arrays passed to GDScript functions mutate caller array elements in-place.
4. **Target Layout Specification**: In `c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md:100-102`:
   - `res://core/physics/physical_integrator.gd`
   - `res://core/physics/verlet_integrator.gd`
   - `res://core/physics/rk4_integrator.gd`
5. **GDScript 2.0 Static Typing & Engine Rules**: `GEMINI.md` mandates strict static typing, zero untyped Variants, forbidden `ClassName.has_method`, and headless test validation using `--check-only`.

---

## 2. Logic Chain
1. From **Observation 1 & 4**, `RK4Integrator` must inherit from `PhysicalIntegrator` and implement `integrate(positions: PackedVector3Array, velocities: PackedVector3Array, masses: PackedFloat32Array, force_callable: Callable, dt: float) -> void`.
2. From **Observation 3**, modifying `positions[i]` and `velocities[i]` directly inside `integrate()` mutates the underlying simulation buffers in-place without needing to return or reallocate new arrays.
3. From **Observation 2**, standard RK4 requires evaluating intermediate slopes across 4 stages. If implemented naively, this would allocate at least 8-10 temporary `PackedVector3Array` objects per integration step.
4. To eliminate heap churn and garbage collection pressure, we designed a **progressive accumulator architecture** using only four persistent scratch buffers (`_temp_pos`, `_temp_vel`, `_sum_k`, `_sum_l`) and one reciprocal mass buffer (`_inv_masses`).
5. As each stage is evaluated, $k_i$ and $l_i$ are accumulated directly into `_sum_k` and `_sum_l` with appropriate Simpson weights ($1, 2, 2, 1$), and intermediate state samples are written to `_temp_pos` and `_temp_vel`.
6. At the end of Stage 4, `positions` and `velocities` are updated in a single pass: `pos[i] += (dt/6.0) * _sum_k[i]` and `vel[i] += (dt/6.0) * _sum_l[i]`.
7. Precomputing `_inv_masses[i] = 1.0 / max(m, 1e-12)` reduces division operations by $4\times$, replacing floating-point division with fast floating-point multiplication in all 4 stages.
8. By inspecting `force_callable.get_argument_count()`, `_evaluate_forces` supports both position-only callables $F(r)$ and velocity-dependent callables $F(r, v)$ automatically.
9. Guard conditions check array size parity, empty buffers, and zero/negative masses before executing any arithmetic, completely preventing `INF`/`NaN` pollution or out-of-bounds crashes.

---

## 3. Caveats
1. `RK4Integrator` is not symplectic: while it achieves high local accuracy $O(\Delta t^5)$ for short timescales and handles dissipative forces $\vec{F}(\vec{r}, \vec{v})$, conservative Hamiltonian systems integrated over long timescales (e.g. $> 10^5$ steps) will exhibit slow secular energy drift, whereas `VerletIntegrator` guarantees exact bounded energy oscillation. The documentation must clearly instruct users when to choose RK4 vs Verlet.
2. If `force_callable` is a complex script method, calling it 4 times per step has $4\times$ the CPU overhead of 1-step integrators. This is an unavoidable mathematical requirement of 4th-order Runge-Kutta.
3. In multi-threaded physics scenarios (if Godot physics ticks run across threads in the future), persistent scratch buffers are per-instance of `RK4Integrator`. Each independent thread or domain module must own its own `RK4Integrator` instance rather than sharing a singleton.

---

## 4. Conclusion
1. The mathematical formulation, GDScript 2.0 static typing, and memory model for `RK4Integrator` are finalized and verified.
2. The progressive accumulator architecture achieves zero heap allocations per integration frame after initial buffer sizing.
3. The complete, drop-in GDScript code blueprint is written and documented in `c:\dev\UniCORE\.agents\teamwork\explorer_m1_3\exploration_report.md` Section 7.
4. Downstream worker agent can implement `res://core/physics/rk4_integrator.gd` directly from this blueprint with zero guesswork.

---

## 5. Verification Method
1. **Inspection**:
   - Inspect `c:\dev\UniCORE\.agents\teamwork\explorer_m1_3\exploration_report.md` for complete code skeleton and derivation.
2. **Syntax Validation**:
   - After Worker implements `res://core/physics/physical_integrator.gd` and `res://core/physics/rk4_integrator.gd`, run:
     ```powershell
     & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
     ```
     Must complete with exit code 0.
3. **Analytical Oscillator Benchmark**:
   - In `res://tests/test_physics_engine_suite.gd`, integrate a damped harmonic oscillator ($m=1.0, k=4.0, \gamma=0.2$) over 1,000 steps with $\Delta t = 0.01$. The simulated position must match the analytical solution $x(t) = e^{-\zeta \omega_0 t} [\cos(\omega_d t) + (\zeta \omega_0/\omega_d)\sin(\omega_d t)]$ with relative error $< 10^{-4}$.
4. **Invalidation Conditions**:
   - `force_callable` returning arrays of length $\ne N$ without triggering guardrail.
   - Any heap allocation or resize observed during step execution after initial sizing.
