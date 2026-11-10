## 2026-10-28T13:23:15Z
You are Worker M3-2 (teamwork_preview_worker) assigned to Milestone 3 (Modular Physics Simulation Domains).

Your working directory: c:\dev\UniCORE\.agents\teamwork\worker_m3_2\

READ FIRST:
1. c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
3. c:\dev\UniCORE\GEMINI.md
4. c:\dev\UniCORE\.agents\teamwork\explorer_m3_3\blueprint_nuclear_quantum.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

EXCLUSIVE WRITE FILE OWNERSHIP (You own ONLY these 2 files):
1. `c:\dev\UniCORE\modules\physics\nuclear_decay_module.gd`
2. `c:\dev\UniCORE\modules\physics\quantum_wavepacket_module.gd`

TASK:
1. Implement `res://modules/physics/nuclear_decay_module.gd` following `blueprint_nuclear_quantum.md` in full detail:
   - 14-species isotope database (U-235, Ra-226, C-14, H-3, H-2, He-4, Th-231, Rn-222, N-14, He-3, Kr-92, Ba-141, Neutron, Electron, Gamma).
   - Stochastic Poisson decay model: P(decay in dt) = 1 - exp(-lambda * dt) with lambda = ln(2) / T_half.
   - Exact 4-momentum and rest-mass-energy conservation during decay emission (p_daughter = -p_ejected, Q = (m_parent - sum(m_products))*c^2).
   - Induced fission chain reaction dynamics: prompt neutron collision with U-235 -> binary fragments + prompt neutrons + energy.
   - SpatialHashGrid O(N) neighbor query acceleration for collision detection and dual MultiMeshInstance3D rendering (nuclei + radiation particles).
   - Integration with SimulationTimeController and ConservationSentry.
2. Implement `res://modules/physics/quantum_wavepacket_module.gd` following `blueprint_nuclear_quantum.md` in full detail:
   - Discrete 1D and 2D Time-Dependent Schrödinger Equation (TDSE) solver on contiguous PackedFloat32Array buffers.
   - Unconditionally unitary 1D Cayley / Crank-Nicolson complex tridiagonal Thomas solver strictly preserving total probability norm sum |psi|^2 dx = 1.0.
   - Symplectic 2D staggered-time leapfrog evolution.
   - Potential barriers: rectangular barrier with tunneling matching analytical transmission T approx (16*E*(V_0-E)/V_0^2) * exp(-2*kappa*d), harmonic well, double slit.
   - Visualization: height = |psi|^2, vertex color hue = phase arg(psi).
   - Dynamic 1D ImmediateMesh ribbon and 2D ArrayMesh surface rendering.
   - Integration with SimulationTimeController and ConservationSentry.
3. Validate compilation and syntax typing via:
   `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`
   and check individual files with:
   `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE --check-only -s res://modules/physics/nuclear_decay_module.gd`
   `& "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE --check-only -s res://modules/physics/quantum_wavepacket_module.gd`
4. Write your implementation report and 5-component handoff report to `c:\dev\UniCORE\.agents\teamwork\worker_m3_2\handoff.md`.
5. Send completion message to orchestrator parent when done.
