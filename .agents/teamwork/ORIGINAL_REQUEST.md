# Original User Request

## 2026-10-28T10:36:33Z

Implement the Fundamental Scientific Physics Simulation Platform for UniCORE in Godot 4.0.stable, transforming the workspace into a surface-less 3D vacuum laboratory with symplectic numerical integrators, invariant conservation sentries, spatial acceleration, and modular physics domains (thermodynamics, relativity, nuclear decay, and quantum mechanics).

Working directory: c:\dev\UniCORE
Integrity mode: development

## Reference Specification:
See complete mathematical models, API contracts, formulas, and task breakdowns in:
file:///c:/Users/Amirrima37/.gemini/antigravity/brain/51a93ace-161d-4812-aeda-bc1b959a8496/scientific_simulation_architecture_spec.md

## Requirements

### R1. Central Simulation Time Engine & Symplectic Integrators
Implement SimulationTimeController (res://core/physics/simulation_time_controller.gd) supporting variable time scales (0.001x to 1000x), pause, step-by-step frame ticking, and fixed delta distribution. Implement the numerical integrator hierarchy (PhysicalIntegrator, VerletIntegrator, RK4Integrator) ensuring strict energy and phase-space conservation in conservative Hamiltonian systems without long-term energy drift.

### R2. Conservation Law Sentry & Spatial Partitioning Acceleration
Implement ConservationSentry (res://core/physics/conservation_sentry.gd) to continuously audit Noether invariants (total energy E, linear momentum P, angular momentum L, and charge Q), providing real-time drift metrics and adaptive delta feedback. Implement SpatialHashGrid (res://core/physics/spatial_hash_grid.gd) providing O(N) neighbor queries for short-range intermolecular forces and collisions.

### R3. Modular Physics Simulation Domains
Implement the primary computational physics modules extending UniCoreModule:
1. MolecularDynamicsModule: Lennard-Jones 12-6 potential, Berendsen thermostat (T_target), periodic or reflective boundaries, and Maxwell-Boltzmann speed distribution rendered via a single MultiMeshInstance3D.
2. NBodyGravityModule: Relativistic/Newtonian N-body gravitational mechanics with configurable speed of light c_sim, Lorentz contraction factor gamma, and orbit trail visualizers.
3. NuclearDecayModule: Isotope database with stochastic Poisson decay channels (alpha, beta, gamma) and collision cross-sections for induced fission.
4. QuantumWavePacketModule: Discrete 1D/2D Schrodinger wavepacket propagation demonstrating potential barrier tunneling and wave-particle interference.

## Acceptance Criteria

### Numerical & Algorithmic Rigor
- Harmonic oscillator / 2-body Kepler orbit test under VerletIntegrator maintains energy drift |(E(t) - E_0)/E_0| < 0.001 over 5,000 steps.
- SpatialHashGrid neighbor queries on 5,000 particles run within 10 ms and return identical results to brute-force O(N^2) within search radius R.
- SimulationTimeController step-once execution advances accumulated simulation time by exactly fixed_delta.

### Modular Integration & Engine Compatibility
- All code conforms to strict GDScript 2.0 static typing with zero untyped Variant variables and passes & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only with exit code 0.
- Particle systems render using MultiMeshInstance3D without allocating individual Node3D nodes per particle.
- The user observer camera remains completely unaffected by physical fields (no gravity, radiation, or heat applied to avatar).
- Automated headless test suite (res://tests/test_physics_engine_suite.gd) verifies all integrators, sentries, and modules.

## 2026-10-28T17:06:52Z

Implement the Interactive Scientific Physics Sandbox & Toolset for UniCORE in Godot 4.0.stable, enabling user interaction with simulations through 3D raycasting, velocity dragging gizmos, clean removal of obsolete toy modules, and 5 interactive scientific tools.

Working directory: c:\dev\UniCORE
Integrity mode: development

## Reference Specification:
See complete UI and Design interface specifications in:
file:///C:/Users/Amirrima37/.gemini/antigravity/brain/51a93ace-161d-4812-aeda-bc1b959a8496/ui_design_physics_interface_spec.md
and physics architecture in:
file:///C:/Users/Amirrima37/.gemini/antigravity/brain/51a93ace-161d-4812-aeda-bc1b959a8496/scientific_simulation_architecture_spec.md

## Requirements

### R1. Cleanup of Obsolete Modules & Space Template Refactoring
Safely delete obsolete toy modules (res://modules/cube_spawner_tool.gd, particle_system.gd, physics_gravity.gd, llm_turret_mod.gd, quartz_cached_mod.gd). Refactor space_manager.gd template TEMPLATE_TOOL_PLAYGROUND into TEMPLATE_PHYSICS_LAB (mounting n_body_gravity_module and molecular_dynamics_module). Update module_registry_client.gd verified templates to replace toy modules with official physics simulation templates.

### R2. 3D Interaction Engine & Velocity Vector Gizmo
Implement VelocityVectorGizmo (res://core/physics/interaction/velocity_vector_gizmo.gd) using 3D procedural meshes to dynamically visualize the direction, speed magnitude, and color-coded energy of an impulse vector during click-and-drag. Implement PhysicsInteractionManager (res://core/physics/interaction/physics_interaction_manager.gd) handling camera-to-world raycasting on focal planes, drag gestures for initial velocity v_0, entity selection, and EventBus integration.

### R3. Suite of 5 Interactive Scientific Physics Tools
Implement interactive tools extending UniCoreModule in res://modules/physics/tools/:
1. CelestialSpawnerTool: Interactive placement of stars, planets, and black holes with impulse drag and tangent trajectory cones for NBodyGravityModule.
2. ParticleInjectorTool: Thermal gas injection, chamber resizing, and laser heating/cooling for MolecularDynamicsModule.
3. NuclearLabTool: Placement of U-235/Ra-226 assemblies, neutron gun firing, and control rod depth adjustment for NuclearDecayModule.
4. QuantumBenchTool: Placement of potential barriers, step functions, and double-slits with wavepacket emission for QuantumWavePacketModule.
5. ScientificProbeTool: 3D measurement sensor placement recording local field strength, temperature, and radiation flux.

## Acceptance Criteria

### Interaction & Gizmo Rigor
- VelocityVectorGizmo correctly projects 3D arrow with length proportional to velocity |v_0| and aligns rotation to the direction vector without NaN singularities when length is zero.
- PhysicsInteractionManager camera raycast correctly computes 3D intersection points with focal planes at arbitrary camera angles.
- Clicking on existing physical entities selects them and dispatches physics_entity_selected with correct metadata dictionary.

### Engine Cleanliness & Verification
- Obsolete modules are deleted and all references in space_manager.gd and module_registry_client.gd are updated.
- All code conforms to strict GDScript 2.0 static typing with zero untyped Variant variables and passes & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only with exit code 0.
- Automated headless test suite (res://tests/test_physics_interaction_suite.gd) verifies gizmos, raycasting, and tool spawning.
