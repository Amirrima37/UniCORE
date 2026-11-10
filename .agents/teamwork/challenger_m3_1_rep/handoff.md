# Handoff Report: Challenger M3-1 Empirical Verification

## 1. Observation

- **Execution Command**:
  `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_challenger_m3_1.gd`
- **Exit Code**: `1`
- **Suite Metrics**:
  - Total Asserts: 49
  - Passed: 44
  - Failed: 5
  - Duration: 2380.92 ms
- **Verbatim Failure Output**:
  ```
  FAILURES IDENTIFIED:
    [FAIL] NVE relative energy drift < 0.005 (0.5%) over 1,000 steps - drift=2.950185
    [FAIL] Peak NVE relative energy drift < 0.005 (0.5%) across all steps - peak=2.950185
    [FAIL] Thermostat equilibrates hot gas toward T=1.0 - T=2.9000
    [FAIL] Thermostat equilibrates gas toward T=2.5 - T=2.9000
    [FAIL] 1PN precession matches analytical formula within 25% - err=4.4185

  VERDICT: REQUEST_CHANGES (Exit Code: 1)
  ==================================================================
  SCRIPT ERROR: Out of bounds get index '0' (on base: 'PackedVector3Array')
            at: MolecularDynamicsModule.compute_potential_energy (res://modules/physics/molecular_dynamics_module.gd:535)
  SCRIPT ERROR: Out of bounds get index '0' (on base: 'PackedVector3Array')
            at: MolecularDynamicsModule.compute_potential_energy (res://modules/physics/molecular_dynamics_module.gd:535)
  SCRIPT ERROR: Out of bounds get index '1' (on base: 'PackedVector3Array')
            at: _challenge_md_spatial_hash_force_equivalence (res://tests/test_challenger_m3_1.gd:167)
  SCRIPT ERROR: Out of bounds get index '0' (on base: 'PackedVector3Array')
            at: MolecularDynamicsModule.compute_forces (res://modules/physics/molecular_dynamics_module.gd:460)
  ERROR: VerletIntegrator: force_callable returned invalid array size at Step 1
     at: push_error (core/variant/variant_utility.cpp:894)
  SCRIPT ERROR: Out of bounds get index '0' (on base: 'PackedVector3Array')
            at: MolecularDynamicsModule.compute_forces (res://modules/physics/molecular_dynamics_module.gd:460)
  ERROR: VerletIntegrator: force_callable returned invalid array size at Step 3
     at: push_error (core/variant/variant_utility.cpp:894)
  ```
- **Code Locations Observed**:
  - `res://core/physics/spatial_hash_grid.gd`: lines 32-35 (`func clear(): _positions.clear()`) and lines 73-79 (`func build_grid(positions): clear(); _positions = positions`).
  - `res://modules/physics/molecular_dynamics_module.gd`: line 451 (`_spatial_grid.build_grid(pos)`) and line 525 (`_spatial_grid.build_grid(pos)`).
  - `res://modules/physics/n_body_gravity_module.gd`: lines 413-417 (`cross_coeff = 4.0 * r_vec.dot(v_rel)`) and lines 378-386 (SR acceleration tensor applied on top of `a_eff += a_1pn`).

---

## 2. Logic Chain

1. **Step 1 (In-Place Array Destruction in `SpatialHashGrid`)**:
   Observation 1 shows `SCRIPT ERROR: Out of bounds get index '0'` in `compute_potential_energy` and `ERROR: VerletIntegrator: force_callable returned invalid array size at Step 3`.
   In `spatial_hash_grid.gd`, `build_grid(positions)` stores `_positions = positions` on the first call.
   On subsequent calls (such as Step 3 in `VerletIntegrator` or `compute_potential_energy`), `clear()` invokes `_positions.clear()`.
   Because Godot 4.0 `PackedVector3Array` assignments are copy-on-write references, clearing `_positions` mutates the caller's array (`MolecularDynamicsModule._positions`) in place, reducing its size to 0.
   Consequently, all subsequent force and energy calculations receive an empty array, corrupting the simulation state from Step 1.
2. **Step 2 (NVE and Thermostat Failure Derivation)**:
   Observation 1 records an NVE energy drift of 295.02% and Berendsen thermostat failing to change temperature from 2.9000.
   Because `_positions` is emptied by Step 1 of the logic chain, the particles no longer experience Lennard-Jones forces, causing symplectic Verlet integration and temperature scaling to operate on empty/zero buffers.
3. **Step 3 (1PN Cross-Velocity Sign Inversion)**:
   Observation 1 records 1PN precession error of 441.85% with simulated precession at $-0.8361$ rad ($5.4472$ rad, retrograde).
   In `n_body_gravity_module.gd`, `r_vec` is defined as `pos_j - pos_i = -\vec{r}$ (inward towards the Sun).
   The analytical EIH equation of motion $\Delta\vec{a}_{1PN} = \frac{GM}{c^2 r^3}[ -(\frac{4GM}{r} - v^2)\vec{r} + 4(\vec{r}\cdot\vec{v})\vec{v} ]$ transforms under $\vec{r} = -\vec{r}_{vec}$ to $\frac{GM}{c^2 r^3}[ (\frac{4GM}{r} - v^2)\vec{r}_{vec} - 4(\vec{r}_{vec}\cdot\vec{v})\vec{v} ]$.
   The worker wrote `cross_coeff = +4.0 * r_vec.dot(v_rel)` instead of `-4.0 * r_vec.dot(v_rel)`, flipping the sign of the cross velocity term.
4. **Step 4 (Double-Application of Relativistic Inertia Tensor)**:
   In `n_body_gravity_module.gd`, lines 378-386 apply the Special Relativistic acceleration tensor $\vec{a}_{rel} = \frac{1}{\gamma}[\vec{a}_{eff} - (\vec{a}_{eff}\cdot\vec{v}/c^2)\vec{v}]$ directly to $\vec{a}_{eff} = \vec{a}_N + \vec{a}_{1PN}$.
   Because the 1PN EIH term already accounts for all $O(c^{-2})$ coordinate acceleration terms in the laboratory frame, dividing $\vec{a}_{eff}$ by $\gamma$ applies velocity-dependent inertia twice, causing the orbit to widen, slow down, and precess in the retrograde direction.

---

## 3. Caveats

- **No Caveats Regarding Root Causes**: Both bugs have been empirically reproduced in isolated scripts and traced to exact line numbers.
- **Visual Display Context**: Visual shaders (`particle_field_glow.gdshader`, `relativistic_mesh.gdshader`) were validated via AST uniform parsing and headless material instantiation; full rasterization testing requires a windowed GPU viewport.

---

## 4. Conclusion

Milestone 3 deliverables fail empirical verification with **5 failing tests** and **GDScript runtime out-of-bounds errors**.
The verdict is **REQUEST_CHANGES**.

**Required Worker Changes**:
1. In `res://core/physics/spatial_hash_grid.gd`: In `clear()`, replace `_positions.clear()` with `_positions = PackedVector3Array()`, or duplicate `positions` in `build_grid()`.
2. In `res://modules/physics/n_body_gravity_module.gd`:
   - Line 414: Fix the sign of the cross-velocity term: `var cross_coeff: float = -4.0 * r_vec.dot(v_rel)`.
   - Lines 378-387: Do not pass the 1PN acceleration through the Special Relativistic acceleration tensor (apply SR tensor only when 1PN mode is `OFF`).

---

## 5. Verification Method

1. Run the headless challenger test suite:
   `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_challenger_m3_1.gd`
2. Run the whole-project compilation check:
   `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`
3. Invalidation condition: Exit code `0` on `test_challenger_m3_1.gd` with 0 failures and 0 GDScript errors.
