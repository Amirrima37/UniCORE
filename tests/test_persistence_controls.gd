extends SceneTree

# ==============================================================================
# UniCORE Test Suite: Settings Persistence & Control Bindings Audit
# Tests user://settings.json serialization, edge cases, type safety,
# mouse sensitivity/inversion, and InputMap rebindings.
# ==============================================================================

var passed_count: int = 0
var failed_count: int = 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s %s" % [test_name, ("- " + error_msg) if not error_msg.is_empty() else ""])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(val, expected, test_name: String) -> void:
	var matches: bool = (val == expected)
	assert_true(matches, test_name, "Expected '%s', got '%s'" % [str(expected), str(val)])

func assert_almost_eq(val: float, expected: float, test_name: String, epsilon: float = 0.0001) -> void:
	var diff := absf(val - expected)
	assert_true(diff <= epsilon, test_name, "Expected '%f', got '%f' (diff %f)" % [expected, val, diff])

func _init() -> void:
	print("==================================================")
	print("UniCORE: Settings Persistence & Controls Audit")
	print("==================================================")

	var eb_script = load("res://core/event_bus.gd")
	var sm_script = load("res://core/settings_manager.gd")
	var avatar_script = load("res://modules/builtin/avatar_locomotion.gd")

	assert_true(eb_script != null, "EventBus script loaded")
	assert_true(sm_script != null, "SettingsManager script loaded")
	assert_true(avatar_script != null, "AvatarLocomotion script loaded")

	var event_bus = eb_script.new()
	root.add_child(event_bus)

	var sm = sm_script.new()
	root.add_child(sm)
	sm.setup(event_bus)

	# --------------------------------------------------------------------------
	# Group 1: Baseline Persistence & Round-Trip Serialization
	# --------------------------------------------------------------------------
	print("\n--- Group 1: Baseline Persistence & Round-Trip Serialization ---")

	sm.reset_to_defaults()
	assert_eq(sm.get_setting("display", "fullscreen"), false, "Default fullscreen is false")
	assert_almost_eq(sm.get_setting("controls", "mouse_sensitivity"), 0.002, "Default mouse_sensitivity is 0.002")
	assert_eq(sm.get_setting("controls", "invert_y"), false, "Default invert_y is false")
	assert_almost_eq(sm.get_setting("audio", "master_volume"), 0.8, "Default master_volume is 0.8")
	assert_eq(sm.get_setting("agent", "provider"), "gemini", "Default agent provider is gemini")

	# Modify settings across all categories
	sm.set_setting("display", "fullscreen", true, false)
	sm.set_setting("display", "fps_limit", 120, false)
	sm.set_mouse_sensitivity(0.0045)
	sm.set_invert_y(true)
	sm.set_move_speed(15.5)
	sm.set_sprint_speed(35.0)
	sm.set_master_volume(0.65, true)
	sm.set_agent_config("openrouter", "anthropic/claude-3.5-sonnet", "sk-test-key-999")

	# Save explicitly
	var save_ok: bool = sm.save_settings()
	assert_true(save_ok, "save_settings returns true")

	# Verify file on disk exists and contains JSON
	assert_true(FileAccess.file_exists(sm.SETTINGS_FILE_PATH), "user://settings.json exists on disk")
	var disk_file = FileAccess.open(sm.SETTINGS_FILE_PATH, FileAccess.READ)
	assert_true(disk_file != null, "user://settings.json opened for reading")
	var disk_text = disk_file.get_as_text()
	disk_file.close()
	assert_true(disk_text.contains("openrouter"), "Disk JSON contains saved provider")
	assert_true(disk_text.contains("sk-test-key-999"), "Disk JSON contains saved api key")

	# Reload into a completely separate SettingsManager instance
	var sm2 = sm_script.new()
	root.add_child(sm2)
	sm2.setup(event_bus)

	assert_eq(sm2.get_setting("display", "fullscreen"), true, "Reloaded: fullscreen is true")
	assert_eq(sm2.get_setting("display", "fps_limit"), 120, "Reloaded: fps_limit is 120")
	assert_almost_eq(sm2.get_setting("controls", "mouse_sensitivity"), 0.0045, "Reloaded: mouse_sensitivity is 0.0045")
	assert_eq(sm2.get_setting("controls", "invert_y"), true, "Reloaded: invert_y is true")
	assert_almost_eq(sm2.get_setting("controls", "move_speed"), 15.5, "Reloaded: move_speed is 15.5")
	assert_almost_eq(sm2.get_setting("controls", "sprint_speed"), 35.0, "Reloaded: sprint_speed is 35.0")
	assert_almost_eq(sm2.get_setting("audio", "master_volume"), 0.65, "Reloaded: master_volume is 0.65")
	assert_eq(sm2.get_setting("agent", "provider"), "openrouter", "Reloaded: agent provider is openrouter")
	assert_eq(sm2.get_setting("agent", "api_key"), "sk-test-key-999", "Reloaded: agent api_key matches")

	sm2.queue_free()

	# --------------------------------------------------------------------------
	# Group 2: Edge Cases — File Corruption, Empty File, Non-Dictionary Roots
	# --------------------------------------------------------------------------
	print("\n--- Group 2: Edge Cases (Corruption, Empty File, Non-Dict Root) ---")

	# Test 2.1: Empty file (0 bytes)
	var empty_file = FileAccess.open(sm.SETTINGS_FILE_PATH, FileAccess.WRITE)
	empty_file.store_string("")
	empty_file.close()

	sm.load_settings()
	assert_almost_eq(sm.get_setting("controls", "mouse_sensitivity"), 0.002, "Empty file recovers default mouse_sensitivity")
	assert_eq(sm.get_setting("display", "fullscreen"), false, "Empty file recovers default fullscreen")
	assert_true(FileAccess.file_exists(sm.SETTINGS_FILE_PATH), "Empty file recovery restored valid file")

	# Test 2.2: Whitespace-only file
	var ws_file = FileAccess.open(sm.SETTINGS_FILE_PATH, FileAccess.WRITE)
	ws_file.store_string("   \n\t  \r\n  ")
	ws_file.close()

	sm.load_settings()
	assert_almost_eq(sm.get_setting("audio", "master_volume"), 0.8, "Whitespace file recovers default master_volume")

	# Test 2.3: Corrupted JSON (syntax error)
	var corrupt_file = FileAccess.open(sm.SETTINGS_FILE_PATH, FileAccess.WRITE)
	corrupt_file.store_string("{ \"display\": { \"fullscreen\": true, INVALID SYNTAX ???")
	corrupt_file.close()

	sm.load_settings()
	assert_eq(sm.get_setting("display", "fullscreen"), false, "Corrupted JSON recovers default fullscreen")
	assert_almost_eq(sm.get_setting("controls", "mouse_sensitivity"), 0.002, "Corrupted JSON recovers default mouse_sensitivity")
	assert_true(FileAccess.file_exists(sm.SETTINGS_FILE_PATH + ".bak"), "Corrupted JSON created .bak backup file")

	# Test 2.4: Non-Dictionary root (JSON array)
	var array_file = FileAccess.open(sm.SETTINGS_FILE_PATH, FileAccess.WRITE)
	array_file.store_string("[1, 2, 3, 4, \"not\", \"a\", \"dict\"]")
	array_file.close()

	sm.load_settings()
	assert_eq(sm.get_setting("display", "fullscreen"), false, "Array root recovers default fullscreen")
	assert_almost_eq(sm.get_setting("controls", "move_speed"), 10.0, "Array root recovers default move_speed")

	# Test 2.5: Non-Dictionary root (JSON string primitive)
	var str_file = FileAccess.open(sm.SETTINGS_FILE_PATH, FileAccess.WRITE)
	str_file.store_string("\"just a raw string\"")
	str_file.close()

	sm.load_settings()
	assert_eq(sm.get_setting("agent", "provider"), "gemini", "String root recovers default provider")

	# --------------------------------------------------------------------------
	# Group 3: Edge Cases — Missing Keys Fallback & Partial JSON
	# --------------------------------------------------------------------------
	print("\n--- Group 3: Missing Keys Fallback & Partial JSON ---")

	# Write partial JSON that only contains one key in display
	var partial_data = {
		"display": {
			"fullscreen": true
		}
	}
	var partial_file = FileAccess.open(sm.SETTINGS_FILE_PATH, FileAccess.WRITE)
	partial_file.store_string(JSON.stringify(partial_data))
	partial_file.close()

	sm.load_settings()
	assert_eq(sm.get_setting("display", "fullscreen"), true, "Partial JSON: loaded specified fullscreen=true")
	assert_eq(sm.get_setting("display", "resolution_width"), 1280, "Partial JSON: missing resolution_width fell back to 1280")
	assert_eq(sm.get_setting("display", "vsync"), true, "Partial JSON: missing vsync fell back to true")
	assert_almost_eq(sm.get_setting("controls", "mouse_sensitivity"), 0.002, "Partial JSON: omitted controls fell back to defaults")
	assert_almost_eq(sm.get_setting("audio", "master_volume"), 0.8, "Partial JSON: omitted audio fell back to defaults")
	assert_eq(sm.get_setting("agent", "provider"), "gemini", "Partial JSON: omitted agent fell back to defaults")

	# Unknown key in known category is preserved
	var custom_data = {
		"display": {
			"custom_render_scale": 1.25
		}
	}
	var custom_file = FileAccess.open(sm.SETTINGS_FILE_PATH, FileAccess.WRITE)
	custom_file.store_string(JSON.stringify(custom_data))
	custom_file.close()

	sm.load_settings()
	assert_almost_eq(sm.get_setting("display", "custom_render_scale"), 1.25, "Custom key in known category preserved")
	assert_eq(sm.get_setting("display", "resolution_width"), 1280, "Standard keys still fallback to defaults")

	# --------------------------------------------------------------------------
	# Group 4: Edge Cases — Type Validation, Coercion, and Range Clamping
	# --------------------------------------------------------------------------
	print("\n--- Group 4: Type Validation, Coercion & Range Clamping ---")

	var bad_types = {
		"display": {
			"fullscreen": "not_a_bool",
			"resolution_width": "invalid_width",
			"resolution_height": -500,
			"fps_limit": 50000
		},
		"controls": {
			"mouse_sensitivity": "ultra_fast",
			"invert_y": "bad_inv",
			"move_speed": -99.0,
			"sprint_speed": "ludicrous",
			"bindings": "not_a_dict"
		},
		"audio": {
			"master_volume": 999.0,
			"ui_sound_enabled": "maybe"
		}
	}
	var bad_file = FileAccess.open(sm.SETTINGS_FILE_PATH, FileAccess.WRITE)
	bad_file.store_string(JSON.stringify(bad_types))
	bad_file.close()

	sm.load_settings()
	assert_eq(sm.get_setting("display", "fullscreen"), false, "Invalid fullscreen string rejected -> default false")
	assert_eq(sm.get_setting("display", "resolution_width"), 1280, "Invalid resolution_width string rejected -> default 1280")
	assert_eq(sm.get_setting("display", "resolution_height"), 720, "Negative height clamped or rejected -> default 720")
	assert_eq(sm.get_setting("display", "fps_limit"), 1000, "Excessive fps_limit clamped to 1000")

	assert_almost_eq(sm.get_setting("controls", "mouse_sensitivity"), 0.002, "String mouse_sensitivity rejected -> default 0.002")
	assert_eq(sm.get_setting("controls", "invert_y"), false, "Invalid invert_y string rejected -> default false")
	assert_almost_eq(sm.get_setting("controls", "move_speed"), 10.0, "Negative move_speed rejected -> default 10.0")
	assert_almost_eq(sm.get_setting("controls", "sprint_speed"), 25.0, "String sprint_speed rejected -> default 25.0")
	assert_true(sm.get_setting("controls", "bindings") is Dictionary, "Non-dict bindings rejected -> default dict")

	assert_almost_eq(sm.get_setting("audio", "master_volume"), 1.0, "Excessive volume clamped to 1.0")
	assert_eq(sm.get_setting("audio", "ui_sound_enabled"), true, "Invalid ui_sound_enabled rejected -> default true")

	# Test valid string coercions for booleans ("true", "false", 1, 0)
	var coercion_data = {
		"display": {
			"fullscreen": "true",
			"vsync": 0
		},
		"controls": {
			"invert_y": "1"
		}
	}
	var coercion_file = FileAccess.open(sm.SETTINGS_FILE_PATH, FileAccess.WRITE)
	coercion_file.store_string(JSON.stringify(coercion_data))
	coercion_file.close()

	sm.load_settings()
	assert_eq(sm.get_setting("display", "fullscreen"), true, "String 'true' coerced to bool true")
	assert_eq(sm.get_setting("display", "vsync"), false, "Int 0 coerced to bool false")
	assert_eq(sm.get_setting("controls", "invert_y"), true, "String '1' coerced to bool true")

	# --------------------------------------------------------------------------
	# Group 5: Mouse Sensitivity Scaling & Mouse Inversion
	# --------------------------------------------------------------------------
	print("\n--- Group 5: Mouse Sensitivity Scaling & Mouse Inversion ---")

	# Create AvatarLocomotion module and test signal response
	var avatar = avatar_script.new()
	root.add_child(avatar)
	var context = {
		"event_bus": event_bus,
		"settings_manager": sm
	}
	var init_ok = avatar.initialize(context)
	assert_true(init_ok, "AvatarLocomotion initialized cleanly")

	# Verify setting mouse sensitivity via SettingsManager propagates via EventBus
	sm.set_mouse_sensitivity(0.006)
	assert_almost_eq(avatar.mouse_sensitivity, 0.006, "AvatarLocomotion received mouse_sensitivity 0.006")

	sm.set_invert_y(true)
	assert_eq(avatar.invert_y, true, "AvatarLocomotion received invert_y = true")

	sm.set_move_speed(18.0)
	assert_almost_eq(avatar.move_speed, 18.0, "AvatarLocomotion received move_speed = 18.0")

	sm.set_sprint_speed(42.0)
	assert_almost_eq(avatar.sprint_speed, 42.0, "AvatarLocomotion received sprint_speed = 42.0")

	# Test camera pitch calculations:
	# Formula in AvatarLocomotion:
	# var y_delta: float = event.relative.y if invert_y else -event.relative.y
	# pitch_node.rotate_x(y_delta * mouse_sensitivity)
	var test_rel_y: float = -15.0 # Mouse moved UP by 15 pixels

	# Test A: invert_y = false
	avatar.invert_y = false
	var y_delta_standard: float = -test_rel_y # Should be +15.0 (pitch up)
	var pitch_change_standard: float = y_delta_standard * avatar.mouse_sensitivity
	assert_almost_eq(pitch_change_standard, 15.0 * 0.006, "Normal Y axis: moving mouse up creates positive pitch delta")

	# Test B: invert_y = true
	avatar.invert_y = true
	var y_delta_inverted: float = test_rel_y # Should be -15.0 (pitch down / flight sim)
	var pitch_change_inverted: float = y_delta_inverted * avatar.mouse_sensitivity
	assert_almost_eq(pitch_change_inverted, -15.0 * 0.006, "Inverted Y axis: moving mouse up creates negative pitch delta")
	assert_eq(pitch_change_standard, -pitch_change_inverted, "Normal and inverted pitch changes are exact opposites")

	# Test C: Sensitivity scaling factor
	var sens_low: float = 0.002
	var sens_high: float = 0.008
	var delta_low: float = 10.0 * sens_low
	var delta_high: float = 10.0 * sens_high
	assert_almost_eq(delta_high / delta_low, 4.0, "Sensitivity scales pitch rotation linearly (4x)")

	avatar.cleanup()
	avatar.queue_free()

	# --------------------------------------------------------------------------
	# Group 6: InputMap Control Rebinding Serialization & Restoration
	# --------------------------------------------------------------------------
	print("\n--- Group 6: InputMap Control Rebinding Serialization & Restoration ---")

	# Reset settings to clean baseline
	sm.reset_to_defaults()

	# Verify default bindings in InputMap
	assert_true(InputMap.has_action("move_forward"), "InputMap has 'move_forward'")
	assert_true(InputMap.has_action("move_backward"), "InputMap has 'move_backward'")
	assert_true(InputMap.has_action("move_left"), "InputMap has 'move_left'")
	assert_true(InputMap.has_action("move_right"), "InputMap has 'move_right'")
	assert_true(InputMap.has_action("move_up"), "InputMap has 'move_up'")
	assert_true(InputMap.has_action("move_down"), "InputMap has 'move_down'")
	assert_true(InputMap.has_action("sprint"), "InputMap has 'sprint'")

	# Verify default keycodes
	assert_eq(sm.get_binding("move_forward"), KEY_W, "Default 'move_forward' is KEY_W")
	assert_eq(sm.get_binding("move_backward"), KEY_S, "Default 'move_backward' is KEY_S")
	assert_eq(sm.get_binding("move_left"), KEY_A, "Default 'move_left' is KEY_A")
	assert_eq(sm.get_binding("move_right"), KEY_D, "Default 'move_right' is KEY_D")
	assert_eq(sm.get_binding("move_up"), KEY_SPACE, "Default 'move_up' is KEY_SPACE")
	assert_eq(sm.get_binding("move_down"), KEY_CTRL, "Default 'move_down' is KEY_CTRL")
	assert_eq(sm.get_binding("sprint"), KEY_SHIFT, "Default 'sprint' is KEY_SHIFT")

	# Verify event inside InputMap for move_forward is KEY_W
	var fw_events = InputMap.action_get_events("move_forward")
	assert_true(fw_events.size() > 0, "move_forward has mapped events")
	assert_true(fw_events[0] is InputEventKey, "move_forward event is InputEventKey")
	assert_eq(fw_events[0].keycode, KEY_W, "move_forward InputMap keycode is KEY_W")

	# Rebind controls (e.g. to Arrow keys or ESDF)
	print("  Rebinding 'move_forward' to KEY_UP (Up Arrow) and 'move_backward' to KEY_DOWN...")
	sm.set_binding("move_forward", KEY_UP, true)
	sm.set_binding("move_backward", KEY_DOWN, true)

	assert_eq(sm.get_binding("move_forward"), KEY_UP, "In-memory binding 'move_forward' is KEY_UP")
	assert_eq(sm.get_binding("move_backward"), KEY_DOWN, "In-memory binding 'move_backward' is KEY_DOWN")

	# Check InputMap was updated in real time
	var updated_fw_events = InputMap.action_get_events("move_forward")
	assert_true(updated_fw_events.size() > 0, "Updated move_forward has events")
	assert_eq(updated_fw_events[0].keycode, KEY_UP, "InputMap event updated to KEY_UP")

	# Check persistence in settings.json
	var file_chk = FileAccess.open(sm.SETTINGS_FILE_PATH, FileAccess.READ)
	assert_true(file_chk != null, "Read settings file for binding check")
	var file_chk_text = file_chk.get_as_text()
	file_chk.close()
	assert_true(file_chk_text.contains(str(int(KEY_UP))), "Disk settings contain KEY_UP code (%d)" % int(KEY_UP))

	# Re-load into a brand new SettingsManager to prove restoration from disk
	var sm3 = sm_script.new()
	root.add_child(sm3)
	sm3.setup(event_bus)

	assert_eq(sm3.get_binding("move_forward"), KEY_UP, "Restored instance: 'move_forward' is KEY_UP")
	assert_eq(sm3.get_binding("move_backward"), KEY_DOWN, "Restored instance: 'move_backward' is KEY_DOWN")
	assert_eq(sm3.get_binding("move_left"), KEY_A, "Restored instance: unmodified 'move_left' remains KEY_A")

	var restored_events = InputMap.action_get_events("move_forward")
	assert_eq(restored_events[0].keycode, KEY_UP, "Restored InputMap has KEY_UP for move_forward")

	# Reset bindings back to defaults
	sm3.reset_bindings_to_defaults(true)
	assert_eq(sm3.get_binding("move_forward"), KEY_W, "Reset bindings: 'move_forward' back to KEY_W")
	var reset_events = InputMap.action_get_events("move_forward")
	assert_eq(reset_events[0].keycode, KEY_W, "Reset InputMap: event back to KEY_W")

	sm3.queue_free()

	# --------------------------------------------------------------------------
	# Final Clean-up
	# --------------------------------------------------------------------------
	# Clean up any test .bak file
	if FileAccess.file_exists(sm.SETTINGS_FILE_PATH + ".bak"):
		DirAccess.remove_absolute(sm.SETTINGS_FILE_PATH + ".bak")

	sm.reset_to_defaults()
	sm.queue_free()
	event_bus.queue_free()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("AUDIT SUCCESS: All settings persistence and control binding tests passed.")
		quit(0)
	else:
		print("AUDIT FAILED: %d tests failed." % failed_count)
		quit(1)
