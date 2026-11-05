# DISPATCH: Reviewer 2 (Interaction Engine & Scientific Tools)

## Mission
Independently review the interaction engine, gizmos, and 5 scientific tools delivered by Worker (`c:\dev\UniCORE\.agents\teamwork\worker_physics_sandbox\handoff.md`).

## Mandatory Inputs to Read
1. `c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md` (Read first!)
2. `c:\dev\UniCORE\.agents\teamwork\orchestrator_2\PROJECT.md`
3. Worker Handoff: `c:\dev\UniCORE\.agents\teamwork\worker_physics_sandbox\handoff.md`

## Focus Areas
1. `res://core/physics/interaction/velocity_vector_gizmo.gd`:
   - Safe rotation alignment without NaN on zero length or near-vertical direction.
   - 3D procedural arrow meshes (shaft & cone).
   - Speed/energy color mapping.
2. `res://core/physics/interaction/physics_interaction_manager.gd`:
   - Camera-to-world raycasting on focal planes at arbitrary camera angles.
   - Click-and-drag gesture recognizer for v_0.
   - Entity selection and EventBus dispatch (`physics_entity_selected`).
3. 5 Scientific Tools (`res://modules/physics/tools/`):
   - `celestial_spawner_tool.gd`, `particle_injector_tool.gd`, `nuclear_lab_tool.gd`, `quantum_bench_tool.gd`, `scientific_probe_tool.gd`.
4. Verification Commands:
   - Run `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`
   - Run `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_interaction_suite.gd`
   - Run `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd`

Render a clear verdict: **APPROVE** or **REQUEST_CHANGES** in `c:\dev\UniCORE\.agents\teamwork\reviewer_2\handoff.md`.
Notify orchestrator via `send_message`.

## 2026-10-28T17:39:27Z
You are Reviewer 2 (Interaction Engine & Scientific Tools) for UniCORE.
Your working directory is: c:\dev\UniCORE\.agents\teamwork\reviewer_2

Read ORIGINAL_REQUEST.md first: c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
Read your dispatch assignment: c:\dev\UniCORE\.agents\teamwork\reviewer_2\DISPATCH.md
Read PROJECT.md: c:\dev\UniCORE\.agents\teamwork\orchestrator_2\PROJECT.md
Read Worker Handoff: c:\dev\UniCORE\.agents\teamwork\worker_physics_sandbox\handoff.md

Review VelocityVectorGizmo, PhysicsInteractionManager, and the 5 scientific tools in res://modules/physics/tools/.
Run:
- & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
- & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_interaction_suite.gd
- & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/test_physics_engine_suite.gd

Render a clear verdict: APPROVE or REQUEST_CHANGES in c:\dev\UniCORE\.agents\teamwork\reviewer_2\handoff.md.
Notify orchestrator via send_message.
