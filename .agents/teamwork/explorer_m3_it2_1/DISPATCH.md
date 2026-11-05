# Dispatch: Remediation Explorer M3-IT2-1 (SpatialHashGrid & MolecularDynamics)

## Objective
Analyze the root causes and formulate the exact fix strategy for:
1. `SpatialHashGrid` (`res://core/physics/spatial_hash_grid.gd`):
   - In Godot 4.0, `PackedVector3Array` assignments are copy-on-write references.
   - `build_grid(positions)` stores `_positions = positions`.
   - Subsequent calls invoke `clear()`, which calls `_positions.clear()`, wiping the caller's array in-place. On Step 3 of Verlet integration in `MolecularDynamicsModule.step()`, this reduces `_positions` to size 0, throwing `Out of bounds get index '0'` and halting the simulation.
2. `MolecularDynamicsModule` (`res://modules/physics/molecular_dynamics_module.gd`):
   - In Godot 4.0, `arr[i] *= factor` on a `PackedVector3Array` operates on a temporary value returned by the indexer, failing to mutate the element in the packed array. In `apply_berendsen_thermostat()`, check if `_velocities[i] *= lambda` fails to update velocities and ensure `_velocities[i] = _velocities[i] * lambda` is used.
   - Inspect boundary reflection and energy calculations to ensure NVE drift is strictly < 0.005.

## Inputs
- `c:\dev\UniCORE\ORIGINAL_REQUEST.md`
- `c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md`
- `c:\dev\UniCORE\.agents\teamwork\challenger_m3_1_rep\handoff.md`
- `c:\dev\UniCORE\.agents\teamwork\reviewer_m3_1_rep\handoff.md`
- Target files: `res://core/physics/spatial_hash_grid.gd`, `res://modules/physics/molecular_dynamics_module.gd`

## Output
Write detailed analysis and exact GDScript code diffs/replacements to:
`c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_1\plan_md_remediation.md`
and write your completion `handoff.md`.

## 2026-10-28T15:30:47Z
You are explorer_m3_it2_1, a read-only exploration agent.
Your working directory is: c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_1\
Your parent conversation ID is: e9e803a1-ad51-4bb6-bbd9-5c64a9f0d796

Read your instructions in: c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_1\DISPATCH.md
Also read:
- c:\dev\UniCORE\ORIGINAL_REQUEST.md
- c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
- c:\dev\UniCORE\.agents\teamwork\reviewer_m3_1_rep\handoff.md
- c:\dev\UniCORE\.agents\teamwork\challenger_m3_1_rep\handoff.md
- res://core/physics/spatial_hash_grid.gd
- res://modules/physics/molecular_dynamics_module.gd

Analyze the SpatialHashGrid array aliasing bug, the Berendsen thermostat packed array assignment bug, and formulate an exact, tested code replacement plan.
Write your analysis and replacement plan to c:\dev\UniCORE\.agents\teamwork\explorer_m3_it2_1\plan_md_remediation.md
Write your completion handoff.md and send a completion message to your parent using send_message. Do NOT edit source code files.
