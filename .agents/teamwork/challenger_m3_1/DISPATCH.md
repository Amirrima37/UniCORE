## 2026-10-28T13:34:12Z
You are Challenger M3-1 (teamwork_preview_challenger) assigned to Milestone 3 Empirical Verification.

Your working directory: c:\dev\UniCORE\.agents\teamwork\challenger_m3_1\

READ FIRST:
1. c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
3. c:\dev\UniCORE\GEMINI.md (NO native assert() in tests, use counters and quit(code))
4. c:\dev\UniCORE\.agents\teamwork\worker_m3_1\handoff.md

TARGETS FOR CHALLENGE:
- `res://modules/physics/molecular_dynamics_module.gd`
- `res://shaders/particle_field_glow.gdshader`
- `res://modules/physics/n_body_gravity_module.gd`
- `res://shaders/relativistic_mesh.gdshader`

SCOPE:
1. Write an empirical headless challenger script in `res://tests/test_challenger_m3_1.gd`:
   - Test MolecularDynamicsModule: NVE energy conservation (relative drift < 0.005 over 1,000 steps without thermostat), Berendsen thermostat equilibration toward T_target, Maxwell-Boltzmann velocity distribution match, SpatialHashGrid half-shell force equivalence vs brute force.
   - Test NBodyGravityModule: Relativistic speed cap (particle accelerating towards massive singularity never exceeds c_sim), 1PN perihelion precession advance in Mercury-like orbit matching analytical rate, Barnes-Hut octree acceleration integration, and orbit trail buffer stability.
2. Execute the test script via:
   `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_challenger_m3_1.gd`
3. Record all quantitative outputs, write `challenge_report.md` and 5-component `handoff.md` to your working directory.
4. Issue verdict (**APPROVE** or **REQUEST_CHANGES**) and send completion message to orchestrator parent.
