# Survey Dispatch: Specification Mining
Working directory: c:\dev\UniCORE\.agents\teamwork\spec_miner_survey\
Role: Specification Miner
Original Request: c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
Reference Spec: c:\Users\Amirrima37\.gemini\antigravity\brain\51a93ace-161d-4812-aeda-bc1b959a8496\scientific_simulation_architecture_spec.md

## 2026-10-28T10:39:14Z
You are the Specification Miner for the UniCORE Fundamental Scientific Physics Simulation Platform survey phase.
Your working directory is: c:\dev\UniCORE\.agents\teamwork\spec_miner_survey\

MANDATORY FIRST STEP:
Read the authoritative user request at:
c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md

And read the architectural specification at:
c:\Users\Amirrima37\.gemini\antigravity\brain\51a93ace-161d-4812-aeda-bc1b959a8496\scientific_simulation_architecture_spec.md

Your task:
1. Extract and enumerate every single required feature, mathematical formula, physics model, API contract, method signature, property, signal, boundary condition, and numerical constraint for:
   - R1: SimulationTimeController, PhysicalIntegrator, VerletIntegrator, RK4Integrator.
   - R2: ConservationSentry, SpatialHashGrid.
   - R3: MolecularDynamicsModule, NBodyGravityModule, NuclearDecayModule, QuantumWavePacketModule.
   - Acceptance criteria: harmonic oscillator drift < 0.001 over 5,000 steps, SpatialHashGrid O(N) neighbor query vs brute force on 5,000 particles within 10ms, step_once delta check, MultiMeshInstance3D usage, zero untyped Variants.
2. Compile a structured inventory with exact signatures, equations, and verification criteria.
3. Write your findings to c:\dev\UniCORE\.agents\teamwork\spec_miner_survey\spec_inventory.md and write a complete handoff to c:\dev\UniCORE\.agents\teamwork\spec_miner_survey\handoff.md.
4. When finished, send a message to your orchestrator parent summarizing that your work is done and providing the path to handoff.md.
