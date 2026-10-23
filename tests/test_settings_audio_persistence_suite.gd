extends SceneTree

# ==============================================================================
# UniCORE Automated Test Suite: Settings, Audio, Display & Persistence
# Subagent Alpha (Settings, Audio & Persistence Specialist)
# ==============================================================================

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

func assert_approx_equal(val: float, expected: float, tolerance: float, test_name: String) -> void:
	var diff := absf(val - expected)
	assert_true(diff <= tolerance, test_name, "Expected ~%f, got %f (diff: %f > %f)" % [expected, val, diff, tolerance])

func _init() -> void:
	print("==================================================================")
	print("Starting UniCORE Subagent Alpha Validation Suite")
	print("SettingsManager, DisplayServer F11, AudioServer & Persistence")
	print("==================================================================")

	var settings_script = load("res://core/settings_manager.gd")
	assert_true(settings_script != null, "SettingsManager script loads")

	var eb_script = load("res://core/event_bus.gd")
	var event_bus = eb_script.new()
	root.add_child(event_bus)

	var settings_mgr: SettingsManager = settings_script.new()
	root.add_child(settings_mgr)
	settings_mgr.setup(event_bus)
	settings_mgr.reset_to_defaults()

	# ------------------------------------------------------------------
	# GROUP 1: Fullscreen Modes, F11 Toggling & DisplayServer Resizing
	# ------------------------------------------------------------------
	print("\n--- GROUP 1: Fullscreen Modes, F11 Toggling & Window Resizing ---")
	
	# 1.1 Default state
	assert_false(bool(settings_mgr.get_setting("display", "fullscreen")), "Default fullscreen is false")

	# 1.2 Toggle fullscreen on
	var mode_on: bool = settings_mgr.toggle_fullscreen()
	assert_true(mode_on == true, "toggle_fullscreen() toggles to true")
	assert_true(bool(settings_mgr.get_setting("display", "fullscreen")) == true, "Fullscreen setting updated to true")

	# 1.3 Toggle fullscreen back off (smooth restore)
	var mode_off: bool = settings_mgr.toggle_fullscreen()
	assert_true(mode_off == false, "toggle_fullscreen() toggles back to false")
	assert_true(bool(settings_mgr.get_setting("display", "fullscreen")) == false, "Fullscreen setting updated to false")

	# 1.4 Rapid toggle stress test (no crash, state integrity)
	var rapid_ok := true
	for i in range(10):
		var state := settings_mgr.toggle_fullscreen()
		var expected := (i % 2 == 0)
		if state != expected or bool(settings_mgr.get_setting("display", "fullscreen")) != expected:
			rapid_ok = false
			break
	# Return to false
	if bool(settings_mgr.get_setting("display", "fullscreen")):
		settings_mgr.toggle_fullscreen()
	assert_true(rapid_ok, "Rapid fullscreen toggling maintains consistency without crash")

	# 1.5 Window resolution presets
	assert_true(settings_mgr.RESOLUTION_PRESETS.size() == 4, "4 resolution presets available")
	settings_mgr.set_resolution_by_index(0)
	assert_true(settings_mgr.get_setting("display", "resolution_width") == 1280, "Preset 0 width is 1280")
	assert_true(settings_mgr.get_setting("display", "resolution_height") == 720, "Preset 0 height is 720")
	assert_true(settings_mgr.get_setting("display", "resolution_index") == 0, "Preset index is 0")

	settings_mgr.set_resolution_by_index(1)
	assert_true(settings_mgr.get_setting("display", "resolution_width") == 1600, "Preset 1 width is 1600")
	assert_true(settings_mgr.get_setting("display", "resolution_height") == 900, "Preset 1 height is 900")
	assert_true(settings_mgr.get_setting("display", "resolution_index") == 1, "Preset index is 1")

	settings_mgr.set_resolution_by_index(2)
	assert_true(settings_mgr.get_setting("display", "resolution_width") == 1920, "Preset 2 width is 1920")
	assert_true(settings_mgr.get_setting("display", "resolution_height") == 1080, "Preset 2 height is 1080")
	assert_true(settings_mgr.get_setting("display", "resolution_index") == 2, "Preset index is 2")

	settings_mgr.set_resolution_by_index(3)
	assert_true(settings_mgr.get_setting("display", "resolution_width") == 2560, "Preset 3 width is 2560")
	assert_true(settings_mgr.get_setting("display", "resolution_height") == 1440, "Preset 3 height is 1440")
	assert_true(settings_mgr.get_setting("display", "resolution_index") == 3, "Preset index is 3")

	# 1.6 Out of bounds preset index
	settings_mgr.set_resolution_by_index(-1)
	assert_true(settings_mgr.get_setting("display", "resolution_index") == 3, "Out-of-bounds preset -1 safely ignored")
	settings_mgr.set_resolution_by_index(99)
	assert_true(settings_mgr.get_setting("display", "resolution_index") == 3, "Out-of-bounds preset 99 safely ignored")

	# 1.7 Direct set_resolution syncing with preset index
	settings_mgr.set_resolution(1280, 720, true)
	assert_true(settings_mgr.get_setting("display", "resolution_index") == 0, "Direct set_resolution(1280, 720) auto-syncs preset index to 0")

	# 1.8 Negative resolution clamping
	settings_mgr.set_resolution(-500, -300, true)
	assert_true(settings_mgr.get_setting("display", "resolution_width") >= 640, "Negative width clamped to >= 640")
	assert_true(settings_mgr.get_setting("display", "resolution_height") >= 360, "Negative height clamped to >= 360")

	# 1.9 VSync & FPS limits
	settings_mgr.set_vsync(true)
	assert_true(bool(settings_mgr.get_setting("display", "vsync")) == true, "VSync set to true")
	settings_mgr.set_vsync(false)
	assert_false(bool(settings_mgr.get_setting("display", "vsync")), "VSync set to false")

	settings_mgr.set_fps_limit(60)
	assert_true(Engine.max_fps == 60, "Engine.max_fps set to 60")
	settings_mgr.set_fps_limit(-10)
	assert_true(Engine.max_fps == 0, "Negative FPS limit clamped to 0 (unlimited)")

	# ------------------------------------------------------------------
	# GROUP 2: AudioServer Volume Scaling & Edge Cases
	# ------------------------------------------------------------------
	print("\n--- GROUP 2: AudioServer Volume Scaling & Edge Cases ---")
	var master_bus_idx := AudioServer.get_bus_index("Master")
	assert_true(master_bus_idx >= 0, "Master audio bus found")

	# 2.1 Slider at 0.0 (Must mute bus and set -80 dB)
	settings_mgr.set_master_volume(0.0)
	assert_true(AudioServer.is_bus_mute(master_bus_idx), "AudioServer Master bus muted when volume is 0.0")
	assert_true(AudioServer.get_bus_volume_db(master_bus_idx) <= -80.0, "Volume dB is -80 when muted at 0.0")
	assert_true(float(settings_mgr.get_setting("audio", "master_volume")) == 0.0, "Stored volume setting is 0.0")

	# 2.2 Volume at small epsilon (<= 0.0001 should mute)
	settings_mgr.set_master_volume(0.00005)
	assert_true(AudioServer.is_bus_mute(master_bus_idx), "AudioServer Master bus muted for epsilon <= 0.0001")
	assert_true(AudioServer.get_bus_volume_db(master_bus_idx) <= -80.0, "Volume dB is -80 for epsilon <= 0.0001")

	# 2.3 Negative volume values (-0.5, -100.0) -> safely clamp to 0.0 and mute
	settings_mgr.set_master_volume(-0.5)
	assert_true(AudioServer.is_bus_mute(master_bus_idx), "Master bus muted on negative volume -0.5")
	assert_true(AudioServer.get_bus_volume_db(master_bus_idx) <= -80.0, "Volume dB is -80 on negative volume -0.5")
	assert_true(float(settings_mgr.get_setting("audio", "master_volume")) == 0.0, "Stored volume clamped to 0.0 on negative input")

	settings_mgr.set_master_volume(-100.0)
	assert_true(float(settings_mgr.get_setting("audio", "master_volume")) == 0.0, "Stored volume clamped to 0.0 on -100.0 input")

	# 2.4 Volume at 0.5 (Normal range, un-muted, ~ -6.02 dB)
	settings_mgr.set_master_volume(0.5)
	assert_false(AudioServer.is_bus_mute(master_bus_idx), "Master bus un-muted on volume 0.5")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_bus_idx), linear_to_db(0.5), 0.1, "Volume dB matches linear_to_db(0.5)")
	assert_approx_equal(float(settings_mgr.get_setting("audio", "master_volume")), 0.5, 0.001, "Stored volume is 0.5")

	# 2.5 Volume at 1.0 (Maximum, un-muted, 0.0 dB)
	settings_mgr.set_master_volume(1.0)
	assert_false(AudioServer.is_bus_mute(master_bus_idx), "Master bus un-muted on volume 1.0")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_bus_idx), 0.0, 0.01, "Volume dB is 0.0 dB at 1.0 volume")
	assert_approx_equal(float(settings_mgr.get_setting("audio", "master_volume")), 1.0, 0.001, "Stored volume is 1.0")

	# 2.6 Overflow volume (> 1.0) -> safely clamp to 1.0
	settings_mgr.set_master_volume(2.5)
	assert_approx_equal(float(settings_mgr.get_setting("audio", "master_volume")), 1.0, 0.001, "Volume > 1.0 clamped to 1.0")
	assert_approx_equal(AudioServer.get_bus_volume_db(master_bus_idx), 0.0, 0.01, "Volume dB clamped to 0.0 dB")

	# 2.7 NaN and Inf handling
	settings_mgr.set_master_volume(NAN)
	assert_true(float(settings_mgr.get_setting("audio", "master_volume")) == 0.0, "NAN volume safely handled as 0.0")

	# 2.8 Signal emission
	var signal_received := [false]
	var sig_cat := [""]
	var sig_key := [""]
	var sig_val := [null]
	settings_mgr.setting_changed.connect(func(c, k, v):
		signal_received[0] = true
		sig_cat[0] = c
		sig_key[0] = k
		sig_val[0] = v
	)
	settings_mgr.set_master_volume(0.75)
	assert_true(signal_received[0], "setting_changed signal emitted on volume update")
	assert_true(sig_cat[0] == "audio" and sig_key[0] == "master_volume" and is_equal_approx(float(sig_val[0]), 0.75), "Signal payload correct")

	# ------------------------------------------------------------------
	# GROUP 3: Persistence to user://settings.json
	# ------------------------------------------------------------------
	print("\n--- GROUP 3: Persistence to user://settings.json ---")
	
	# 3.1 Save and verify file existence
	settings_mgr.set_setting("controls", "mouse_sensitivity", 0.0055, false)
	settings_mgr.set_setting("controls", "move_speed", 14.5, false)
	settings_mgr.set_setting("audio", "master_volume", 0.65, false)
	settings_mgr.set_setting("display", "resolution_width", 1600, false)
	settings_mgr.set_setting("display", "resolution_height", 900, false)
	var save_res := settings_mgr.save_settings()
	assert_true(save_res, "save_settings() returns true")
	assert_true(FileAccess.file_exists(SettingsManager.SETTINGS_FILE_PATH), "user://settings.json exists on disk")

	# 3.2 Read file directly and parse JSON
	var raw_file := FileAccess.open(SettingsManager.SETTINGS_FILE_PATH, FileAccess.READ)
	assert_true(raw_file != null, "FileAccess can open user://settings.json")
	var raw_json := raw_file.get_as_text()
	raw_file.close()
	var json_parser := JSON.new()
	var err := json_parser.parse(raw_json)
	assert_true(err == OK, "user://settings.json is valid well-formed JSON")
	var parsed_data: Dictionary = json_parser.get_data()
	assert_true(parsed_data.has("display") and parsed_data.has("controls") and parsed_data.has("audio"), "JSON contains all expected categories")

	# 3.3 New instance loading from disk
	var new_mgr: SettingsManager = settings_script.new()
	root.add_child(new_mgr)
	new_mgr.load_settings()
	assert_approx_equal(float(new_mgr.get_setting("controls", "mouse_sensitivity")), 0.0055, 0.0001, "mouse_sensitivity restored from disk")
	assert_approx_equal(float(new_mgr.get_setting("controls", "move_speed")), 14.5, 0.1, "move_speed restored from disk")
	assert_approx_equal(float(new_mgr.get_setting("audio", "master_volume")), 0.65, 0.01, "master_volume restored from disk")
	assert_true(int(new_mgr.get_setting("display", "resolution_width")) == 1600, "resolution_width restored from disk")
	new_mgr.queue_free()

	# 3.4 Corrupted JSON fallback
	var corrupt_file := FileAccess.open(SettingsManager.SETTINGS_FILE_PATH, FileAccess.WRITE)
	corrupt_file.store_string("{ INVALID JSON SYNTAX ::: ")
	corrupt_file.close()

	var corrupt_test_mgr: SettingsManager = settings_script.new()
	root.add_child(corrupt_test_mgr)
	corrupt_test_mgr.load_settings() # Should not crash
	assert_true(float(corrupt_test_mgr.get_setting("controls", "mouse_sensitivity")) == 0.002, "Corrupt JSON falls back to default sensitivity")
	assert_true(float(corrupt_test_mgr.get_setting("audio", "master_volume")) == 0.8, "Corrupt JSON falls back to default volume")
	corrupt_test_mgr.queue_free()

	# 3.5 Reset to defaults
	settings_mgr.reset_to_defaults()
	assert_true(float(settings_mgr.get_setting("controls", "mouse_sensitivity")) == 0.002, "reset_to_defaults restores sensitivity")
	assert_true(float(settings_mgr.get_setting("audio", "master_volume")) == 0.8, "reset_to_defaults restores volume")
	assert_true(bool(settings_mgr.get_setting("display", "fullscreen")) == false, "reset_to_defaults restores fullscreen to false")

	# ------------------------------------------------------------------
	# GROUP 4: Controls, Mouse Sensitivity Scaling & Key Bindings
	# ------------------------------------------------------------------
	print("\n--- GROUP 4: Controls, Mouse Sensitivity Scaling & Key Bindings ---")
	
	# 4.1 Mouse sensitivity scaling & clamping
	settings_mgr.set_mouse_sensitivity(0.004)
	assert_approx_equal(float(settings_mgr.get_setting("controls", "mouse_sensitivity")), 0.004, 0.0001, "Mouse sensitivity set to 0.004")

	settings_mgr.set_mouse_sensitivity(-0.01)
	assert_true(float(settings_mgr.get_setting("controls", "mouse_sensitivity")) >= 0.0001, "Negative mouse sensitivity clamped to positive minimum")

	settings_mgr.set_mouse_sensitivity(0.0)
	assert_true(float(settings_mgr.get_setting("controls", "mouse_sensitivity")) >= 0.0001, "Zero mouse sensitivity clamped to positive minimum")

	settings_mgr.set_mouse_sensitivity(5.0)
	assert_true(float(settings_mgr.get_setting("controls", "mouse_sensitivity")) <= 0.1, "Excessive mouse sensitivity clamped to 0.1")

	# 4.2 Move and sprint speed controls
	settings_mgr.set_move_speed(12.0)
	assert_true(float(settings_mgr.get_setting("controls", "move_speed")) == 12.0, "Move speed set to 12.0")
	settings_mgr.set_move_speed(-5.0)
	assert_true(float(settings_mgr.get_setting("controls", "move_speed")) >= 1.0, "Negative move speed clamped to >= 1.0")

	settings_mgr.set_sprint_speed(28.0)
	assert_true(float(settings_mgr.get_setting("controls", "sprint_speed")) == 28.0, "Sprint speed set to 28.0")
	settings_mgr.set_sprint_speed(-10.0)
	assert_true(float(settings_mgr.get_setting("controls", "sprint_speed")) >= 1.0, "Negative sprint speed clamped to >= 1.0")

	# 4.3 Invert Y
	settings_mgr.set_invert_y(true)
	assert_true(bool(settings_mgr.get_setting("controls", "invert_y")) == true, "Invert Y set to true")
	settings_mgr.set_invert_y(false)
	assert_false(bool(settings_mgr.get_setting("controls", "invert_y")), "Invert Y set to false")

	# 4.4 Control key bindings
	var fwd_key: int = settings_mgr.get_binding("move_forward", KEY_NONE)
	assert_true(fwd_key == KEY_W, "Default move_forward key binding is KEY_W")

	settings_mgr.set_binding("move_forward", KEY_UP, true)
	assert_true(settings_mgr.get_binding("move_forward") == KEY_UP, "Rebound move_forward to KEY_UP")

	# Verify binding persistence
	var check_bind_mgr = settings_script.new()
	root.add_child(check_bind_mgr)
	check_bind_mgr.load_settings()
	assert_true(check_bind_mgr.get_binding("move_forward") == KEY_UP, "Custom key binding persisted across load")
	check_bind_mgr.queue_free()

	# Restore default binding
	settings_mgr.set_binding("move_forward", KEY_W, true)
	assert_true(settings_mgr.get_binding("move_forward") == KEY_W, "Restored move_forward to KEY_W")

	# 4.5 Avatar locomotion sensitivity scaling verification
	var avatar_script = load("res://modules/builtin/avatar_locomotion.gd")
	assert_true(avatar_script != null, "avatar_locomotion.gd loads")
	var avatar_inst = avatar_script.new()
	root.add_child(avatar_inst)
	avatar_inst.initialize({"event_bus": event_bus})

	settings_mgr.set_mouse_sensitivity(0.002)
	assert_approx_equal(avatar_inst.mouse_sensitivity, 0.002, 0.0001, "AvatarLocomotion receives 0.002 sensitivity via EventBus")

	settings_mgr.set_mouse_sensitivity(0.006)
	assert_approx_equal(avatar_inst.mouse_sensitivity, 0.006, 0.0001, "AvatarLocomotion receives scaled 0.006 sensitivity via EventBus")

	# Verify camera angular rotation scaling
	var motion_event := InputEventMouseMotion.new()
	motion_event.relative = Vector2(100.0, 50.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Test rotation with sens 0.002
	avatar_inst.mouse_sensitivity = 0.002
	var yaw_before: float = float(avatar_inst.yaw_node.rotation.y)
	avatar_inst._unhandled_input(motion_event)
	var delta_rot_1: float = absf(float(avatar_inst.yaw_node.rotation.y) - yaw_before)

	# Test rotation with sens 0.004 (should be exactly 2x)
	avatar_inst.mouse_sensitivity = 0.004
	yaw_before = float(avatar_inst.yaw_node.rotation.y)
	avatar_inst._unhandled_input(motion_event)
	var delta_rot_2: float = absf(float(avatar_inst.yaw_node.rotation.y) - yaw_before)

	assert_approx_equal(delta_rot_2, delta_rot_1 * 2.0, 0.001, "Mouse sensitivity scaling doubles angular camera rotation proportionally")

	avatar_inst.cleanup()
	avatar_inst.queue_free()

	# ------------------------------------------------------------------
	# GROUP 5: Live UI & Space Viewport F11 Input Handling
	# ------------------------------------------------------------------
	print("\n--- GROUP 5: Live UI & Space Viewport F11 Input Handling ---")

	var vp_scene = load("res://core/space_viewport.tscn")
	assert_true(vp_scene != null, "space_viewport.tscn loads")
	var vp_inst = vp_scene.instantiate()
	root.add_child(vp_inst)

	# 5.1 TopBar fullscreen button state
	var topbar = vp_inst.top_bar
	assert_true(topbar != null, "TopBar exists in viewport scene")
	assert_true(topbar.fullscreen_btn.text == "ЭКРАН [F11]", "TopBar shows 'ЭКРАН [F11]' when windowed")

	# 5.2 Simulate pressing F11 via InputEventKey
	var f11_press := InputEventKey.new()
	f11_press.keycode = KEY_F11
	f11_press.pressed = true
	f11_press.echo = false

	# Dispatch to viewport
	vp_inst._input(f11_press)
	assert_true(bool(vp_inst.settings_manager.get_setting("display", "fullscreen")) == true, "F11 _input toggled fullscreen to true")
	assert_true(topbar.fullscreen_btn.text == "ОКНО [F11]", "TopBar button text updated to 'ОКНО [F11]'")

	# Press F11 again to return to windowed mode
	vp_inst._input(f11_press)
	assert_false(bool(vp_inst.settings_manager.get_setting("display", "fullscreen")), "F11 _input toggled fullscreen back to false")
	assert_true(topbar.fullscreen_btn.text == "ЭКРАН [F11]", "TopBar button text returned to 'ЭКРАН [F11]'")

	# 5.3 Echo press should NOT toggle
	var f11_echo := InputEventKey.new()
	f11_echo.keycode = KEY_F11
	f11_echo.pressed = true
	f11_echo.echo = true
	vp_inst._input(f11_echo)
	assert_false(bool(vp_inst.settings_manager.get_setting("display", "fullscreen")), "F11 echo event ignored without toggling")

	# 5.4 MainMenu UI synchronization
	var main_menu = vp_inst.main_menu
	main_menu.open("settings")
	assert_true(main_menu.is_open, "MainMenu opened")
	assert_false(main_menu.fullscreen_check.button_pressed, "MainMenu fullscreen checkbox is unchecked initially")

	# Toggle fullscreen while MainMenu is open
	vp_inst._input(f11_press)
	assert_true(main_menu.fullscreen_check.button_pressed, "MainMenu fullscreen checkbox dynamically checked via F11")

	# Toggle off while MainMenu is open
	vp_inst._input(f11_press)
	assert_false(main_menu.fullscreen_check.button_pressed, "MainMenu fullscreen checkbox dynamically unchecked via F11")

	main_menu.close()
	assert_false(main_menu.is_open, "MainMenu closed cleanly")

	# Clean up
	vp_inst.queue_free()
	settings_mgr.queue_free()
	event_bus.queue_free()

	print("\n==================================================================")
	print("Subagent Alpha Validation Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================================")

	if failed_count == 0:
		quit(0)
	else:
		quit(1)
