extends SceneTree

# Comprehensive Automated Test Suite for SpaceManager & Space Persistence
# Subagent Beta - Space Management & Serialization Specialist

var passed_count: int = 0
var failed_count: int = 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_approx_eq(a: float, b: float, test_name: String, tolerance: float = 0.001) -> void:
	var diff = abs(a - b)
	assert_true(diff <= tolerance, test_name, "Expected ~%.4f, got %.4f (diff: %.5f)" % [b, a, diff])

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE SpaceManager & Serialization Test Suite")
	print("==================================================")

	var eb_script = load("res://core/event_bus.gd")
	var event_bus: EventBus = eb_script.new()
	root.add_child(event_bus)

	var settings_script = load("res://core/settings_manager.gd")
	var settings_mgr: SettingsManager = settings_script.new()
	root.add_child(settings_mgr)
	settings_mgr.setup(event_bus)

	var mod_mgr_script = load("res://core/module_manager.gd")
	var mod_mgr: ModuleManager = mod_mgr_script.new()
	root.add_child(mod_mgr)

	var world_root: Node3D = Node3D.new()
	root.add_child(world_root)
	mod_mgr.setup(event_bus, world_root)

	var space_mgr_script = load("res://core/space_manager.gd")
	assert_true(space_mgr_script != null, "SpaceManager script loads successfully")

	var space_mgr: SpaceManager = space_mgr_script.new()
	root.add_child(space_mgr)
	space_mgr.setup(mod_mgr, event_bus, world_root, null, settings_mgr)

	# ----------------------------------------------------
	# Requirement 1: Creating Spaces from Templates
	# ----------------------------------------------------
	print("\n--- Requirement 1: Template Spaces Creation ---")

	# 1.1 Default Studio
	var s_default = space_mgr.create_new_space("Test Default Studio", "Default Studio")
	assert_true(s_default.has("id"), "Default Studio created with valid dict")
	assert_true(space_mgr.current_space_name == "Test Default Studio", "Current space is Test Default Studio")
	var active_mods = mod_mgr.get_active_module_ids()
	assert_true("builtin_ground_plane" in active_mods, "Default Studio has builtin_ground_plane")
	assert_true("builtin_avatar_locomotion" in active_mods, "Default Studio has builtin_avatar_locomotion")

	# 1.2 Cyber Void
	var s_cyber = space_mgr.create_new_space("Test Cyber Void", "Cyber Void")
	assert_true(s_cyber.has("id"), "Cyber Void created with valid dict")
	active_mods = mod_mgr.get_active_module_ids()
	assert_true("builtin_ground_plane" in active_mods, "Cyber Void has builtin_ground_plane")
	assert_true("builtin_avatar_locomotion" in active_mods, "Cyber Void has builtin_avatar_locomotion")
	var cyber_env = s_cyber.get("environment", {})
	assert_true(cyber_env.get("ambient_energy", 1.0) < 0.5, "Cyber Void has dark ambient energy")

	# 1.3 Clean Slate
	var s_clean = space_mgr.create_new_space("Test Clean Slate", "Clean Slate")
	assert_true(s_clean.has("id"), "Clean Slate created with valid dict")
	active_mods = mod_mgr.get_active_module_ids()
	assert_true("builtin_avatar_locomotion" in active_mods, "Clean Slate has builtin_avatar_locomotion")
	assert_false("builtin_ground_plane" in active_mods, "Clean Slate does NOT have builtin_ground_plane (Pure Void)")

	# 1.4 Tool Playground
	var s_tools = space_mgr.create_new_space("Test Tool Playground", "Tool Playground")
	assert_true(s_tools.has("id"), "Tool Playground created with valid dict")
	active_mods = mod_mgr.get_active_module_ids()
	assert_true("builtin_ground_plane" in active_mods, "Tool Playground has builtin_ground_plane")
	assert_true("builtin_avatar_locomotion" in active_mods, "Tool Playground has builtin_avatar_locomotion")
	assert_true("cube_spawner_tool" in active_mods, "Tool Playground has cube_spawner_tool")

	# Verify JSON files exist on disk for all created spaces
	var default_spaces = space_mgr.list_spaces()
	assert_true(default_spaces.size() >= 4, "Space list contains all created template spaces")

	# ----------------------------------------------------
	# Requirement 2: Saving with Active Modules & Camera Transform
	# ----------------------------------------------------
	print("\n--- Requirement 2: Saving Active Modules & Camera Transform ---")

	# Modify camera position and rotation in locomotion
	var locomotion = mod_mgr.get_module("builtin_avatar_locomotion")
	assert_true(locomotion != null, "Locomotion module retrieved")
	locomotion.yaw_node.global_position = Vector3(14.5, 3.2, -9.8)
	locomotion.yaw_node.rotation.y = 1.25
	locomotion.pitch_node.rotation.x = -0.45

	# Add a custom runtime module
	var custom_src := """extends UniCoreModule

func get_module_id() -> String:
	return "custom_dynamic_mod"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	return true
"""
	var custom_inst = mod_mgr.load_module_from_source("custom_dynamic_mod", custom_src)
	assert_true(custom_inst != null, "Dynamic module loaded into space")

	# Save current space
	var save_res = space_mgr.save_current_space()
	assert_true(save_res, "save_current_space() returns true")

	var saved_id = space_mgr.current_space_id
	var saved_file := "%s/%s.json" % [SpaceManager.SPACES_DIR, saved_id]
	assert_true(FileAccess.file_exists(saved_file), "Space JSON file exists on disk")

	# Read and inspect JSON contents directly
	var f = FileAccess.open(saved_file, FileAccess.READ)
	assert_true(f != null, "Space JSON file readable")
	var parsed_json = JSON.parse_string(f.get_as_text())
	f.close()
	assert_true(parsed_json is Dictionary, "Saved space JSON parsed cleanly")

	var cam_dict = parsed_json.get("camera", {})
	assert_approx_eq(cam_dict["position"][0], 14.5, "Saved camera X position")
	assert_approx_eq(cam_dict["position"][1], 3.2, "Saved camera Y position")
	assert_approx_eq(cam_dict["position"][2], -9.8, "Saved camera Z position")
	assert_approx_eq(cam_dict["rotation"][0], -0.45, "Saved camera pitch rotation")
	assert_approx_eq(cam_dict["rotation"][1], 1.25, "Saved camera yaw rotation")

	# Verify custom module was serialized with its source code
	var saved_mods: Array = parsed_json.get("active_modules", [])
	var found_dynamic = false
	for m in saved_mods:
		if m.get("id") == "custom_dynamic_mod":
			found_dynamic = true
			assert_true(m.has("source_code") and not m["source_code"].is_empty(), "Dynamic module source_code serialized")
			break
	assert_true(found_dynamic, "Dynamic module entry found in saved JSON")

	# Reset camera and switch space to verify clean restore
	space_mgr.create_new_space("Scratch Space", "clean_slate")
	assert_true(space_mgr.current_space_name == "Scratch Space", "Switched to Scratch Space")

	# Now load back the saved space
	var load_res = space_mgr.load_space(saved_id)
	assert_true(load_res, "load_space() successfully reloaded space")

	var restored_locomotion = mod_mgr.get_module("builtin_avatar_locomotion")
	assert_true(restored_locomotion != null, "Locomotion restored after load")
	assert_approx_eq(restored_locomotion.yaw_node.global_position.x, 14.5, "Restored camera X pos")
	assert_approx_eq(restored_locomotion.yaw_node.global_position.y, 3.2, "Restored camera Y pos")
	assert_approx_eq(restored_locomotion.yaw_node.global_position.z, -9.8, "Restored camera Z pos")
	assert_approx_eq(restored_locomotion.pitch_node.rotation.x, -0.45, "Restored camera pitch")
	assert_approx_eq(restored_locomotion.yaw_node.rotation.y, 1.25, "Restored camera yaw")

	var restored_dynamic = mod_mgr.get_module("custom_dynamic_mod")
	assert_true(restored_dynamic != null, "Dynamic module restored from serialized source")

	# ----------------------------------------------------
	# Requirement 3: Live Switching & Dangling Node Elimination
	# ----------------------------------------------------
	print("\n--- Requirement 3: Live Switching Without Dangling Nodes ---")

	# Add an untracked loose Node3D directly into world_root
	var loose_node = Node3D.new()
	loose_node.name = "LooseDanglingNode"
	world_root.add_child(loose_node)
	assert_true(world_root.has_node("LooseDanglingNode"), "Loose node added to world_root")

	# Switch live to Clean Slate space
	space_mgr.load_space(s_clean["id"])
	assert_true(space_mgr.current_space_name == "Test Clean Slate", "Switched live to Test Clean Slate")

	# Verify loose dangling node was eliminated
	assert_false(world_root.has_node("LooseDanglingNode"), "Loose dangling node removed on space switch")

	# Verify only Clean Slate modules remain
	var current_mod_ids = mod_mgr.get_active_module_ids()
	assert_true(current_mod_ids.size() == 1, "Only 1 module in Clean Slate")
	assert_true(current_mod_ids[0] == "builtin_avatar_locomotion", "Only locomotion active")
	assert_false(world_root.has_node("custom_dynamic_mod"), "Previous dynamic module removed from tree")
	assert_false(world_root.has_node("builtin_ground_plane"), "Ground plane removed from tree")

	# Switch back to Tool Playground: verify no node name mangling (e.g. no @builtin_avatar_locomotion@2)
	space_mgr.load_space(s_tools["id"])
	assert_true(world_root.has_node("builtin_avatar_locomotion"), "locomotion clean node name")
	assert_false(world_root.has_node("@builtin_avatar_locomotion@2"), "No mangled node names in world_root")

	# ----------------------------------------------------
	# Requirement 4: Deleting Spaces and Cloning (Save As)
	# ----------------------------------------------------
	print("\n--- Requirement 4: Cloning (Save As) and Deleting Spaces ---")

	var cloned_name = "Cloned Playground Space"
	var clone_res = space_mgr.save_space_as(cloned_name)
	assert_true(clone_res, "save_space_as returns true")
	assert_true(space_mgr.current_space_name == cloned_name, "Current space updated to clone name")

	var cloned_id = space_mgr.current_space_id
	assert_true(space_mgr.has_space(cloned_id), "Cloned space exists on disk")
	assert_true(cloned_id != s_tools["id"], "Cloned space has new unique ID")

	# Delete cloned space
	var delete_res = space_mgr.delete_space(cloned_id)
	assert_true(delete_res, "delete_space returns true")
	assert_false(space_mgr.has_space(cloned_id), "Cloned space file removed from disk")

	# Verify current space fallback when current space was deleted
	assert_true(space_mgr.current_space_id != cloned_id, "Current space fell back after deletion")
	assert_true(space_mgr.has_space(space_mgr.current_space_id), "Fallback space is valid and exists")

	# ----------------------------------------------------
	# Requirement 5: Remember and Restore Last Active Space on Boot
	# ----------------------------------------------------
	print("\n--- Requirement 5: Remembering & Restoring Last Active Space on Boot ---")

	# Switch to Cyber Void
	space_mgr.load_space(s_cyber["id"])
	assert_true(space_mgr.current_space_id == s_cyber["id"], "Active space is Cyber Void")

	# Verify settings_mgr and session file have recorded Cyber Void
	var recorded_id = settings_mgr.get_setting("session", "last_active_space", "")
	assert_true(recorded_id == s_cyber["id"], "settings_manager session/last_active_space updated")

	# Clean up current space_mgr to simulate application termination
	space_mgr.queue_free()

	# Create a brand new SpaceManager instance (Cold Boot)
	var booted_space_mgr: SpaceManager = space_mgr_script.new()
	root.add_child(booted_space_mgr)
	booted_space_mgr.setup(mod_mgr, event_bus, world_root, null, settings_mgr)

	# Verify it automatically restored Cyber Void on boot
	assert_true(booted_space_mgr.current_space_id == s_cyber["id"], "New SpaceManager restored Cyber Void on boot")
	assert_true(booted_space_mgr.current_space_name == "Test Cyber Void", "New SpaceManager space name matches")

	# ----------------------------------------------------
	# Requirement 6: Advanced Edge Cases, Cloning, Renaming & Robustness
	# ----------------------------------------------------
	print("\n--- Requirement 6: Edge Cases, Cloning, Renaming & Robustness ---")

	# 6.1 Template normalizer checks
	assert_true(booted_space_mgr.normalize_template_type("Default Studio") == "default", "normalize 'Default Studio' -> default")
	assert_true(booted_space_mgr.normalize_template_type("Cyber Void") == "cyber_void", "normalize 'Cyber Void' -> cyber_void")
	assert_true(booted_space_mgr.normalize_template_type("Clean Slate") == "clean_slate", "normalize 'Clean Slate' -> clean_slate")
	assert_true(booted_space_mgr.normalize_template_type("Tool Playground") == "tool_studio", "normalize 'Tool Playground' -> tool_studio")
	assert_true(booted_space_mgr.normalize_template_type("playground") == "tool_studio", "normalize 'playground' -> tool_studio")
	assert_true(booted_space_mgr.normalize_template_type("unknown_nonexistent") == "default", "fallback unknown -> default")

	# 6.2 Template definitions inspection
	var tmpl_defs = booted_space_mgr.get_template_definitions()
	assert_true(tmpl_defs.size() == 4, "get_template_definitions() returns 4 templates")
	assert_true(tmpl_defs.has("default") and tmpl_defs.has("cyber_void") and tmpl_defs.has("clean_slate") and tmpl_defs.has("tool_studio"), "All 4 template keys present")

	# 6.3 Manifest and space data inspection
	var manifest = booted_space_mgr.get_space_manifest()
	assert_true(manifest.size() > 0, "get_space_manifest returns valid array")
	var spec_data = booted_space_mgr.get_space_data(s_cyber["id"])
	assert_true(spec_data.get("name") == "Test Cyber Void", "get_space_data returns accurate space dict")

	# 6.4 clone_space(source_id, new_name)
	var direct_clone = booted_space_mgr.clone_space(s_clean["id"], "Direct Clean Clone")
	assert_true(not direct_clone.is_empty(), "clone_space creates clone")
	var clone_id = direct_clone.get("id", "")
	assert_true(booted_space_mgr.has_space(clone_id), "Cloned space exists on disk")
	assert_true(direct_clone.get("name") == "Direct Clean Clone", "Clone has correct name")
	assert_true(direct_clone.get("template") == "clean_slate", "Clone preserved template type")

	# 6.5 rename_space(space_id, new_name)
	var rename_state := {"fired": false, "name": ""}
	booted_space_mgr.space_renamed.connect(func(sid, nname):
		if sid == clone_id:
			rename_state["fired"] = true
			rename_state["name"] = nname
	)
	var rename_ok = booted_space_mgr.rename_space(clone_id, "Renamed Clean Clone")
	assert_true(rename_ok, "rename_space returns true")
	assert_true(rename_state["fired"], "space_renamed signal fired")
	assert_true(rename_state["name"] == "Renamed Clean Clone", "space_renamed has correct name")
	var renamed_data = booted_space_mgr.get_space_data(clone_id)
	assert_true(renamed_data.get("name") == "Renamed Clean Clone", "Renamed space file contains updated name")

	# 6.6 rename error paths
	assert_false(booted_space_mgr.rename_space("non_existent_space_id", "New Name"), "rename non-existent space returns false")
	assert_false(booted_space_mgr.rename_space(clone_id, "   "), "rename with empty string returns false")

	# 6.7 ID Uniqueness under rapid sequential creation
	var rapid_name = "Rapid Unique Test"
	var r1 = booted_space_mgr.create_new_space(rapid_name, "default")
	var r2 = booted_space_mgr.create_new_space(rapid_name, "default")
	var r3 = booted_space_mgr.create_new_space(rapid_name, "default")
	assert_true(r1["id"] != r2["id"] and r2["id"] != r3["id"] and r1["id"] != r3["id"], "Rapid sequential spaces have unique IDs")
	assert_true(booted_space_mgr.has_space(r1["id"]) and booted_space_mgr.has_space(r2["id"]) and booted_space_mgr.has_space(r3["id"]), "All rapid spaces exist simultaneously")

	# 6.8 Special / illegal characters in space names
	var special_name = "Lab: Area / Section #1 * <Beta> ? | Test"
	var special_space = booted_space_mgr.create_new_space(special_name, "cyber_void")
	assert_true(not special_space.is_empty(), "Space with special characters created cleanly")
	assert_true(booted_space_mgr.has_space(special_space["id"]), "Special character space exists on disk")
	assert_true(special_space.get("name") == special_name, "Special character space preserves exact original name")

	# 6.9 Malformed JSON resilience
	var corrupt_path := "%s/corrupt_test_file.json" % SpaceManager.SPACES_DIR
	var cf := FileAccess.open(corrupt_path, FileAccess.WRITE)
	cf.store_string("INVALID JSON NOT A DICT {{{")
	cf.close()
	var error_state := {"caught": false}
	booted_space_mgr.space_error.connect(func(_msg): error_state["caught"] = true)
	var load_corrupt = booted_space_mgr.load_space("corrupt_test_file")
	assert_false(load_corrupt, "load_space gracefully handles corrupted JSON")
	assert_true(error_state["caught"], "space_error signal caught for corrupted JSON")
	DirAccess.remove_absolute(corrupt_path)

	# 6.10 Camera restore with Viewport / WorldRoot camera when locomotion is absent
	var custom_cam := Camera3D.new()
	custom_cam.name = "CustomHarnessCam"
	world_root.add_child(custom_cam)
	# Unload all modules so locomotion is null
	for mid in mod_mgr.get_active_module_ids().duplicate():
		mod_mgr.unload_module(mid)
	booted_space_mgr._restore_camera_data({"position": [7.0, 8.0, 9.0], "rotation": [0.1, 0.2, 0.3]})
	assert_approx_eq(custom_cam.global_position.x, 7.0, "Fallback camera X position restored")
	assert_approx_eq(custom_cam.global_position.y, 8.0, "Fallback camera Y position restored")
	assert_approx_eq(custom_cam.global_position.z, 9.0, "Fallback camera Z position restored")
	custom_cam.queue_free()

	# Clean up test spaces created during this test
	var cleanup_spaces = [
		s_default["id"], s_cyber["id"], s_clean["id"], s_tools["id"], saved_id,
		clone_id, r1["id"], r2["id"], r3["id"], special_space["id"]
	]
	for sp_id in cleanup_spaces:
		if booted_space_mgr.has_space(sp_id):
			DirAccess.remove_absolute("%s/%s.json" % [SpaceManager.SPACES_DIR, sp_id])

	# Also delete scratch space if lingering
	var scratch_path := "%s/space_scratch_space_1792290627.json" % SpaceManager.SPACES_DIR
	if FileAccess.file_exists(scratch_path):
		DirAccess.remove_absolute(scratch_path)

	booted_space_mgr.queue_free()
	world_root.queue_free()
	mod_mgr.queue_free()
	settings_mgr.queue_free()
	event_bus.queue_free()

	print("\n==================================================")
	print("SpaceManager Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		quit(0)
	else:
		quit(1)
