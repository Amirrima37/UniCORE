# Dispatch Log

## 2026-10-28T17:08:23Z
You are the Project Orchestrator for the next milestone of UniCORE: "Interactive Scientific Physics Sandbox & Toolset in Godot 4.0.stable".

Your Identity: Project Orchestrator
Your Working Directory: c:\dev\UniCORE\.agents\teamwork\orchestrator_2
Original User Request: Read the latest entry in c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md (under ## 2026-10-28T17:06:52Z).

Task Summary:
Implement the Interactive Scientific Physics Sandbox & Toolset for UniCORE in Godot 4.0.stable, enabling user interaction with simulations through 3D raycasting, velocity dragging gizmos, clean removal of obsolete toy modules, and 5 interactive scientific tools.

Reference Specifications:
1. UI and Design interface specifications:
file:///C:/Users/Amirrima37/.gemini/antigravity/brain/51a93ace-161d-4812-aeda-bc1b959a8496/ui_design_physics_interface_spec.md
2. Scientific simulation architecture:
file:///C:/Users/Amirrima37/.gemini/antigravity/brain/51a93ace-161d-4812-aeda-bc1b959a8496/scientific_simulation_architecture_spec.md

Core Requirements:
- R1. Cleanup of Obsolete Modules & Space Template Refactoring:
  Safely delete obsolete toy modules (res://modules/cube_spawner_tool.gd, particle_system.gd, physics_gravity.gd, llm_turret_mod.gd, quartz_cached_mod.gd).
  Refactor space_manager.gd template TEMPLATE_TOOL_PLAYGROUND into TEMPLATE_PHYSICS_LAB (mounting n_body_gravity_module and molecular_dynamics_module).
  Update module_registry_client.gd verified templates to replace toy modules with official physics simulation templates.
- R2. 3D Interaction Engine & Velocity Vector Gizmo:
  Implement VelocityVectorGizmo (res://core/physics/interaction/velocity_vector_gizmo.gd) using 3D procedural meshes to dynamically visualize direction, speed magnitude, and color-coded energy of an impulse vector during click-and-drag.
  Implement PhysicsInteractionManager (res://core/physics/interaction/physics_interaction_manager.gd) handling camera-to-world raycasting on focal planes, drag gestures for initial velocity v_0, entity selection, and EventBus integration.
- R3. Suite of 5 Interactive Scientific Physics Tools:
  Implement interactive tools extending UniCoreModule in res://modules/physics/tools/:
  1. CelestialSpawnerTool
  2. ParticleInjectorTool
  3. NuclearLabTool
  4. QuantumBenchTool
  5. ScientificProbeTool
- Acceptance Criteria & Verification:
  - VelocityVectorGizmo correctly projects 3D arrow with length proportional to |v_0| and aligns rotation without NaN singularities when length is zero.
  - PhysicsInteractionManager camera raycast correctly computes 3D intersection points with focal planes at arbitrary camera angles.
  - Clicking on existing physical entities selects them and dispatches physics_entity_selected with correct metadata dictionary.
  - Obsolete modules deleted and all references updated.
  - All code conforms to strict GDScript 2.0 static typing with zero untyped Variant variables and passes & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only with exit code 0.
  - Automated headless test suite (res://tests/test_physics_interaction_suite.gd) verifies gizmos, raycasting, and tool spawning.
