# Remediation Plan: SpatialHashGrid Aliasing & MolecularDynamics Thermostat Assignment

**Document ID**: `explorer_m3_it2_1/plan_md_remediation.md`  
**Author**: `explorer_m3_it2_1` (Read-Only Exploration Agent)  
**Date**: 2026-10-28T15:38:00Z  
**Status**: APPROVED_FOR_IMPLEMENTATION  
**Target Files**:
1. `res://core/physics/spatial_hash_grid.gd`
2. `res://modules/physics/molecular_dynamics_module.gd`

---

## 1. Executive Summary

Empirical stress testing in Milestone 3 Iteration 1 revealed two critical bugs in the Molecular Dynamics and Spatial Partitioning subsystems:
1. **In-Place Buffer Destruction in `SpatialHashGrid.build_grid`**: In Godot 4.0, `PackedVector3Array` assignments are reference-based. `build_grid(positions)` cached `_positions = positions`. On subsequent calls (such as Step 3 in `VerletIntegrator.integrate` and `compute_potential_energy`), `clear()` executed `_positions.clear()`, wiping the caller's array in-place to size 0. This halted the simulation after 1 tick, producing GDScript out-of-bounds runtime errors at line 460 and 535, causing 292.6% NVE energy drift, and logging `ConservationSentry.audit: Array size mismatch (pos: 0, vel: 500, mass: 500)`.
2. **Compound Assignment Failure on Packed Arrays in `apply_berendsen_thermostat`**: In Godot 4.0 GDScript, `_velocities[i] *= lambda_scale` applies `*=` to a temporary `Vector3` value returned by the indexer getter, failing to write the scaled value back into the contiguous `PackedVector3Array`. As a result, the Berendsen thermostat was a complete no-op, leaving velocities and temperature stuck at their initial values (e.g. $T = 2.9000$) across all 400 steps. Similarly, `_velocities[i] -= v_cm` and `_velocities[i] *= scale` in `_initialize_maxwell_boltzmann_velocities()` failed to remove center-of-mass drift and rescale temperature.

This plan details the exact root causes, mathematical/engine mechanisms, and concrete drop-in code diffs for the implementer worker.

---

## 2. Root Cause Analysis & Empirical Evidence

### 2.1 Issue 1: `SpatialHashGrid` Array Aliasing & Caller Wiping

#### 2.1.1 Location in Code
- File: `res://core/physics/spatial_hash_grid.gd`
- Lines 32-35 (`clear()`):
  ```gdscript
  func clear() -> void:
      _grid.clear()
      _positions.clear()
      _particle_count = 0
  ```
- Lines 73-80 (`build_grid()`):
  ```gdscript
  func build_grid(positions: PackedVector3Array) -> void:
      clear()
      var n: int = positions.size()
      if n == 0:
          return
      
      _positions = positions
      _particle_count = n
  ```

#### 2.1.2 Mechanism
1. In Godot 4.0 GDScript, `PackedVector3Array` is passed by reference (shallow reference to a ref-counted `Vector<Vector3>` buffer).
2. In `MolecularDynamicsModule.step(dt)`:
   - Symplectic Velocity-Verlet calls `_integrator.integrate(_positions, _velocities, _masses, _force_callable, dt)`.
   - `VerletIntegrator.integrate` evaluates forces at $t$: calls `force_callable.call(positions)` (`compute_forces(_positions)`).
   - In `compute_forces`: line 451 executes `_spatial_grid.build_grid(pos)`.
   - On this first call, `_positions = positions` assigns the reference of `MolecularDynamicsModule._positions` to `_spatial_grid._positions`.
   - `VerletIntegrator` advances particle positions to $t + \Delta t$: `positions[i] += velocities[i] * dt + a0 * dt_sq_half`.
   - `VerletIntegrator` evaluates forces at $t + \Delta t$ (Step 3): calls `force_callable.call(positions)`.
   - Inside `compute_forces`: line 451 calls `_spatial_grid.build_grid(pos)` a second time!
   - `build_grid` invokes `clear()`.
   - `clear()` calls `_positions.clear()`.
   - Because `_spatial_grid._positions` references the exact same buffer as `pos` (`MolecularDynamicsModule._positions`), `_positions.clear()` empties the caller's array in-place!
   - `pos.size()` drops to `0`.
   - `build_grid` exits immediately (`if n == 0: return`).
   - Line 459 of `compute_forces` attempts to iterate over the pre-cached `n = 500`:
     Line 460: `var pos_i: Vector3 = pos[i]` throws `SCRIPT ERROR: Out of bounds get index '0' (on base: 'PackedVector3Array')`.
   - `compute_forces` returns empty `_forces`, `VerletIntegrator` halts with `invalid array size at Step 3`, and `MolecularDynamicsModule._positions` is permanently empty.

#### 2.1.3 Verbatim Runtime Errors Observed
From `res://tests/test_challenger_m3_1.gd` and `res://tests/test_reviewer_m3_verification.gd`:
```
SCRIPT ERROR: Out of bounds get index '0' (on base: 'PackedVector3Array')
          at: MolecularDynamicsModule.compute_forces (res://modules/physics/molecular_dynamics_module.gd:460)
ERROR: VerletIntegrator: force_callable returned invalid array size at Step 1
   at: push_error (core/variant/variant_utility.cpp:894)
ERROR: ConservationSentry.audit: Array size mismatch (pos: 0, vel: 500, mass: 500)
   at: push_error (core/variant/variant_utility.cpp:894)
SCRIPT ERROR: Out of bounds get index '0' (on base: 'PackedVector3Array')
          at: MolecularDynamicsModule.compute_potential_energy (res://modules/physics/molecular_dynamics_module.gd:535)
SCRIPT ERROR: Out of bounds get index '1' (on base: 'PackedVector3Array')
          at: _challenge_md_spatial_hash_force_equivalence (res://tests/test_challenger_m3_1.gd:167)
```

---

### 2.2 Issue 2: Compound Assignment Failure on Packed Arrays in `apply_berendsen_thermostat`

#### 2.2.1 Location in Code
- File: `res://modules/physics/molecular_dynamics_module.gd`
- Lines 585-587 (`apply_berendsen_thermostat()`):
  ```gdscript
  for i in range(n):
      _velocities[i] *= lambda_scale
  ```
- Lines 308-317 (`_initialize_maxwell_boltzmann_velocities()`):
  ```gdscript
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
  ```

#### 2.2.2 Mechanism
1. In Godot 4.0 GDScript compiler, `PackedVector3Array` elements are `Vector3` (12-byte structs).
2. The expression `_velocities[i]` returns a temporary `Vector3` Variant by value on the stack.
3. When using compound assignment operators (`*=`, `-=`) between a packed array element and a different operand type (e.g. `Vector3 *= float`), the GDScript virtual machine modifies the temporary `Vector3` Variant on the stack and does NOT issue a `set(i, value)` call back into the `PackedVector3Array`.
4. As a result, `_velocities` remains completely unchanged after `apply_berendsen_thermostat(dt)` executes.
5. In `test_challenger_m3_1.gd` Challenge 3:
   - Initial temperature was sampled at $T = 3.0$ (instantaneous $T = 2.9000$).
   - Cooling to $T = 1.0$ for 400 steps resulted in $T = 2.9000$.
   - Heating to $T = 2.5$ for 400 steps resulted in $T = 2.9000$.
   - The thermostat failed to alter the kinetic energy of the gas by even 0.0001%.

---

### 2.3 Issue 3: NVE Energy Conservation (< 0.005) & Boundary Reflection

#### 2.3.1 NVE Drift Derivation
- In `test_challenger_m3_1.gd` Challenge 2:
  Initial state: $N = 32$, $E_k = 38.4000$, $E_p = -58.3390$, $E_0 = -19.9390$.
- Because `_positions` was wiped to size 0 on step 1 by `SpatialHashGrid.clear()`, the potential energy became $E_p = 0.0$ and no forces were computed.
- The computed drift was:
  $$\text{drift} = \frac{|E_{\text{tot}} - E_0|}{|E_0|} = \frac{|38.4000 - (-19.9390)|}{|-19.9390|} = \frac{58.3390}{19.9390} = 2.925870 \quad (292.6\%)$$
- Once Issue 1 is resolved, Velocity-Verlet with $dt = 0.002$ on 32 Lennard-Jones particles will conserve energy with drift on the order of $\sim 10^{-5}$ to $10^{-4}$, easily passing the $< 0.005$ (0.5%) tolerance.

#### 2.3.2 Boundary Reflection Verification
- In `molecular_dynamics_module.gd:enforce_boundaries()` (lines 606-646):
  - Correctly computes effective bounds: `eff_box = box_half_extent - Vector3(particle_radius, particle_radius, particle_radius)`.
  - Reflects coordinates: `pos.x = eff_box.x - (pos.x - eff_box.x) * e`.
  - Inverts velocity: `vel.x = -vel.x * e`.
  - Clamps: `pos.x = clampf(pos.x, -eff_box.x, eff_box.x)`.
  - Writes back using explicit indexed assignment: `_positions[i] = pos`, `_velocities[i] = vel`.
  - This implementation already passed Challenge 5 in `test_challenger_m3_1.gd` and Test 2.3 in `test_reviewer_m3_verification.gd`. No changes are required in `enforce_boundaries()`.

---

## 3. Concrete Implementation Plan & Code Diffs

### 3.1 Modification 1: `res://core/physics/spatial_hash_grid.gd`

#### Target 1.1: `clear()` (Lines 32-36)
**Rationale**: Reassign `_positions` to a fresh `PackedVector3Array()` rather than calling `_positions.clear()`. This detaches `_positions` from any incoming reference without mutating the caller's array.

```diff
--- a/res://core/physics/spatial_hash_grid.gd
+++ b/res://core/physics/spatial_hash_grid.gd
@@ -32,5 +32,5 @@
 func clear() -> void:
 	_grid.clear()
-	_positions.clear()
+	_positions = PackedVector3Array()
 	_particle_count = 0
```

#### Target 1.2: `build_grid()` (Lines 73-82)
**Rationale**: In addition to safe `clear()`, call `positions.duplicate()` so that the grid's internal buffer is completely decoupled from the caller's simulation state, preventing any external mutations from invalidating neighbor queries.

```diff
--- a/res://core/physics/spatial_hash_grid.gd
+++ b/res://core/physics/spatial_hash_grid.gd
@@ -78,3 +78,3 @@
 	
-	_positions = positions
+	_positions = positions.duplicate()
 	_particle_count = n
```

---

### 3.2 Modification 2: `res://modules/physics/molecular_dynamics_module.gd`

#### Target 2.1: `apply_berendsen_thermostat()` (Lines 585-588)
**Rationale**: Replace compound assignment `_velocities[i] *= lambda_scale` with explicit indexed assignment `_velocities[i] = _velocities[i] * lambda_scale` to force the GDScript VM to invoke the packed array setter.

```diff
--- a/res://modules/physics/molecular_dynamics_module.gd
+++ b/res://modules/physics/molecular_dynamics_module.gd
@@ -585,3 +585,3 @@
 	for i in range(n):
-		_velocities[i] *= lambda_scale
+		_velocities[i] = _velocities[i] * lambda_scale
 	
```

#### Target 2.2: `_initialize_maxwell_boltzmann_velocities()` (Lines 308-317)
**Rationale**: Replace compound assignments `_velocities[i] -= v_cm` and `_velocities[i] *= scale` with explicit indexed assignments to guarantee center-of-mass momentum zeroing and exact initial temperature calibration.

```diff
--- a/res://modules/physics/molecular_dynamics_module.gd
+++ b/res://modules/physics/molecular_dynamics_module.gd
@@ -308,3 +308,3 @@
 	for i in range(n):
-		_velocities[i] -= v_cm
+		_velocities[i] = _velocities[i] - v_cm
 	
@@ -315,3 +315,3 @@
 		for i in range(n):
-			_velocities[i] *= scale
+			_velocities[i] = _velocities[i] * scale
```

---

## 4. Full Replacement Blocks for Implementer

### 4.1 `res://core/physics/spatial_hash_grid.gd`

```gdscript
## Clears all buckets and resets particle caches.
func clear() -> void:
	_grid.clear()
	_positions = PackedVector3Array()
	_particle_count = 0
```

```gdscript
## Bulk builds the grid from a contiguous array of particle positions.
func build_grid(positions: PackedVector3Array) -> void:
	clear()
	var n: int = positions.size()
	if n == 0:
		return
	
	_positions = positions.duplicate()
	_particle_count = n
	var inv_c: float = inverse_cell_size
	
	for i in range(n):
		var pos: Vector3 = positions[i]
		var ix: int = int(floor(pos.x * inv_c))
		var iy: int = int(floor(pos.y * inv_c))
		var iz: int = int(floor(pos.z * inv_c))
		var h: int = (ix * P1) ^ (iy * P2) ^ (iz * P3)
		
		if _grid.has(h):
			var bucket: PackedInt32Array = _grid[h]
			bucket.append(i)
			_grid[h] = bucket
		else:
			var bucket: PackedInt32Array = PackedInt32Array()
			bucket.append(i)
			_grid[h] = bucket
```

---

### 4.2 `res://modules/physics/molecular_dynamics_module.gd`

```gdscript
	# Eliminate center-of-mass momentum drift
	var v_cm: Vector3 = total_p / (float(n) * particle_mass)
	for i in range(n):
		_velocities[i] = _velocities[i] - v_cm
	
	# Rescale to match exact target temperature
	var current_t: float = compute_instantaneous_temperature()
	if current_t > 1e-9:
		var scale: float = sqrt(target_temperature / current_t)
		for i in range(n):
			_velocities[i] = _velocities[i] * scale
```

```gdscript
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
		_velocities[i] = _velocities[i] * lambda_scale
	
	return lambda_scale
```

---

## 5. Verification Method

Once the implementer applies the changes:
1. **Compilation Check**:
   ```powershell
   & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
   ```
   *Expected outcome*: Exit code 0, 0 errors.

2. **Milestone 3 Challenger Suite 1 Verification**:
   ```powershell
   & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_challenger_m3_1.gd
   ```
   *Expected outcome*:
   - Challenge 1: Zero runtime errors, potential energy matches brute force within 1e-3.
   - Challenge 2: NVE relative energy drift < 0.005 over 1000 steps [PASS], peak drift < 0.005 [PASS].
   - Challenge 3: Cooling test reaches $T = 1.0$ within 0.08 [PASS], heating test reaches $T = 2.5$ within 0.12 [PASS].
   - Stderr: Zero `Out of bounds get index '0'` or `VerletIntegrator` error messages.

3. **Milestone 3 Reviewer Verification Suite**:
   ```powershell
   & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_reviewer_m3_verification.gd
   ```
   *Expected outcome*:
   - Test Suite 2 (Molecular Dynamics): All tests pass.
   - Test Suite 6 (Observer Camera Immunity): MD module completes 30 steps with 0 array size mismatch errors and 0 index errors.
