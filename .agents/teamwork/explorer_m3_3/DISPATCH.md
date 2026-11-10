## 2026-10-28T13:13:08Z
From: e9e803a1-ad51-4bb6-bbd9-5c64a9f0d796
Priority: MESSAGE_PRIORITY_HIGH

You are Explorer M3-3 (teamwork_preview_explorer) assigned to Milestone 3 (Modular Physics Simulation Domains).

Your working directory: c:\dev\UniCORE\.agents\teamwork\explorer_m3_3\

READ FIRST:
1. c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
3. c:\Users\Amirrima37\.gemini\antigravity\brain\51a93ace-161d-4812-aeda-bc1b959a8496\scientific_simulation_architecture_spec.md § 3.5, Task 7, Task 8
4. c:\dev\UniCORE\core\base_module.gd (UniCoreModule base class)
5. c:\dev\UniCORE\core\physics\simulation_time_controller.gd
6. c:\dev\UniCORE\core\physics\conservation_sentry.gd

SCOPE:
Investigate and produce an exhaustive, production-grade architectural and implementation blueprint for:
1. `res://modules/physics/nuclear_decay_module.gd` (extending `UniCoreModule`):
   - Built-in isotope database: Uranium-235, Radium-226, Carbon-14, Hydrogen-2 (Deuterium), Hydrogen-3 (Tritium), Helium-4 (Alpha).
   - Stochastic Poisson decay model: P(decay in dt) = 1 - exp(-lambda * dt) with lambda = ln(2) / T_half.
   - Decay channels: alpha (He-4 nucleus + Q_alpha), beta- (electron + antineutrino), gamma, spontaneous and induced fission.
   - 4-momentum and kinetic energy conservation during emission: p_daughter = -p_ejected, Q = (m_parent - m_daughter - m_ejected)*c^2.
   - Induced fission chain reaction: neutron strikes U-235 nucleus -> 2 fission fragments + 2-3 free prompt neutrons + energy.
   - MultiMeshInstance3D visualization of nuclei and ejected radiation particles.
2. `res://modules/physics/quantum_wavepacket_module.gd` (extending `UniCoreModule`):
   - Discrete 1D / 2D Schrödinger wavepacket propagation: i*hbar * d(psi)/dt = (-hbar^2 / (2m) * laplacian + V(r)) * psi.
   - Discretized spatial grid with complex wavefunction represented by PackedFloat32Array for real and imaginary parts (psi_R, psi_I).
   - Unitary Cayley / Crank-Nicolson evolution operator or split-operator FFT/matrix method preserving norm integral |psi|^2 = 1.0.
   - Potential barriers: rectangular barrier, harmonic well, barrier tunneling T approx exp(-2*kappa*d) where kappa = sqrt(2m*(V_0 - E)) / hbar.
   - Visualization: height = probability density |psi|^2, color/hue = phase arg(psi).
   - MultiMesh or ImmediateMesh or ArrayMesh surface rendering.

RULES:
- Read-only exploration. DO NOT write code to `res://` yet.
- Produce `c:\dev\UniCORE\.agents\teamwork\explorer_m3_3\blueprint_nuclear_quantum.md` and `handoff.md`.
- Ensure 100% strict GDScript 2.0 static typing and Godot 4.0.stable compatibility.
- Send completion message to orchestrator parent when done.
