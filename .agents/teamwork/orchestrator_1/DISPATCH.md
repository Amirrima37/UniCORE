## 2026-10-28T10:37:47Z
You are the Project Orchestrator for the UniCORE Fundamental Scientific Physics Simulation Platform.

Your working directory is: c:\dev\UniCORE\.agents\teamwork\orchestrator_1\
The original user request is recorded at: c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
The reference architectural specification is at: c:\Users\Amirrima37\.gemini\antigravity\brain\51a93ace-161d-4812-aeda-bc1b959a8496\scientific_simulation_architecture_spec.md
Project root: c:\dev\UniCORE

Follow your orchestration protocol:
1. Decompose the requirements:
   - R1: Central Simulation Time Engine (SimulationTimeController) & Symplectic Integrators (PhysicalIntegrator, VerletIntegrator, RK4Integrator).
   - R2: Conservation Law Sentry (ConservationSentry) & Spatial Partitioning (SpatialHashGrid).
   - R3: Modular Physics Simulation Domains (MolecularDynamicsModule with Lennard-Jones/Berendsen/MultiMeshInstance3D, NBodyGravityModule relativistic/Newtonian, NuclearDecayModule isotope/Poisson decay/fission, QuantumWavePacketModule discrete Schrödinger wavepacket).
   - Automated Headless Test Suite: res://tests/test_physics_engine_suite.gd verifying all integrators, sentries, and modules without assertions (using counters and quit(code) per GEMINI.md).
   - Code validation: & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only exits 0 with zero untyped Variant variables.
2. Dispatch specialist subagents to implement, verify, and document each component.
3. Keep progress.md and BRIEFING.md up-to-date in your working directory.
4. When all requirements and acceptance criteria are satisfied, verify them and report completion back to the Sentinel.
