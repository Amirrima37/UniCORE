# DISPATCH: Survey Explorer 1 (Spec & Interface Miner)

## Task
Analyze `ORIGINAL_REQUEST.md`, `file:///C:/Users/Amirrima37/.gemini/antigravity/brain/51a93ace-161d-4812-aeda-bc1b959a8496/ui_design_physics_interface_spec.md`, and `file:///C:/Users/Amirrima37/.gemini/antigravity/brain/51a93ace-161d-4812-aeda-bc1b959a8496/scientific_simulation_architecture_spec.md`.

Map out exact requirements, contracts, and math/logic for:
1. `VelocityVectorGizmo` (`res://core/physics/interaction/velocity_vector_gizmo.gd`):
   - 3D procedural meshes (shaft cylinder/line and cone head).
   - Dynamic length proportional to initial velocity magnitude |v_0|.
   - Orientation/rotation alignment to velocity vector direction without NaN singularities when length is zero.
   - Energy color-coding (e.g. cyan -> amber -> red/magenta).
2. `PhysicsInteractionManager` (`res://core/physics/interaction/physics_interaction_manager.gd`):
   - Camera-to-world raycasting on configurable focal planes (e.g., XZ, XY, or camera-perpendicular plane passing through interaction origin) at arbitrary camera angles.
   - Click-and-drag gesture detection: initial click sets spawn position, drag vector determines initial velocity v_0.
   - Entity selection via 3D raycasting/picking, emitting `physics_entity_selected` with metadata dictionary.
   - EventBus integration (`physics_tool_selected`, `physics_parameter_changed`, `physics_entity_selected`).
3. The 5 Interactive Scientific Physics Tools (`res://modules/physics/tools/`):
   - `CelestialSpawnerTool`
   - `ParticleInjectorTool`
   - `NuclearLabTool`
   - `QuantumBenchTool`
   - `ScientificProbeTool`
   Inheritance from `UniCoreModule`, tool activation/deactivation lifecycle, interaction modes, and target physics module bridges.

Write your findings to `c:\dev\UniCORE\.agents\teamwork\explorer_survey_1\analysis.md` and complete with `handoff.md`.

## 2026-10-28T17:09:52Z
You are Explorer Survey 1 (Spec & Interface Miner) for UniCORE.
Your working directory is: c:\dev\UniCORE\.agents\teamwork\explorer_survey_1
Read ORIGINAL_REQUEST.md first: c:\dev\UniCORE\.agents\teamwork\ORIGINAL_REQUEST.md
Read your dispatch assignment: c:\dev\UniCORE\.agents\teamwork\explorer_survey_1\DISPATCH.md
Read reference specifications:
- file:///C:/Users/Amirrima37/.gemini/antigravity/brain/51a93ace-161d-4812-aeda-bc1b959a8496/ui_design_physics_interface_spec.md
- file:///C:/Users/Amirrima37/.gemini/antigravity/brain/51a93ace-161d-4812-aeda-bc1b959a8496/scientific_simulation_architecture_spec.md

Analyze exact requirements, data structures, math formulas, and signals for:
1. VelocityVectorGizmo (res://core/physics/interaction/velocity_vector_gizmo.gd)
2. PhysicsInteractionManager (res://core/physics/interaction/physics_interaction_manager.gd)
3. The 5 Interactive Scientific Physics Tools (CelestialSpawnerTool, ParticleInjectorTool, NuclearLabTool, QuantumBenchTool, ScientificProbeTool in res://modules/physics/tools/)

Write your full analysis to c:\dev\UniCORE\.agents\teamwork\explorer_survey_1\analysis.md and write a soft handoff to c:\dev\UniCORE\.agents\teamwork\explorer_survey_1\handoff.md.
When finished, notify me via send_message.

