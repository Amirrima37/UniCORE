# DISPATCH: Challenger 2 (Tool Integration & Stress Testing)

## Mission
Empirically challenge the integration, performance, and stability of the 5 interactive scientific tools and physics engine bridges.

## Mandatory Inputs to Read
1. `c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md` (Read first!)
2. `c:\dev\UniCORE\.agents\teamwork\orchestrator_2\PROJECT.md`
3. Worker Handoff: `c:\dev\UniCORE\.agents\teamwork\worker_physics_sandbox\handoff.md`

## Adversarial Focus
1. `ParticleInjectorTool` & `MolecularDynamicsModule`:
   - Repeated particle injections: does MultiMesh buffer reallocate correctly?
   - Reset to Maxwell-Boltzmann: are velocities finite and temperature preserved?
2. `CelestialSpawnerTool` & `NBodyGravityModule`:
   - Spawning bodies with extreme mass or relativistic speeds.
   - Entity selection (`find_body_near_ray`): does it pick the closest entity within threshold?
3. `QuantumBenchTool` & `QuantumWavePacketModule`:
   - Rapidly switching potential types and modifying barrier height/width.
4. `ScientificProbeTool`:
   - Sampling fields when no particles are loaded or when particles are far away.
5. Verification:
   - Run `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_interaction_suite.gd`
   - Run `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd`

Render a clear verdict: **CONFIRM** or **DISPUTE** in `c:\dev\UniCORE\.agents\teamwork\challenger_2\handoff.md`.
Notify orchestrator via `send_message`.


## 2026-10-28T17:39:28Z
You are Challenger 2 (Tool Integration & Stress Testing) for UniCORE.
Your working directory is: c:\dev\UniCORE\.agents\teamwork\challenger_2

Read ORIGINAL_REQUEST.md first: c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
Read your dispatch assignment: c:\dev\UniCORE\.agents\teamwork\challenger_2\DISPATCH.md
Read PROJECT.md: c:\dev\UniCORE\.agents\teamwork\orchestrator_2\PROJECT.md
Read Worker Handoff: c:\dev\UniCORE\.agents\teamwork\worker_physics_sandbox\handoff.md

Empirically test the 5 interactive tools, entity selection picking, particle injection bounds, and parameter changes.
Run:
- & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_interaction_suite.gd
- & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd

Render a clear verdict: CONFIRM or DISPUTE in c:\dev\UniCORE\.agents\teamwork\challenger_2\handoff.md.
Notify orchestrator via send_message.
