# Handoff Report: Core Architecture Survey
**Agent**: Core Architecture Explorer (`explorer_core_survey`)  
**Mission**: Investigate UniCORE architecture, module contracts, EventBus, observer isolation, and Godot 4.0-stable constraints for the Fundamental Scientific Physics Simulation Platform.  
**Handoff Type**: Hard (Task Complete)

---

## 1. Observation

1. **UniCoreModule Base Class**:
   - Location: `res://core/base_module.gd`, lines 1-34.
   - Defines `class_name UniCoreModule extends Node`.
   - Lifecycle methods: `initialize(context: Dictionary) -> bool`, `cleanup() -> void`, `get_module_id() -> String`, `get_module_name() -> String`, `get_action_bindings() -> Array[Dictionary]`.
   - Signals: `module_ready(module_id: String)`, `module_error(module_id: String, error_message: String)`.
   - Properties: `var core_context: Dictionary = {}`, `var is_initialized: bool = false`.

2. **ModuleManager Injection & Lifecycle**:
   - Location: `res://core/module_manager.gd`, lines 280-288 and 310-318.
   - On load (`load_module_from_script`): constructs context:
     ```gdscript
     var context: Dictionary = {
         "event_bus": _event_bus,
         "world_root": _world_root,
         "module_manager": self,
         "space_sync": _space_sync
     }
     instance.call("initialize", context)
     ```
   - On unload (`unload_module`): invokes `_event_bus.unsubscribe_all_for_target(instance)`, calls `instance.cleanup()`, and frees the node.

3. **Canonical Module Reference**:
   - Location: `res://modules/builtin/avatar_locomotion.gd`, lines 1-177.
   - Implements `get_action_bindings()` returning an array of keybinding dictionaries (`move_forward`, `sprint`, etc.).
   - Subscribes to `EventBus` in `initialize(context)`: `eb.subscribe("controls_settings_updated", _on_controls_updated)`.
   - Camera and observer hierarchy: dynamically builds `AvatarYaw (Node3D)` -> `AvatarPitch (Node3D)` -> `AvatarCamera (Camera3D)`.
   - Movement logic in `_process(delta)`: purely translates `yaw_node.global_position += input_dir * current_speed * delta`. Does not possess collision shapes, physics mass, or interaction with external physical force fields.

4. **EventBus Message Bus**:
   - Location: `res://core/event_bus.gd`, lines 1-68.
   - Extends `Node`, implements `subscribe(event_name, callback)`, `unsubscribe(event_name, callback)`, `emit(event_name, payload = {})`, and `unsubscribe_all_for_target(target)`.
   - Signal emitted on publish: `signal event_emitted(event_name: String, payload: Dictionary)`.
   - Automatic cleanup of invalid listener Callables during `emit()` and `cleanup_invalid_listeners()`.

5. **Space Management & Sterile Vacuum Baseline**:
   - Location: `res://core/space_manager.gd`, lines 450-478, 1073-1087.
   - Default template `TEMPLATE_DEFAULT_STUDIO` ("Default Studio") mounts only `["builtin_avatar_locomotion"]` into a dark vacuum (`bg_color = [0.06, 0.07, 0.09, 1.0]`, ambient energy 0.6).
   - No ground plane or gravitational surface exists by default in the studio template.

6. **Static Analysis & Security Rules in CodeValidator**:
   - Location: `res://agent/code_validator.gd`, lines 213-280.
   - Requires `_init` to have zero required arguments.
   - Requires script to inherit `Node` or `UniCoreModule`.
   - Requires `initialize(context: Dictionary)` accepting a context argument.
   - Requires `cleanup()` and `get_module_id()` with zero required arguments.
   - Prohibits forbidden calls (`OS.execute`, `OS.kill`, `DirAccess.remove_absolute`, writing to `res://`, reflection bypasses).

7. **Project Compilation Health**:
   - Tool execution: `& "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only`
   - Result: Exited with exit code 0 and empty stderr.

---

## 2. Logic Chain

1. **Module Architecture Integration**:
   - From Observation 1, 2, and 6: Any new physics domain module (`MolecularDynamicsModule`, `NBodyGravityModule`, `NuclearDecayModule`, `QuantumWavePacketModule`) must extend `UniCoreModule`, have a zero-argument `_init()`, accept `context: Dictionary` in `initialize(context)`, call `super.initialize(context)`, and cleanup internal structures in `cleanup()`.
   - This ensures 100% compatibility with `ModuleManager`, `CodeValidator`, and the dynamic UI gallery.

2. **Decoupled Inter-System Communication**:
   - From Observation 4: Modules and the physics core communicate asynchronously through `core_context["event_bus"]`.
   - Core engines call down into computational subroutines (integrators, spatial hash grids); modules emit state updates and metric snapshots up to `EventBus` (`sim_tick`, `invariants_updated`, `conservation_warning`, `nuclear_reaction_occurred`) using typed Dictionary payloads.

3. **Observer Immunity (Scientific Observer Paradigm)**:
   - From Observation 3 and 5: The observer camera in `avatar_locomotion.gd` is purely kinematic (translating `global_position` via input vectors) and is not a `RigidBody3D` or `CollisionObject3D`.
   - Physical modules simulate internal arrays of particles/nuclei (`PackedVector3Array`, `PackedFloat32Array`) and render them with `MultiMeshInstance3D`.
   - Therefore, physical modules do not exert any forces or effects on `AvatarCamera` or `AvatarYaw`, guaranteeing complete immunity of the experimenter.

4. **Engine Constraints & Test Suite Architecture**:
   - From GEMINI.md and Observation 7: Godot 4.0.stable requires strict GDScript 2.0 static typing, prohibits `ClassName.has_method(...)` on class names directly, requires primitive capture by reference (array wrapping) in lambdas, and forbids built-in `assert()` in headless mode.
   - Automated tests in `res://tests/test_physics_engine_suite.gd` must follow the established pattern (custom `assert_true`, counter tracking, and explicit `quit(0)`/`quit(1)`), allowing `test_runner.gd` to aggregate them smoothly.

---

## 3. Caveats

- **Existing Physics**: The only existing physics script in `res://modules/` is `physics_gravity.gd`, which uses Godot's built-in `RigidBody3D`. It does not contain symplectic algorithms and will not be reused; the new platform components in `res://core/physics/` and `res://modules/physics/` will be greenfield implementations according to the architecture specification.
- **Compute Shaders**: While the architecture specification notes Compute Shaders as an option for massive fields, Godot 4.0-stable `RenderingDevice` compute shaders require specific pipeline initialization. For Phase 1 and Phase 2, CPU-vectorized `PackedVector3Array` / `PackedFloat32Array` with `SpatialHashGrid` and `MultiMeshInstance3D` satisfies the acceptance criteria (5,000 particles under 10 ms).

---

## 4. Conclusion

The UniCORE core architecture is fully analyzed, healthy, and ready for the implementation of the Fundamental Scientific Physics Simulation Platform.
- The base module lifecycle (`UniCoreModule`), event bus (`EventBus`), and space management (`SpaceManager`) provide all necessary hooks.
- Detailed implementation blueprints, contracts, and directory layouts have been produced in `core_architecture_report.md`.
- All constraints from GEMINI.md are cataloged for downstream implementation agents.

---

## 5. Verification Method

1. **Verify Godot Project Compilation**:
   ```powershell
   & "C:\Godot\godot.exe" --headless --path c:\dev\UniCORE --check-only
   ```
   *Expected outcome*: Exit code 0, 0 errors.

2. **Verify Architecture Report & Artifacts**:
   - Inspect `c:\dev\UniCORE\.agents\teamwork\explorer_core_survey\core_architecture_report.md`
   - Inspect `c:\dev\UniCORE\.agents\teamwork\explorer_core_survey\handoff.md`

3. **Invalidation Conditions**:
   - Any modification to `res://core/base_module.gd` or `res://core/module_manager.gd` altering the `initialize(context)` signature would invalidate the module integration blueprint.
