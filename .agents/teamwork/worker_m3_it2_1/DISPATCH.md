# Dispatch: Worker M3-IT2-1 (Remediation Developer)

## Objective
Implement the exact fixes for all 4 files according to the Master Remediation Blueprint:
`c:\dev\UniCORE\.agents\teamwork\orchestrator_1\remediation_blueprint_m3_it2.md`

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Input Context Documents (READ ALL FIRST)
- `c:\dev\UniCORE\ORIGINAL_REQUEST.md`
- `c:\dev\UniCORE\GEMINI.md`
- `c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md`
- `c:\dev\UniCORE\.agents\teamwork\orchestrator_1\remediation_blueprint_m3_it2.md`
- `c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_1\plan_md_remediation.md`
- `c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_2\plan_nbody_octree_remediation.md`
- `c:\dev\UniCORE\.agents\teamwork\challenger_m3_1_rep\handoff.md`
- `c:\dev\UniCORE\.agents\teamwork\reviewer_m3_1_rep\handoff.md`

## Files You Own Exclusively
- `res://core/physics/spatial_hash_grid.gd`
- `res://modules/physics/molecular_dynamics_module.gd`
- `res://core/physics/barnes_hut_octree.gd`
- `res://modules/physics/n_body_gravity_module.gd`

## Summary of Fixes Required
1. `res://core/physics/spatial_hash_grid.gd`:
   - In `clear()`: `_positions = PackedVector3Array()` (do NOT call `_positions.clear()`).
   - In `build_grid(positions)`: `_positions = positions.duplicate()`.
2. `res://modules/physics/molecular_dynamics_module.gd`:
   - In `_initialize_maxwell_boltzmann_velocities()`:
     `_velocities[i] = _velocities[i] - v_cm`
     `_velocities[i] = _velocities[i] * scale`
   - In `apply_berendsen_thermostat()`:
     `_velocities[i] = _velocities[i] * lambda_scale`
3. `res://core/physics/barnes_hut_octree.gd`:
   - In `build()` and `build_with_bounds()`:
     `_cached_positions = positions.duplicate()`
     `_cached_masses = masses.duplicate()`
   - In `compute_all_accelerations()`, `compute_all_forces()`, and `compute_total_potential_energy()`:
     Rebuild if `_root == null or _particle_count != n or _cached_positions != positions or _cached_masses != masses`.
4. `res://modules/physics/n_body_gravity_module.gd`:
   - In `_calculate_total_potential_energy()`: Ensure `_octree` is instantiated if null.
   - In `_clear_particles()`: call `if _octree: _octree.clear()`.
   - In `_finalize_preset()`: call `if _positions.size() > 0: _octree.build(_positions, _masses)` before calculating initial energy.
   - In `_compute_1pn_pair()`: `var cross_coeff: float = -4.0 * r_vec.dot(v_rel)`.
   - In `_evaluate_forces_barnes_hut()`: apply Special Relativistic acceleration tensor ONLY when 1PN mode is NOT active (`if enable_relativity and not (enable_1pn_correction and primary_body_idx >= 0):`).

## Verification Requirements
Run the following commands using run_command:
1. `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only` (MUST exit 0).
2. `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_challenger_m3_1.gd` (MUST exit 0 with 0 failures).
3. `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_reviewer_m3_verification.gd` (MUST exit 0 with 0 failures).
4. `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd` (MUST exit 0, 88/88 passed).

Write your completion `handoff.md` in `c:\dev\UniCORE\.agents\teamwork\worker_m3_it2_1\` and send a completion message to your parent.


## 2026-10-28T15:51:48Z
You are worker_m3_it2_1, an implementation worker.
Your working directory is: c:\dev\UniCORE\.agents\teamwork\worker_m3_it2_1\
Your parent conversation ID is: e9e803a1-ad51-4bb6-bbd9-5c64a9f0d796

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Read your full instructions in: c:\dev\UniCORE\.agents\teamwork\worker_m3_it2_1\DISPATCH.md
Also read:
- c:\dev\UniCORE\ORIGINAL_REQUEST.md
- c:\dev\UniCORE\GEMINI.md
- c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
- c:\dev\UniCORE\.agents\teamwork\orchestrator_1\remediation_blueprint_m3_it2.md

Files you own exclusively:
- res://core/physics/spatial_hash_grid.gd
- res://modules/physics/molecular_dynamics_module.gd
- res://core/physics/barnes_hut_octree.gd
- res://modules/physics/n_body_gravity_module.gd

Implement the exact code fixes specified in remediation_blueprint_m3_it2.md.
Run the required verification suites:
1. & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
2. & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_challenger_m3_1.gd
3. & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_reviewer_m3_verification.gd
4. & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd

Write your completion report in c:\dev\UniCORE\.agents\teamwork\worker_m3_it2_1\handoff.md and send a completion message to your parent via send_message.
