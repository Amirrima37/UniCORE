# Runtime object interaction

Use the Select tool, then left-click a generated mesh or gravity body. The cyan box marks the selection. Drag with the left button to apply the mode chosen in the inspector: Move, Rotate, or Scale. Mesh rotation uses degrees; gravity scaling changes its radius. Gravity spheres do not expose rotation.

The inspector supports numeric position/rotation/scale for generated MeshInstance3D objects and position/velocity/mass/radius for gravity bodies. Submit names with Enter. Empty space deselects. Escape restores the transform at the beginning of a drag. The simulation pauses during a drag and returns to its previous pause state on release. Delete and Reset act on the selected object; Reset restores its state at selection time.

Architecture: PhysicsInteractionManager delegates Select-mode input to object_editor.gd. Picking tests mesh bounds in local coordinates and uses the gravity module's ray picker for MultiMesh bodies. A camera-facing plane drives translation. Mesh edits update node transforms; gravity edits update the authoritative arrays which _advance_native uploads with set_state before advancing C++. No C++ binding change is needed. Existing spawn tools retain their velocity gesture.

Files:
- core/physics/interaction/object_editor.gd: picking, selection outline, gesture ownership, runtime inspector and edits.
- core/physics/interaction/physics_interaction_manager.gd: Select-mode delegation and selected-object actions.
- modules/physics/n_body_gravity_module.gd: validated body edit and snapshot API.
- ui/physics/physics_inspector_drawer.gd: subscribes to entity updates.
- tests/test_object_editor_suite.gd: regression coverage for generated meshes and gravity state edits.

Verification on Godot 4.0:
- test_physics_interaction_suite.gd: 60 checks passed.
- test_object_editor_suite.gd: 12 checks passed.
- Headless editor parse/import and application startup completed; headless rendering emits dummy mesh warnings and startup reports disconnected network warnings.

Manual checks:
1. Load a generated cube, select it and drag it. Try Move, Rotate and Scale.
2. Edit each inspector component; verify the mesh follows and values follow subsequent drags.
3. Drag over the inspector and release; the gesture must stop. Escape must restore the starting transform.
4. Load gravity, select a body, edit position/mass/velocity/radius, then resume simulation.
5. Click empty space, delete a selection, unload its module, switch domains, and verify no stale outline remains.
6. Check camera RMB navigation and spawn gestures still operate.

Limits: mesh picking uses bounding boxes rather than triangle precision. Molecular/nuclear MultiMesh particles and quantum field samples do not yet expose per-instance edit adapters. Generated scripts that continually overwrite their own transforms can override runtime mesh edits. Runtime mesh edits are not added to persistence or multiplayer replication by this change. GUI visual verification remains manual. Set object_editor.debug_interaction to true for pick logs.
