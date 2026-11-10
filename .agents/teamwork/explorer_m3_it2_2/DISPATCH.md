# Dispatch: Remediation Explorer M3-IT2-2 (N-Body Octree Cache & Preset Invalidation)

## Objective
Analyze the root cause and formulate the exact fix strategy for:
1. `NBodyGravityModule` (`res://modules/physics/n_body_gravity_module.gd`):
   - When switching presets (e.g. from `preset_relativistic_precession()` to `preset_kepler_2body()`), `_clear_particles()` clears arrays, but does NOT invalidate or clear `_octree`.
   - `_finalize_preset()` computes potential energy via `_octree.compute_total_potential_energy()`. Because `barnes_hut_octree.gd` checks only `_particle_count != n or _cached_positions != positions` (and not masses), and both presets have N=2, the Kepler bodies evaluate potential against the leftover 100-mass Sun from the previous preset (`initial_e = -49.689` vs `final_e = -0.2498`), producing a 99.5% energy mismatch and failing Test 3.2.2.
2. `BarnesHutOctree` (`res://core/physics/barnes_hut_octree.gd`):
   - Ensure `compute_total_potential_energy()` and `compute_forces()` correctly detect when masses change, or ensure `clear()` resets cached state.
   - Ensure `_clear_particles()` and `_finalize_preset()` in `NBodyGravityModule` explicitly rebuild or clear `_octree`.

## Inputs
- `c:\dev\UniCORE\ORIGINAL_REQUEST.md`
- `c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md`
- `c:\dev\UniCORE\.agents\teamwork\reviewer_m3_1_rep\handoff.md`
- `c:\dev\UniCORE\.agents\teamwork\challenger_m3_1_rep\handoff.md`
- Target files: `res://modules/physics/n_body_gravity_module.gd`, `res://core/physics/barnes_hut_octree.gd`

## Output
Write detailed analysis and exact GDScript code diffs/replacements to:
`c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_2\plan_nbody_octree_remediation.md`
and write your completion `handoff.md`.

## 2026-10-28T15:30:48Z
Received dispatch message:
You are explorer_m3_it2_2, a read-only exploration agent.
Your working directory is: c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_2\
Your parent conversation ID is: e9e803a1-ad51-4bb6-bbd9-5c64a9f0d796

Read your instructions in: c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_2\DISPATCH.md
Also read:
- c:\dev\UniCORE\ORIGINAL_REQUEST.md
- c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
- c:\dev\UniCORE\.agents\teamwork\reviewer_m3_1_rep\handoff.md
- c:\dev\UniCORE\.agents\teamwork\challenger_m3_1_rep\handoff.md
- res://modules/physics/n_body_gravity_module.gd
- res://core/physics/barnes_hut_octree.gd

Analyze the N-Body gravity preset switching stale octree cache bug (Kepler 2-body calculating potential against 100-mass Sun from previous relativistic preset, causing 99.5% energy drift) and formulate an exact code replacement plan.
Write your analysis and replacement plan to c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_2\plan_nbody_octree_remediation.md
Write your completion handoff.md and send a completion message to your parent using send_message. Do NOT edit source code files.

