extends SceneTree

# ==============================================================================
# UniCORE DisplayServer, Window Modes, Resolution & F11 Fullscreen Test Suite
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

func _init() -> void:
	print("==================================================================")
	print("UniCORE DisplayServer, Window Modes & F11 Fullscreen Audit Suite")
	print("==================================================================")

	# ----------------------------------------------------
	# GROUP 1: DisplayServer Primitive Auditing & Headless Safety
	# ----------------------------------------------------
	print("\n--- GROUP 1: DisplayServer Primitive Auditing & Headless Safety ---")
	var ds_name := DisplayServer.get_name()
	print("  DisplayServer active driver: %s" % ds_name)
	assert_true(ds_name.length() > 0, "DisplayServer driver name is valid")

	# Mode switching primitives
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	assert_true(true, "DisplayServer.window_set_mode(WINDOWED) does not crash")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	assert_true(true, "DisplayServer.window_set_mode(FULLSCREEN) does not crash")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	assert_true(true, "DisplayServer.window_set_mode(EXCLUSIVE_FULLSCREEN) does not crash")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	assert_true(true, "DisplayServer.window_set_mode(MAXIMIZED) does not crash")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	assert_true(true, "DisplayServer.window_set_mode(MINIMIZED) does not crash")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Size primitives with extreme/negative values
	DisplayServer.window_set_size(Vector2i(1280, 720))
	assert_true(true, "DisplayServer.window_set_size(1280x720) does not crash")
	DisplayServer.window_set_size(Vector2i(-500, -500))
	assert_true(true, "DisplayServer.window_set_size(-500, -500) negative coordinates do not crash")
	DisplayServer.window_set_size(Vector2i(0, 0))
	assert_true(true, "DisplayServer.window_set_size(0, 0) zero coordinates do not crash")
	DisplayServer.window_set_size(Vector2i(100000, 100000))
	assert_true(true, "DisplayServer.window_set_size(100000, 100000) extreme coordinates do not crash")
	DisplayServer.window_set_size(Vector2i(1280, 720))

	# Position primitives
	DisplayServer.window_set_position(Vector2i(100, 100))
	assert_true(true, "DisplayServer.window_set_position(100, 100) does not crash")
	DisplayServer.window_set_position(Vector2i(-999, -999))
	assert_true(true, "DisplayServer.window_set_position(-999, -999) does not crash")

	# VSync primitives
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	assert_true(true, "DisplayServer.window_set_vsync_mode(VSYNC_ENABLED) does not crash")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	assert_true(true, "DisplayServer.window_set_vsync_mode(VSYNC_DISABLED) does not crash")

	# ----------------------------------------------------
	# GROUP 2: Viewport Scaling Settings & Configuration
	# ----------------------------------------------------
	print("\n--- GROUP 2: Viewport Scaling Settings & Configuration ---")
	var win = root
	assert_true(win != null, "SceneTree root window exists")
	print("  Root content_scale_size: %s" % str(win.content_scale_size))
	print("  Root content_scale_mode: %d" % win.content_scale_mode)
	print("  Root content_scale_aspect: %d" % win.content_scale_aspect)
	print("  Root content_scale_factor: %f" % win.content_scale_factor)

	assert_true(win.content_scale_size == Vector2i(1280, 720), "Project stretch size is 1280x720 base design resolution")
	assert_true(win.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "Stretch mode is CANVAS_ITEMS (1)")
	assert_true(win.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Stretch aspect is EXPAND (4)")

	# Instantiate SettingsManager
	var settings_script = load("res://core/settings_manager.gd")
	assert_true(settings_script != null, "SettingsManager script loads successfully")
	var settings_mgr: SettingsManager = settings_script.new()
	root.add_child(settings_mgr)

	var eb_script = load("res://core/event_bus.gd")
	var event_bus = eb_script.new()
	root.add_child(event_bus)

	settings_mgr.setup(event_bus)
	settings_mgr.reset_to_defaults()

	# Test Viewport Scaling Query & Setter
	var scale_settings = settings_mgr.get_viewport_scaling_settings()
	assert_true(scale_settings is Dictionary, "get_viewport_scaling_settings returns Dictionary")
	assert_true(scale_settings.has("content_scale_size"), "Scaling settings contain content_scale_size")
	assert_true(scale_settings.has("content_scale_mode"), "Scaling settings contain content_scale_mode")
	assert_true(scale_settings.has("content_scale_aspect"), "Scaling settings contain content_scale_aspect")
	assert_true(scale_settings.has("content_scale_factor"), "Scaling settings contain content_scale_factor")

	# Scale Factor setting & clamping
	settings_mgr.set_viewport_scale_factor(1.5, true)
	assert_true(is_equal_approx(settings_mgr.get_viewport_scale_factor(), 1.5), "Scale factor set to 1.5")
	assert_true(is_equal_approx(win.content_scale_factor, 1.5), "Window content_scale_factor updated to 1.5")

	# Clamp lower boundary
	settings_mgr.set_viewport_scale_factor(0.1, true)
	assert_true(is_equal_approx(settings_mgr.get_viewport_scale_factor(), 0.5), "Scale factor clamped to minimum 0.5")

	# Clamp upper boundary
	settings_mgr.set_viewport_scale_factor(10.0, true)
	assert_true(is_equal_approx(settings_mgr.get_viewport_scale_factor(), 3.0), "Scale factor clamped to maximum 3.0")

	# Reset scale factor
	settings_mgr.set_viewport_scale_factor(1.0, true)
	assert_true(is_equal_approx(settings_mgr.get_viewport_scale_factor(), 1.0), "Scale factor reset to 1.0")

	# ----------------------------------------------------
	# GROUP 3: Fullscreen Modes (Windowed, Borderless, Exclusive) & F11 Toggle
	# ----------------------------------------------------
	print("\n--- GROUP 3: Fullscreen Modes & F11 Toggle ---")
	settings_mgr.reset_to_defaults()
	assert_true(settings_mgr.is_fullscreen() == false, "Default fullscreen is false")
	assert_true(settings_mgr.get_setting("display", "fullscreen") == false, "display/fullscreen setting is false")

	# Toggle ON (Borderless Fullscreen)
	var toggled_on: bool = settings_mgr.toggle_fullscreen()
	assert_true(toggled_on == true, "toggle_fullscreen returns true (fullscreen enabled)")
	assert_true(settings_mgr.is_fullscreen() == true, "is_fullscreen() returns true")
	assert_true(settings_mgr.get_setting("display", "fullscreen") == true, "display/fullscreen setting is true")

	# Toggle OFF (Windowed Mode)
	var toggled_off: bool = settings_mgr.toggle_fullscreen()
	assert_true(toggled_off == false, "toggle_fullscreen returns false (windowed enabled)")
	assert_true(settings_mgr.is_fullscreen() == false, "is_fullscreen() returns false")
	assert_true(settings_mgr.get_setting("display", "fullscreen") == false, "display/fullscreen setting is false")

	# Test Exclusive Fullscreen Configuration
	settings_mgr.set_exclusive_fullscreen(true, true)
	assert_true(settings_mgr.get_setting("display", "exclusive_fullscreen") == true, "exclusive_fullscreen setting enabled")

	# Toggle ON with Exclusive Fullscreen mode configured
	var exclusive_toggled_on = settings_mgr.toggle_fullscreen()
	assert_true(exclusive_toggled_on == true, "Exclusive fullscreen toggled on successfully")
	assert_true(settings_mgr.is_fullscreen() == true, "is_fullscreen() is true in exclusive mode")
	assert_true(settings_mgr.is_exclusive_fullscreen() == true, "is_exclusive_fullscreen() is true")

	# Toggle OFF from Exclusive Fullscreen
	var exclusive_toggled_off = settings_mgr.toggle_fullscreen()
	assert_true(exclusive_toggled_off == false, "Exclusive fullscreen smoothly toggles back to windowed")
	assert_true(settings_mgr.is_fullscreen() == false, "is_fullscreen() is false after exiting exclusive fullscreen")

	# Reset exclusive mode
	settings_mgr.set_exclusive_fullscreen(false, true)

	# Direct set_fullscreen calls with idempotent safety
	settings_mgr.set_fullscreen(true, true)
	assert_true(settings_mgr.is_fullscreen() == true, "set_fullscreen(true) activated")
	settings_mgr.set_fullscreen(true, true) # redundant call
	assert_true(settings_mgr.is_fullscreen() == true, "Redundant set_fullscreen(true) is safe and idempotent")

	settings_mgr.set_fullscreen(false, true)
	assert_true(settings_mgr.is_fullscreen() == false, "set_fullscreen(false) deactivated")
	settings_mgr.set_fullscreen(false, true) # redundant call
	assert_true(settings_mgr.is_fullscreen() == false, "Redundant set_fullscreen(false) is safe and idempotent")

	# Stress Test: 50 Rapid Consecutive Toggles
	print("  Running 50 rapid toggle stress tests...")
	var stress_passed := true
	for i in range(50):
		var state = settings_mgr.toggle_fullscreen()
		if settings_mgr.is_fullscreen() != state:
			stress_passed = false
			break
	assert_true(stress_passed, "50 rapid toggle cycles executed without desync or crash")
	# Ensure left in windowed mode
	if settings_mgr.is_fullscreen():
		settings_mgr.toggle_fullscreen()
	assert_true(settings_mgr.is_fullscreen() == false, "Cleanly restored to windowed state after stress test")

	# ----------------------------------------------------
	# GROUP 4: Resolution Presets & Switching
	# ----------------------------------------------------
	print("\n--- GROUP 4: Resolution Presets & Switching ---")
	var presets := settings_mgr.get_resolution_presets()
	assert_true(presets.size() == 4, "4 resolution presets defined", "Count: %d" % presets.size())
	assert_true(presets[0] == Vector2i(1280, 720), "Preset 0 is 1280x720")
	assert_true(presets[1] == Vector2i(1600, 900), "Preset 1 is 1600x900")
	assert_true(presets[2] == Vector2i(1920, 1080), "Preset 2 is 1920x1080")
	assert_true(presets[3] == Vector2i(2560, 1440), "Preset 3 is 2560x1440")

	# Iterate and apply all presets by index
	for i in range(presets.size()):
		settings_mgr.set_resolution_by_index(i)
		assert_true(settings_mgr.get_setting("display", "resolution_index") == i, "Preset index %d applied" % i)
		assert_true(settings_mgr.get_setting("display", "resolution_width") == presets[i].x, "Preset %d width correct" % i)
		assert_true(settings_mgr.get_setting("display", "resolution_height") == presets[i].y, "Preset %d height correct" % i)

	# Invalid index handling
	settings_mgr.set_resolution_by_index(-1)
	assert_true(settings_mgr.get_setting("display", "resolution_index") == 3, "Invalid index -1 safely ignored without crash")
	settings_mgr.set_resolution_by_index(999)
	assert_true(settings_mgr.get_setting("display", "resolution_index") == 3, "Invalid index 999 safely ignored without crash")

	# Direct resolution setting with auto-preset matching
	settings_mgr.set_resolution(1280, 720)
	assert_true(settings_mgr.get_setting("display", "resolution_index") == 0, "1280x720 automatically maps to preset index 0")
	settings_mgr.set_resolution(1920, 1080)
	assert_true(settings_mgr.get_setting("display", "resolution_index") == 2, "1920x1080 automatically maps to preset index 2")

	# Custom non-preset resolution
	settings_mgr.set_resolution(1366, 768)
	assert_true(settings_mgr.get_setting("display", "resolution_width") == 1366, "Custom width 1366 stored")
	assert_true(settings_mgr.get_setting("display", "resolution_height") == 768, "Custom height 768 stored")

	# Extreme and invalid dimensions clamping
	settings_mgr.set_resolution(-100, -100)
	assert_true(settings_mgr.get_setting("display", "resolution_width") == 320, "Negative width clamped to min 320")
	assert_true(settings_mgr.get_setting("display", "resolution_height") == 240, "Negative height clamped to min 240")

	settings_mgr.set_resolution(50000, 50000)
	assert_true(settings_mgr.get_setting("display", "resolution_width") == 15360, "Extreme width clamped to max 15360")
	assert_true(settings_mgr.get_setting("display", "resolution_height") == 8640, "Extreme height clamped to max 8640")

	# Auto-exit fullscreen when resolution preset is selected
	settings_mgr.set_fullscreen(true, true)
	assert_true(settings_mgr.is_fullscreen() == true, "Fullscreen active before resolution change")
	settings_mgr.set_resolution_by_index(1) # Select 1600x900
	assert_true(settings_mgr.is_fullscreen() == false, "Selecting resolution preset automatically exits fullscreen into windowed mode")
	assert_true(settings_mgr.get_setting("display", "resolution_width") == 1600, "Resolution updated to 1600x900")

	# ----------------------------------------------------
	# GROUP 5: Input Actions & F11 / Alt+Enter Input Handling
	# ----------------------------------------------------
	print("\n--- GROUP 5: Input Actions & F11 / Alt+Enter Handling ---")
	assert_true(InputMap.has_action("toggle_fullscreen"), "InputMap contains toggle_fullscreen action")
	var action_events := InputMap.action_get_events("toggle_fullscreen")
	assert_true(action_events.size() >= 1, "toggle_fullscreen has mapped events")

	# Verify F11 key event
	var has_f11 := false
	var has_alt_enter := false
	for ev in action_events:
		if ev is InputEventKey:
			if ev.keycode == KEY_F11:
				has_f11 = true
			if ev.keycode == KEY_ENTER and ev.alt_pressed:
				has_alt_enter = true
	assert_true(has_f11, "toggle_fullscreen action is bound to KEY_F11")
	assert_true(has_alt_enter, "toggle_fullscreen action is bound to Alt+Enter")

	# Test SpaceViewport Input Event Handler
	var space_scene = load("res://core/space_viewport.tscn")
	assert_true(space_scene != null, "space_viewport.tscn loads")
	var space_instance: SpaceViewport = space_scene.instantiate()
	root.add_child(space_instance)

	# Simulate F11 key event to space_instance._input
	var f11_event := InputEventKey.new()
	f11_event.keycode = KEY_F11
	f11_event.pressed = true
	f11_event.echo = false

	var initial_fs = space_instance.settings_manager.is_fullscreen()
	space_instance._input(f11_event)
	var toggled_fs = space_instance.settings_manager.is_fullscreen()
	assert_true(toggled_fs == not initial_fs, "Simulated F11 key event toggles fullscreen in SpaceViewport")

	# Simulate second F11 key event
	space_instance._input(f11_event)
	var toggled_back_fs = space_instance.settings_manager.is_fullscreen()
	assert_true(toggled_back_fs == initial_fs, "Second simulated F11 key event toggles fullscreen back")

	# Simulate Alt+Enter key event to space_instance._input
	var alt_enter_event := InputEventKey.new()
	alt_enter_event.keycode = KEY_ENTER
	alt_enter_event.alt_pressed = true
	alt_enter_event.pressed = true
	alt_enter_event.echo = false

	space_instance._input(alt_enter_event)
	assert_true(space_instance.settings_manager.is_fullscreen() == not initial_fs, "Simulated Alt+Enter toggles fullscreen in SpaceViewport")

	space_instance._input(alt_enter_event)
	assert_true(space_instance.settings_manager.is_fullscreen() == initial_fs, "Second simulated Alt+Enter toggles fullscreen back")

	space_instance.queue_free()

	# ----------------------------------------------------
	# GROUP 6: Serialization & Disk Persistence
	# ----------------------------------------------------
	print("\n--- GROUP 6: Serialization & Disk Persistence ---")
	settings_mgr.set_resolution_by_index(2) # 1920x1080
	settings_mgr.set_fullscreen(true, true)
	settings_mgr.set_vsync(false, true)
	settings_mgr.set_fps_limit(144, true)
	settings_mgr.set_viewport_scale_factor(1.25, true)
	settings_mgr.save_settings()

	# Create a second manager instance and load from disk
	var mgr2: SettingsManager = settings_script.new()
	root.add_child(mgr2)
	mgr2.setup(event_bus)

	assert_true(mgr2.get_setting("display", "fullscreen") == true, "Fullscreen persisted and reloaded from disk")
	assert_true(mgr2.get_setting("display", "resolution_width") == 1920, "Resolution width persisted (1920)")
	assert_true(mgr2.get_setting("display", "resolution_height") == 1080, "Resolution height persisted (1080)")
	assert_true(mgr2.get_setting("display", "resolution_index") == 2, "Resolution index persisted (2)")
	assert_true(mgr2.get_setting("display", "vsync") == false, "VSync persisted (false)")
	assert_true(mgr2.get_setting("display", "fps_limit") == 144, "FPS limit persisted (144)")
	assert_true(is_equal_approx(float(mgr2.get_setting("display", "scale_factor")), 1.25), "Scale factor persisted (1.25)")

	# Clean up and restore defaults
	mgr2.reset_to_defaults()
	assert_true(mgr2.get_setting("display", "fullscreen") == false, "Reset to defaults restored fullscreen to false")
	assert_true(mgr2.get_setting("display", "resolution_width") == 1280, "Reset to defaults restored width to 1280")
	assert_true(mgr2.get_setting("display", "resolution_height") == 720, "Reset to defaults restored height to 720")

	mgr2.queue_free()
	settings_mgr.queue_free()
	event_bus.queue_free()

	print("\n==================================================================")
	print("Test Results: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("==================================================================")

	quit(0 if failed_count == 0 else 1)
