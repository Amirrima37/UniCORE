extends SceneTree

# ==============================================================================
# UniCORE Automated Test Suite: Liquid Glass Theme & Interface Settings
# Verifies:
# 1. CyberTheme Liquid Glass Aesthetics (CyberLife White, Cyber Void, LED glow)
# 2. Dynamic opacity, LED intensity and style generation (Panel, Button, Input)
# 3. SettingsManager interface category, validation, signals & disk persistence
# 4. MainMenu Interface/Design UI controls and dynamic styling updates
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

func assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	if actual == expected:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - Expected '%s', got '%s'" % [test_name, str(expected), str(actual)])
		failed_count += 1

func assert_approx_equal(val: float, expected: float, tolerance: float, test_name: String) -> void:
	var diff := absf(val - expected)
	assert_true(diff <= tolerance, test_name, "Expected ~%f, got %f (diff: %f > %f)" % [expected, val, diff, tolerance])

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE Liquid Glass & Interface Settings Suite")
	print("==================================================")

	_test_cyber_theme_constants_and_aesthetics()
	_test_cyber_theme_dynamic_styles()
	_test_settings_manager_interface_category()
	_test_settings_manager_interface_persistence()
	_test_interface_signals()
	_test_main_menu_interface_controls()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("ALL TESTS PASSED SUCCESSFULLY! Quitting with code 0.")
		quit(0)
	else:
		print("SOME TESTS FAILED! Quitting with code 1.")
		quit(1)

func _test_cyber_theme_constants_and_aesthetics() -> void:
	print("\n--- 1. Testing CyberTheme Constants & Aesthetics ---")
	var theme_script = load("res://ui/theme/cyber_theme.gd")
	assert_true(theme_script != null, "cyber_theme.gd loads cleanly")

	# 1.1 Verify LED constants
	assert_true(theme_script.COLOR_CYAN_GLOW == Color(0.0, 0.9, 1.0, 1.0), "COLOR_CYAN_GLOW is neon cyan")
	assert_true(theme_script.COLOR_ELECTRIC_BLUE == Color(0.1, 0.6, 1.0, 1.0), "COLOR_ELECTRIC_BLUE is electric blue")
	assert_true(theme_script.COLOR_SUCCESS_LED == Color(0.0, 0.9, 0.45, 1.0), "COLOR_SUCCESS_LED is neon green")
	assert_true(theme_script.COLOR_AMBER_LED == Color(1.0, 0.7, 0.0, 1.0), "COLOR_AMBER_LED is neon amber")
	assert_true(theme_script.COLOR_RED_LED == Color(1.0, 0.2, 0.25, 1.0), "COLOR_RED_LED is neon red")

	# 1.2 Verify Base Colors
	assert_true(theme_script.COLOR_GLASS_CYBERLIFE_BASE == Color(0.92, 0.95, 0.99), "COLOR_GLASS_CYBERLIFE_BASE is arctic/milky white")
	assert_true(theme_script.COLOR_GLASS_VOID_BASE == Color(0.04, 0.08, 0.14), "COLOR_GLASS_VOID_BASE is deep dark void")

	# 1.3 Verify instance properties
	var inst = theme_script.new()
	assert_true(inst != null, "CyberTheme instantiates cleanly")
	assert_true(inst.theme_name is String, "CyberTheme instance has theme_name property")
	assert_true(inst.glass_opacity is float, "CyberTheme instance has glass_opacity property")
	assert_true(inst.led_intensity is float, "CyberTheme instance has led_intensity property")

func _test_cyber_theme_dynamic_styles() -> void:
	print("\n--- 2. Testing CyberTheme Dynamic Styles & LED Glow ---")
	var theme_script = load("res://ui/theme/cyber_theme.gd")

	# 2.1 CyberLife White Theme
	theme_script.apply_interface_settings({
		"theme": "cyberlife_white",
		"glass_opacity": 0.8,
		"led_intensity": 1.5
	})
	assert_true(theme_script.is_white_theme(), "CyberLife White theme active")
	assert_approx_equal(theme_script.get_glass_opacity(), 0.8, 0.001, "glass_opacity is 0.8")
	assert_approx_equal(theme_script.get_led_intensity(), 1.5, 0.001, "led_intensity is 1.5")

	var white_panel: StyleBoxFlat = theme_script.create_glass_panel_style()
	assert_true(white_panel is StyleBoxFlat, "create_glass_panel_style returns StyleBoxFlat")
	assert_true(white_panel.bg_color.r > 0.9 and white_panel.bg_color.g > 0.9, "White theme panel has light background")
	assert_approx_equal(white_panel.bg_color.a, 0.8, 0.01, "White theme panel respects glass_opacity (0.8)")
	assert_true(white_panel.shadow_size > 0, "White theme panel has LED glow shadow")
	assert_approx_equal(white_panel.shadow_size, int(round(4 * 1.5)), 0.1, "Shadow size scaled by led_intensity 1.5")

	# 2.2 Cyber Void Dark Theme
	theme_script.apply_interface_settings({
		"theme": "cyber_void",
		"glass_opacity": 0.6,
		"led_intensity": 0.75
	})
	assert_false(theme_script.is_white_theme(), "Cyber Void theme active")
	assert_approx_equal(theme_script.get_glass_opacity(), 0.6, 0.001, "glass_opacity is 0.6")
	assert_approx_equal(theme_script.get_led_intensity(), 0.75, 0.001, "led_intensity is 0.75")

	var dark_panel: StyleBoxFlat = theme_script.create_glass_panel_style()
	assert_true(dark_panel.bg_color.r < 0.1 and dark_panel.bg_color.g < 0.1, "Dark theme panel has dark background")
	assert_approx_equal(dark_panel.bg_color.a, 0.6, 0.01, "Dark theme panel respects glass_opacity (0.6)")
	assert_approx_equal(dark_panel.shadow_size, int(round(4 * 0.75)), 0.1, "Shadow size scaled by led_intensity 0.75")

	# 2.3 Custom parameters in create_glass_panel_style
	var custom_panel: StyleBoxFlat = theme_script.create_glass_panel_style(
		theme_script.COLOR_CYAN_GLOW,
		Color(0.1, 0.2, 0.3, 0.5),
		2,
		8,
		10,
		Color(0.0, 1.0, 0.5, 0.8)
	)
	assert_true(custom_panel.border_color == theme_script.COLOR_CYAN_GLOW, "Custom accent border applied")
	assert_true(custom_panel.bg_color == Color(0.1, 0.2, 0.3, 0.5), "Custom bg_color applied")
	assert_true(custom_panel.border_width_left == 2, "Custom border_width applied")
	assert_true(custom_panel.corner_radius_top_left == 8, "Custom corner_radius applied")
	assert_true(custom_panel.shadow_color == Color(0.0, 1.0, 0.5, 0.8), "Custom shadow_color applied")

	# 2.4 Button & Input Styles
	var btn_style: StyleBoxFlat = theme_script.create_cyber_button_style()
	assert_true(btn_style is StyleBoxFlat, "create_cyber_button_style returns StyleBoxFlat")
	var input_style: StyleBoxFlat = theme_script.create_input_style(false)
	assert_true(input_style is StyleBoxFlat, "create_input_style unfocused returns StyleBoxFlat")
	var input_focused: StyleBoxFlat = theme_script.create_input_style(true)
	assert_true(input_focused is StyleBoxFlat, "create_input_style focused returns StyleBoxFlat")
	assert_true(input_focused.shadow_size > 0, "Focused input style has LED glow")

	# 2.5 Full Theme Construction
	var full_theme: Theme = theme_script.build_theme()
	assert_true(full_theme is Theme, "build_theme returns valid Theme")
	assert_true(full_theme.has_stylebox("panel", "PanelContainer"), "Theme has PanelContainer style")
	assert_true(full_theme.has_stylebox("normal", "Button"), "Theme has Button normal style")
	assert_true(full_theme.has_stylebox("hover", "Button"), "Theme has Button hover style")
	assert_true(full_theme.has_stylebox("normal", "LineEdit"), "Theme has LineEdit style")
	assert_true(full_theme.has_stylebox("panel", "TabContainer"), "Theme has TabContainer style")

	# Reset to default white theme
	theme_script.apply_interface_settings({
		"theme": "cyberlife_white",
		"glass_opacity": 0.75,
		"led_intensity": 1.0
	})
	assert_true(theme_script.is_white_theme(), "Reset to cyberlife_white")

func _test_settings_manager_interface_category() -> void:
	print("\n--- 3. Testing SettingsManager Interface Category & Sanitization ---")
	var sm_script = load("res://core/settings_manager.gd")
	var sm: SettingsManager = sm_script.new()
	root.add_child(sm)
	sm.setup(null)

	# 3.1 Defaults
	var iface: Dictionary = sm.get_interface_settings()
	assert_true(iface.has("theme"), "Settings has interface.theme")
	assert_true(iface.has("glass_opacity"), "Settings has interface.glass_opacity")
	assert_true(iface.has("led_intensity"), "Settings has interface.led_intensity")
	assert_true(iface.has("prompt_bar_autoclose"), "Settings has interface.prompt_bar_autoclose")

	# 3.2 Clamping & Sanitization
	sm.set_glass_opacity(0.05) # below 0.2
	assert_approx_equal(float(sm.get_setting("interface", "glass_opacity")), 0.2, 0.01, "glass_opacity clamped to minimum 0.2")

	sm.set_glass_opacity(1.5) # above 0.95
	assert_approx_equal(float(sm.get_setting("interface", "glass_opacity")), 0.95, 0.01, "glass_opacity clamped to maximum 0.95")

	sm.set_led_intensity(0.1) # below 0.5
	assert_approx_equal(float(sm.get_setting("interface", "led_intensity")), 0.5, 0.01, "led_intensity clamped to minimum 0.5")

	sm.set_led_intensity(3.0) # above 2.0
	assert_approx_equal(float(sm.get_setting("interface", "led_intensity")), 2.0, 0.01, "led_intensity clamped to maximum 2.0")

	sm.set_interface_theme("invalid_theme_name")
	var current_theme: String = sm.get_setting("interface", "theme")
	assert_true(current_theme == "cyberlife_white" or current_theme == "cyber_void", "Invalid theme rejected, keeps valid theme")

	sm.queue_free()

func _test_settings_manager_interface_persistence() -> void:
	print("\n--- 4. Testing SettingsManager Disk Persistence (user://settings.json) ---")
	var sm_script = load("res://core/settings_manager.gd")

	# Instance 1: write modified settings
	var sm1: SettingsManager = sm_script.new()
	root.add_child(sm1)
	sm1.setup(null)

	sm1.set_interface_theme("cyber_void")
	sm1.set_glass_opacity(0.82)
	sm1.set_led_intensity(1.4)
	sm1.set_prompt_bar_autoclose(false)
	var save_ok: bool = sm1.save_settings()
	assert_true(save_ok, "save_settings returns true")

	# Verify file on disk directly
	var file_path := "user://settings.json"
	assert_true(FileAccess.file_exists(file_path), "user://settings.json exists on disk")

	var f := FileAccess.open(file_path, FileAccess.READ)
	assert_true(f != null, "user://settings.json can be opened for reading")
	var raw_text := f.get_as_text()
	f.close()

	var json := JSON.new()
	var err := json.parse(raw_text)
	assert_true(err == OK, "user://settings.json parses as valid JSON")
	var data = json.get_data()
	assert_true(data is Dictionary, "JSON root is Dictionary")
	assert_true(data.has("interface"), "JSON contains 'interface' section")
	assert_eq(data["interface"]["theme"], "cyber_void", "Disk JSON has theme 'cyber_void'")
	assert_approx_equal(float(data["interface"]["glass_opacity"]), 0.82, 0.01, "Disk JSON has glass_opacity 0.82")
	assert_approx_equal(float(data["interface"]["led_intensity"]), 1.4, 0.01, "Disk JSON has led_intensity 1.4")
	assert_false(bool(data["interface"]["prompt_bar_autoclose"]), "Disk JSON has prompt_bar_autoclose false")

	sm1.queue_free()

	# Instance 2: reload fresh from disk
	var sm2: SettingsManager = sm_script.new()
	root.add_child(sm2)
	sm2.setup(null)

	assert_eq(sm2.get_setting("interface", "theme"), "cyber_void", "Reloaded theme is cyber_void")
	assert_approx_equal(float(sm2.get_setting("interface", "glass_opacity")), 0.82, 0.01, "Reloaded glass_opacity is 0.82")
	assert_approx_equal(float(sm2.get_setting("interface", "led_intensity")), 1.4, 0.01, "Reloaded led_intensity is 1.4")
	assert_false(bool(sm2.get_setting("interface", "prompt_bar_autoclose")), "Reloaded prompt_bar_autoclose is false")

	# Restore to default cyberlife_white for clean workspace
	sm2.set_interface_theme("cyberlife_white")
	sm2.set_glass_opacity(0.75)
	sm2.set_led_intensity(1.0)
	sm2.set_prompt_bar_autoclose(true)
	sm2.save_settings()

	sm2.queue_free()

func _test_interface_signals() -> void:
	print("\n--- 5. Testing Interface Signals (EventBus & SettingsManager) ---")
	var sm: SettingsManager = SettingsManager.new()
	var eb: EventBus = EventBus.new()
	root.add_child(sm)
	root.add_child(eb)
	sm.setup(eb)

	var eb_events: Array[Dictionary] = []
	eb.subscribe("interface_settings_changed", func(payload):
		eb_events.append(payload)
	)

	var sm_events: Array[Dictionary] = []
	sm.interface_settings_changed.connect(func(settings):
		sm_events.append(settings)
	)

	sm.set_glass_opacity(0.9)

	assert_true(eb_events.size() > 0, "EventBus received 'interface_settings_changed'")
	assert_true(sm_events.size() > 0, "SettingsManager emitted 'interface_settings_changed'")

	var last_eb: Dictionary = eb_events[eb_events.size() - 1]
	assert_approx_equal(float(last_eb.get("glass_opacity", 0.0)), 0.9, 0.01, "EventBus payload contains glass_opacity 0.9")

	var last_sm: Dictionary = sm_events[sm_events.size() - 1]
	assert_approx_equal(float(last_sm.get("glass_opacity", 0.0)), 0.9, 0.01, "SettingsManager payload contains glass_opacity 0.9")

	sm.queue_free()
	eb.queue_free()

func _test_main_menu_interface_controls() -> void:
	print("\n--- 6. Testing MainMenu Interface Settings Controls ---")
	var menu_scene = load("res://ui/menu/main_menu.tscn")
	assert_true(menu_scene != null, "main_menu.tscn loads successfully")

	var menu: MainMenu = menu_scene.instantiate()
	root.add_child(menu)

	var sm: SettingsManager = SettingsManager.new()
	var eb: EventBus = EventBus.new()
	var mm: ModuleManager = ModuleManager.new()
	var spm: SpaceManager = SpaceManager.new()
	root.add_child(sm)
	root.add_child(eb)
	root.add_child(mm)
	root.add_child(spm)

	sm.setup(eb)
	menu.setup(sm, spm, mm, eb)

	menu.open("settings")
	assert_true(menu.is_open, "Main menu opened on settings tab")

	# 6.1 Check node references exist
	assert_true(menu.interface_theme_opt != null, "menu.interface_theme_opt exists")
	assert_true(menu.glass_opacity_slider != null, "menu.glass_opacity_slider exists")
	assert_true(menu.glass_opacity_val_label != null, "menu.glass_opacity_val_label exists")
	assert_true(menu.led_intensity_slider != null, "menu.led_intensity_slider exists")
	assert_true(menu.led_intensity_val_label != null, "menu.led_intensity_val_label exists")
	assert_true(menu.prompt_autoclose_check != null, "menu.prompt_autoclose_check exists")

	# 6.2 Test slider interactions
	menu.glass_opacity_slider.value = 0.88
	assert_eq(menu.glass_opacity_val_label.text, "88%", "Opacity slider updates percentage label to 88%")
	assert_approx_equal(float(sm.get_setting("interface", "glass_opacity")), 0.88, 0.01, "SettingsManager received 0.88 opacity")

	menu.led_intensity_slider.value = 1.75
	assert_eq(menu.led_intensity_val_label.text, "175%", "LED slider updates percentage label to 175%")
	assert_approx_equal(float(sm.get_setting("interface", "led_intensity")), 1.75, 0.01, "SettingsManager received 1.75 LED intensity")

	menu.prompt_autoclose_check.button_pressed = false
	assert_false(bool(sm.get_setting("interface", "prompt_bar_autoclose")), "SettingsManager received prompt_bar_autoclose false")

	# 6.3 Test theme option selection
	menu.interface_theme_opt.selected = 1
	menu.interface_theme_opt.item_selected.emit(1)
	assert_eq(sm.get_setting("interface", "theme"), "cyber_void", "Theme option updates setting to cyber_void")

	menu.interface_theme_opt.selected = 0
	menu.interface_theme_opt.item_selected.emit(0)
	assert_eq(sm.get_setting("interface", "theme"), "cyberlife_white", "Theme option updates setting back to cyberlife_white")

	# 6.4 Clean Close
	menu.close()
	assert_false(menu.is_open, "Main menu closed cleanly")

	menu.queue_free()
	sm.queue_free()
	eb.queue_free()
	mm.queue_free()
	spm.queue_free()
