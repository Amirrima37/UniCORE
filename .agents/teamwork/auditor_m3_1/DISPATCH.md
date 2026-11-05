## 2026-10-28T13:34:13Z
From: e9e803a1-ad51-4bb6-bbd9-5c64a9f0d796 (orchestrator parent)
Content:
You are Forensic Auditor M3-1 (teamwork_preview_auditor) assigned to Milestone 3 Forensic Integrity Audit.

Your working directory: c:\dev\UniCORE\.agents\teamwork\auditor_m3_1\

READ FIRST:
1. c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
3. c:\dev\UniCORE\GEMINI.md
4. c:\dev\UniCORE\.agents\teamwork\worker_m3_1\handoff.md
5. c:\dev\UniCORE\.agents\teamwork\worker_m3_2\handoff.md

AUDIT TARGETS:
- `res://modules/physics/molecular_dynamics_module.gd`
- `res://shaders/particle_field_glow.gdshader`
- `res://modules/physics/n_body_gravity_module.gd`
- `res://shaders/relativistic_mesh.gdshader`
- `res://modules/physics/nuclear_decay_module.gd`
- `res://modules/physics/quantum_wavepacket_module.gd`

AUDIT MANDATE (ZERO TOLERANCE):
Perform deep forensic analysis of all 6 deliverables:
1. Check for hardcoded test results, fake returns, facade implementations, or bypassed physics calculations.
2. Verify algorithmic authenticity:
   - Does MolecularDynamicsModule genuinely compute Lennard-Jones forces, Berendsen velocity scaling, and Maxwell-Boltzmann distributions?
   - Does NBodyGravityModule genuinely calculate Barnes-Hut multipole forces, special relativistic acceleration tensor, and 1PN precession?
   - Does NuclearDecayModule genuinely perform stochastic Poisson sampling, 4-momentum conservation, and induced fission?
   - Does QuantumWavePacketModule genuinely solve the Schrödinger equation with unitary Cayley Crank-Nicolson tridiagonal matrices?
3. Verify observer camera immunity (avatar locomotion camera is completely unaffected by physical fields).
4. Verify data-oriented MultiMesh rendering without per-particle Node3D allocations.
5. Create and run an independent headless verification script `res://tests/test_auditor_m3_forensic.gd` testing all 6 deliverables.
6. Write your audit report to `c:\dev\UniCORE\.agents\teamwork\auditor_m3_1\audit_report.md` and 5-component `handoff.md`.
7. Issue binary verdict (**CLEAN** or **INTEGRITY VIOLATION**) and send completion message to orchestrator parent.
