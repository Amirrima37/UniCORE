# Milestone 3 Iteration 2: Unified Remediation Blueprint

## 1. Overview
This blueprint unifies the remediation plans from `explorer_m3_it2_1`, `explorer_m3_it2_2`, `reviewer_m3_1_rep`, and `challenger_m3_1_rep` to resolve all defects identified during Gate 1 verification.

---

## 2. File-by-File Detailed Fixes

### 2.1 File 1: `res://core/physics/spatial_hash_grid.gd`
- **Issue**: Array reference aliasing in Godot 4.0. `build_grid()` assigned `_positions = positions`. On subsequent calls, `clear()` executed `_positions.clear()`, clearing the caller's array in-place.
- **Fix 1** (Lines 32-35):
  ```gdscript
  func clear() -> void:
      _grid.clear()
      _positions = PackedVector3Array()
      _particle_count = 0
  ```
- **Fix 2** (Lines 78-79):
  ```gdscript
  _positions = positions.duplicate()
  _particle_count = n
  ```

### 2.2 File 2: `res://modules/physics/molecular_dynamics_module.gd`
- **Issue**: In Godot 4.0 GDScript, compound assignment operators (`*=`, `-=`) on `PackedVector3Array[i]` modify temporary Variant values on the stack and do not update the underlying array elements.
- **Fix 1** (Line 309 inside `_initialize_maxwell_boltzmann_velocities`):
  ```gdscript
  for i in range(n):
      _velocities[i] = _velocities[i] - v_cm
  ```
- **Fix 2** (Line 316 inside `_initialize_maxwell_boltzmann_velocities`):
  ```gdscript
  for i in range(n):
      _velocities[i] = _velocities[i] * scale
  ```
- **Fix 3** (Line 586 inside `apply_berendsen_thermostat`):
  ```gdscript
  for i in range(n):
      _velocities[i] = _velocities[i] * lambda_scale
  ```

### 2.3 File 3: `res://core/physics/barnes_hut_octree.gd`
- **Issue**: Cache validation checked only `_particle_count != n or _cached_positions != positions`, omitting `masses` and allowing stale masses to persist across presets. In addition, `_cached_positions = positions` was a shallow alias.
- **Fix 1** (Lines 120-121 in `build` and lines 141-142 in `build_with_bounds`):
  ```gdscript
  _cached_positions = positions.duplicate()
  _cached_masses = masses.duplicate()
  ```
- **Fix 2** (Lines 279, 300, 392):
  In `compute_all_accelerations`, `compute_all_forces`, and `compute_total_potential_energy`, update the rebuild condition to:
  ```gdscript
  if _root == null or _particle_count != n or _cached_positions != positions or _cached_masses != masses:
      build(positions, masses)
  ```

### 2.4 File 4: `res://modules/physics/n_body_gravity_module.gd`
- **Issue 1**: Switching presets did not clear or rebuild `_octree`, leading to Kepler potential evaluating against stale 100-mass Sun.
- **Fix 1** (Lines 419-421 inside `_calculate_total_potential_energy`):
  ```gdscript
  func _calculate_total_potential_energy(positions: PackedVector3Array) -> float:
      if _octree == null:
          _octree = BarnesHutOctree.new(theta_crit, softening, gravitational_constant)
      return _octree.compute_total_potential_energy(positions, _masses, theta_crit, softening, gravitational_constant)
  ```
- **Fix 2** (Lines 625-635 inside `_clear_particles`):
  ```gdscript
  func _clear_particles() -> void:
      _positions.clear()
      _velocities.clear()
      _masses.clear()
      _radii.clear()
      _body_colors.clear()
      _body_names.clear()
      _trail_history.clear()
      if _trail_mesh and _trail_mesh.get_surface_count() > 0:
          _trail_mesh.clear_surfaces()
      if _octree:
          _octree.clear()
  ```
- **Fix 3** (Lines 650-655 inside `_finalize_preset`):
  ```gdscript
  _setup_rendering()
  _setup_trails()
  _update_multimesh_transforms()
  
  if _positions.size() > 0 and _masses.size() == _positions.size():
      _octree.build(_positions, _masses)
  
  if _sentry and is_instance_valid(_sentry):
  ```
- **Issue 2**: 1PN cross-term sign was inverted (`+4.0 * r_vec.dot(v_rel)` instead of `-4.0 * r_vec.dot(v_rel)` with inward `r_vec`), and double-counted Special Relativistic acceleration tensor.
- **Fix 4** (Line 414 inside `_compute_1pn_pair`):
  ```gdscript
  var cross_coeff: float = -4.0 * r_vec.dot(v_rel)
  ```
- **Fix 5** (Lines 378-386 inside `_evaluate_forces_barnes_hut`):
  Apply Special Relativistic acceleration tensor ONLY when 1PN mode is NOT active:
  ```gdscript
  a_eff += a_1pn
  if enable_relativity and not (enable_1pn_correction and primary_body_idx >= 0):
      var a_dot_v: float = a_eff.dot(vel_i)
      var a_rel: Vector3 = (a_eff - (vel_i * (a_dot_v / c_sim_sq))) / gamma
      a_eff = a_rel
  ```

---

## 3. Verification Protocol
1. Run `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only` (exit code 0).
2. Run `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_challenger_m3_1.gd` (exit code 0, 0 failures).
3. Run `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_reviewer_m3_verification.gd` (exit code 0, 0 failures).
4. Run `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd` (exit code 0, 88/88 passed).
