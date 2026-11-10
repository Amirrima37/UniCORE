## 2026-10-28T13:23:15Z
You are Worker M3-1 (teamwork_preview_worker) assigned to Milestone 3 (Modular Physics Simulation Domains).

Your working directory: c:\dev\UniCORE\.agents\teamwork\worker_m3_1\

READ FIRST:
1. c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
3. c:\dev\UniCORE\GEMINI.md
4. c:\dev\UniCORE\.agents\teamwork\explorer_m3_1\blueprint_molecular_dynamics.md
5. c:\dev\UniCORE\.agents\teamwork\explorer_m3_2\blueprint_nbody_gravity.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

EXCLUSIVE WRITE FILE OWNERSHIP (You own ONLY these 4 files):
1. `c:\dev\UniCORE\modules\physics\molecular_dynamics_module.gd`
2. `c:\dev\UniCORE\shaders\particle_field_glow.gdshader`
3. `c:\dev\UniCORE\modules\physics\n_body_gravity_module.gd`
4. `c:\dev\UniCORE\shaders\relativistic_mesh.gdshader`

TASK:
1. Implement `res://modules/physics/molecular_dynamics_module.gd` and `res://shaders/particle_field_glow.gdshader` following `blueprint_molecular_dynamics.md` in full detail (Lennard-Jones 12-6 with analytic shift, square-root-free force evaluation, O(N) SpatialHashGrid neighbor pairing with half-shell j > i, Velocity-Verlet symplectic integration, Berendsen thermostat, reflective cubic boundary container with restitution, Maxwell-Boltzmann velocity sampling, MultiMeshInstance3D single draw call rendering, action bindings, and ConservationSentry auditing).
2. Implement `res://modules/physics/n_body_gravity_module.gd` and `res://shaders/relativistic_mesh.gdshader` following `blueprint_nbody_gravity.md` in full detail (Barnes-Hut Octree acceleration with explicit octree.build() per tick, Velocity-Verlet integration, relativistic speed of light c_sim, Lorentz factor gamma, relativistic momentum & acceleration limit, 1PN perihelion precession correction, MultiMeshInstance3D rendering, ImmediateMesh fading orbit trails, ConservationSentry auditing, and 5 presets).
3. Validate compilation and syntax typing via:
   `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`
   and check individual files with:
   `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE --check-only -s res://modules/physics/molecular_dynamics_module.gd`
   `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE --check-only -s res://modules/physics/n_body_gravity_module.gd`
4. Write your implementation report and 5-component handoff report to `c:\dev\UniCORE\.agents\teamwork\worker_m3_1\handoff.md`.
5. Send completion message to orchestrator parent when done.
