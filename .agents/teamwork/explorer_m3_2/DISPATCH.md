## 2026-10-28T13:13:07Z

You are Explorer M3-2 (teamwork_preview_explorer) assigned to Milestone 3 (Modular Physics Simulation Domains).

Your working directory: c:\dev\UniCORE\.agents\teamwork\explorer_m3_2\

READ FIRST:
1. c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
2. c:\dev\UniCORE\.agents\teamwork\orchestrator_1\PROJECT.md
3. c:\Users\Amirrima37\.gemini\antigravity\brain\51a93ace-161d-4812-aeda-bc1b959a8496\scientific_simulation_architecture_spec.md § 3.3, Task 6
4. c:\dev\UniCORE\core\base_module.gd (UniCoreModule base class)
5. c:\dev\UniCORE\core\physics\simulation_time_controller.gd
6. c:\dev\UniCORE\core\physics\barnes_hut_octree.gd
7. c:\dev\UniCORE\core\physics\verlet_integrator.gd
8. c:\dev\UniCORE\core\physics\conservation_sentry.gd

SCOPE:
Investigate and produce an exhaustive, production-grade architectural and implementation blueprint for:
1. `res://modules/physics/n_body_gravity_module.gd` (extending `UniCoreModule`):
   - Gravitational N-body mechanics accelerated via BarnesHutOctree (O(N log N)) with explicit build() per tick (per Challenger M2-1 caveat).
   - Symplectic Velocity-Verlet numerical integration.
   - Relativistic corrections:
     - Configurable simulation speed of light c_sim (e.g. 5.0 to 100.0 m/s for visual laboratory demonstration).
     - Lorentz contraction factor gamma = 1 / sqrt(1 - v^2/c_sim^2).
     - Relativistic momentum p = gamma * m * v and velocity-dependent acceleration limit preventing v >= c_sim.
     - 1st Post-Newtonian (1PN) perihelion precession correction term: Delta a_1PN = (G*M / (c^2 * r^3)) * [ (4*G*M/r - v^2)*r_vec + 4*(r_vec . v_vec)*v_vec ].
   - MultiMeshInstance3D body rendering for planets/stars.
   - Orbit trail visualizer with fading opacity history (ImmediateMesh or MeshInstance3D line loops).
   - Integration with SimulationTimeController and ConservationSentry.
2. `res://shaders/relativistic_mesh.gdshader`:
   - Spatial shader performing vertex-stage Lorentz contraction along the velocity vector: Delta r' = (1/gamma)*(Delta r . u_hat)*u_hat + (Delta r - (Delta r . u_hat)*u_hat), plus Doppler chromatic shift along the line of sight.

RULES:
- Read-only exploration. DO NOT write code to `res://` yet.
- Produce `c:\dev\UniCORE\.agents\teamwork\explorer_m3_2\blueprint_nbody_gravity.md` and `handoff.md`.
- Ensure 100% strict GDScript 2.0 static typing and Godot 4.0.stable compatibility.
- Send completion message to orchestrator parent when done.
