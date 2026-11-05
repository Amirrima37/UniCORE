## 2026-10-28T13:13:07Z

You are Explorer M3-1 (teamwork_preview_explorer) assigned to Milestone 3 (Modular Physics Simulation Domains).

Your working directory: c:\dev\UniCORE\.agents\teamwork\explorer_m3_1\

READ FIRST:
1. c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
3. c:\Users\Amirrima37\.gemini\antigravity\brain\51a93ace-161d-4812-aeda-bc1b959a8496\scientific_simulation_architecture_spec.md § 3.2, 3.4, Task 5
4. c:\dev\UniCORE\core\base_module.gd (UniCoreModule base class)
5. c:\dev\UniCORE\core\physics\simulation_time_controller.gd
6. c:\dev\UniCORE\core\physics\spatial_hash_grid.gd
7. c:\dev\UniCORE\core\physics\conservation_sentry.gd

SCOPE:
Investigate and produce an exhaustive, production-grade architectural and implementation blueprint for:
1. `res://modules/physics/molecular_dynamics_module.gd` (extending `UniCoreModule`):
   - Lennard-Jones 12-6 pairwise potential: V(r) = 4*epsilon * ((sigma/r)^12 - (sigma/r)^6) with cutoff r_c = 2.5*sigma and potential shift V_shift(r) = V(r) - V(r_c). Force F_ij = 24*(epsilon/sigma^2) * [2*(sigma/r)^14 - (sigma/r)^8] * r_vec.
   - SpatialHashGrid neighbor search integration for O(N) short-range evaluations.
   - Verlet velocity integration.
   - Berendsen thermostat: lambda = sqrt(1 + (dt/tau) * (T_target / T_instant - 1)), rescaling particle velocities toward target temperature.
   - Cubic reflective boundary container with restitution / elasticity.
   - Maxwell-Boltzmann speed distribution initializer f(v) proportional to v^2 * exp(-m*v^2 / (2*k_B*T)).
   - Single MultiMeshInstance3D particle rendering with sphere meshes and instance color / custom data mapped to kinetic energy / velocity magnitude.
   - Action bindings: heat up (KEY_UP), cool down (KEY_DOWN), compress box (KEY_P).
   - Integration with SimulationTimeController sim_tick signal and ConservationSentry audit.
2. `res://shaders/particle_field_glow.gdshader`:
   - Visual shader for particles with kinetic energy/temperature gradient (blue=cold, yellow=medium, red=hot) and glow billboard effects.

RULES:
- Read-only exploration. DO NOT write code to `res://` yet.
- Produce `c:\dev\UniCORE\.agents\teamwork\explorer_m3_1\blueprint_molecular_dynamics.md` and `handoff.md`.
- Ensure 100% strict GDScript 2.0 static typing and Godot 4.0.stable compatibility.
- Send completion message to orchestrator parent when done.
