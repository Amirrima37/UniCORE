## 2026-10-28T11:13:32Z
You are the Physics Core Developer (Worker M1) for Milestone 1 (Central Simulation Time Engine & Integrators).
Your working directory is: c:\dev\UniCORE\.agents\teamwork\worker_m1_1\

MANDATORY FIRST STEP:
Read the authoritative user request at:
c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md

And read the project specification at:
c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md

And read the Explorer blueprints:
- c:\dev\UniCORE\.agents\teamwork\explorer_m1_1\exploration_report.md
- c:\dev\UniCORE\.agents\teamwork\explorer_m1_2\exploration_report.md
- c:\dev\UniCORE\.agents\teamwork\explorer_m1_3\exploration_report.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

EXCLUSIVE WRITE OWNERSHIP:
You own and must implement the following 5 files exclusively:
1. res://core/physics/simulation_time_controller.gd
2. res://core/physics/unit_converter.gd
3. res://core/physics/physical_integrator.gd
4. res://core/physics/verlet_integrator.gd
5. res://core/physics/rk4_integrator.gd

Implementation Requirements:
1. Strict GDScript 2.0 static typing on all properties, parameters, and return types (zero untyped Variants).
2. Follow all Godot 4.0.stable constraints from GEMINI.md.
3. Zero heap allocations inside the integration loops using preallocated scratch buffers and in-place PackedVector3Array mutations.
4. Velocity-Verlet must maintain energy drift < 0.001 over 5,000 steps for a harmonic oscillator.
5. SimulationTimeController must support variable time scales (0.001x to 1000x), pause, max_substeps lag cap, fixed_delta distribution, and step_once() advancing sim_time by exactly fixed_delta.
6. UnitConverter must support bidirectional scalar and vector conversions across Lennard-Jones, Planck, and Astronomical scales.

Verification Step:
Execute the syntax check command via run_command:
& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
Verify it exits with code 0 and zero warnings.

When complete, write your handoff report to:
c:\dev\UniCORE\.agents\teamwork\worker_m1_1\handoff.md
Include the build/check command and result in your handoff report.
Then send a message back to the orchestrator parent.
