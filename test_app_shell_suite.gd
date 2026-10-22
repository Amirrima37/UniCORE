extends SceneTree

# Automated Test Suite for UniCORE App Shell, Settings, Space Management, and UI

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
	print("==================================================")
	print("Starting UniCORE Phase 2 App Shell & Space Test Suite")
	print("==================================================")

	# ----------------------------------------------------
	# Group 1: CyberTheme & Detroit Aesthetics
	# ----------------------------------------------------
	print("\n--- Testing CyberTheme & Styling ---")
	var theme_script = load("res://ui/theme/cyber_theme.gd")
	assert_true(theme_script != null, "CyberTheme script loads")

	var glass_style = theme_script.create_glass_panel_style()
	assert_true(glass_style is StyleBoxFlat, "create_glass_panel_style returns StyleBoxFlat")
	assert_true(glass_style.border_width_left == 1, "glass panel border width is 1")

	var btn_style = theme_script.create_cyber_button_style(Color.BLACK, Color.WHITE)
	assert_true(btn_style is StyleBoxFlat, "create_cyber_button_style returns StyleBoxFlat")

	var input_style = theme_script.create_input_style(true)
	assert_true(input_style is StyleBoxFlat, "create_input_style returns StyleBoxFlat")

	var cyber_theme = theme_script.build_theme()
	assert_true(cyber_theme is Theme, "build_theme returns valid Theme")

	# ----------------------------------------------------
	# Group 2: DetroitOrb LED Indicator
	# ----------------------------------------------------
	print("\n--- Testing DetroitOrb LED Indicator ---")
	var orb_scene = load("res://ui/led_indicator/detroit_orb.tscn")
	assert_true(orb_scene != null, "detroit_orb.tscn loads")

	var orb_inst = orb_scene.instantiate()
	assert_true(orb_inst != null, "detroit_orb instantiates")
	root.add_child(orb_inst)

	orb_inst.set_idle()
	assert_true(orb_inst.current_state == orb_inst.State.IDLE, "Orb idle state")

	orb_inst.set_processing("Test processing")
	assert_true(orb_inst.current_state == orb_inst.State.PROCESSING, "Orb processing state")

	orb_inst.flash_success("Test success", 1.0)
	assert_true(orb_inst.current_state == orb_inst.State.SUCCESS, "Orb success state")

	orb_inst.flash_error("Test error", 1.0)
	assert_true(orb_inst.current_state == orb_inst.State.ERROR, "Orb error state")

	orb_inst.queue_free()

	# ----------------------------------------------------
	# Group 3: SettingsManager Persistence & Display Modes
	# ----------------------------------------------------
	print("\n--- Testing SettingsManager ---")
	var settings_script = load("res://core/settings_manager.gd")
	assert_true(settings_script != null, "settings_manager.gd loads")

	var settings_mgr = settings_script.new()
	root.add_child(settings_mgr)

	var eb_script = load("res://core/event_bus.gd")
	var event_bus = eb_script.new()
	root.add_child(event_bus)

	settings_mgr.setup(event_bus)
	settings_mgr.reset_to_defaults()

	# Verify default values
	var def_fs = settings_mgr.get_setting("display", "fullscreen")
	assert_true(def_fs == false, "display/fullscreen default is false")

	var def_sens = settings_mgr.get_setting("controls", "mouse_sensitivity")
	assert_true(def_sens == 0.002, "default mouse_sensitivity is 0.002")

	# Test modifying setting and persistence
	settings_mgr.set_setting("controls", "mouse_sensitivity", 0.0045, true)
	assert_true(settings_mgr.get_setting("controls", "mouse_sensitivity") == 0.0045, "mouse_sensitivity updated")

	# Test resolution presets
	assert_true(settings_mgr.RESOLUTION_PRESETS.size() >= 4, "Resolution presets exist")
	settings_mgr.set_resolution_by_index(0)
	assert_true(settings_mgr.get_setting("display", "resolution_width") == 1280, "Resolution preset 0 width is 1280")

	# Test toggle fullscreen function
	var toggled_mode = settings_mgr.toggle_fullscreen()
	assert_true(toggled_mode == true, "Fullscreen toggled on")
	var toggled_back = settings_mgr.toggle_fullscreen()
	assert_true(toggled_back == false, "Fullscreen toggled back off")

	# Test agent config
	settings_mgr.set_agent_config("openrouter", "google/gemini-2.5-flash", "test_key_123")
	assert_true(settings_mgr.get_setting("agent", "provider") == "openrouter", "Agent provider updated")
	assert_true(settings_mgr.get_setting("agent", "api_key") == "test_key_123", "Agent api key stored")

	# Reload from disk
	settings_mgr.load_settings()
	assert_true(settings_mgr.get_setting("controls", "mouse_sensitivity") == 0.0045, "Settings persisted and reloaded from disk")

	# ----------------------------------------------------
	# Group 4: SpaceManager Lifecycle & Serialization
	# ----------------------------------------------------
	print("\n--- Testing SpaceManager & Spaces ---")
	var mod_mgr_script = load("res://core/module_manager.gd")
	var mod_mgr = mod_mgr_script.new()
	root.add_child(mod_mgr)

	var world_root = Node3D.new()
	root.add_child(world_root)
	mod_mgr.setup(event_bus, world_root)

	var space_mgr_script = load("res://core/space_manager.gd")
	assert_true(space_mgr_script != null, "space_manager.gd loads")

	var space_mgr = space_mgr_script.new()
	root.add_child(space_mgr)
	space_mgr.setup(mod_mgr, event_bus, world_root, null)

	# List spaces
	var spaces_list = space_mgr.list_spaces()
	assert_true(spaces_list.size() >= 1, "Default spaces exist", "Spaces count: %d" % spaces_list.size())

	# Create a new space from template
	var test_space_name = "Unit Test Cyber Space"
	var new_space_data = space_mgr.create_new_space(test_space_name, "cyber_void")
	assert_true(new_space_data.get("name") == test_space_name, "create_new_space creates correct space name")
	assert_true(space_mgr.current_space_name == test_space_name, "current_space_name updated to new space")

	# Save current space as
	var copy_name = "Unit Test Cyber Space Copy"
	var saved_ok = space_mgr.save_space_as(copy_name)
	assert_true(saved_ok, "save_space_as returns true")
	assert_true(space_mgr.current_space_name == copy_name, "current_space_name updated to copy")

	# Verify it appears in spaces list
	var updated_list = space_mgr.list_spaces()
	var found_copy = false
	var copy_id = ""
	for s in updated_list:
		if s.get("name") == copy_name:
			found_copy = true
			copy_id = s.get("id")
			break
	assert_true(found_copy, "Saved copy found in space list")

	# Delete spaces created in test
	if not copy_id.is_empty():
		var deleted = space_mgr.delete_space(copy_id)
		assert_true(deleted, "delete_space successfully removes space copy")

	if new_space_data.has("id"):
		var orig_deleted = space_mgr.delete_space(new_space_data["id"])
		assert_true(orig_deleted, "delete_space cleanly removes original test space")

	# ----------------------------------------------------
	# Group 5: TopBar, MainMenu, and PromptBar Verification
	# ----------------------------------------------------
	print("\n--- Testing TopBar HUD & MainMenu ---")
	var topbar_scene = load("res://ui/hud/top_bar.tscn")
	assert_true(topbar_scene != null, "top_bar.tscn loads")
	var topbar_inst = topbar_scene.instantiate()
	root.add_child(topbar_inst)
	topbar_inst._ready()
	topbar_inst.setup(settings_mgr, space_mgr, null, event_bus)
	# Test TopBar LOG button
	assert_true(topbar_inst.log_btn != null, "TopBar has log_btn [F10]")
	var log_btn_signalled := [false]
	topbar_inst.log_button_pressed.connect(func(): log_btn_signalled[0] = true)
	topbar_inst.log_btn.pressed.emit()
	assert_true(log_btn_signalled[0], "TopBar log_button_pressed signal emitted")

	var menu_scene = load("res://ui/menu/main_menu.tscn")
	assert_true(menu_scene != null, "main_menu.tscn loads")
	var menu_inst = menu_scene.instantiate()
	root.add_child(menu_inst)
	menu_inst.setup(settings_mgr, space_mgr, mod_mgr, event_bus)

	# Toggle menu
	menu_inst.open("settings")
	assert_true(menu_inst.is_open, "Main menu open() works")
	assert_true(menu_inst.tab_container.current_tab == 1, "Main menu opened on Settings tab")

	# Test reactive setting synchronization in MainMenu
	settings_mgr.set_setting("display", "fullscreen", true)
	assert_true(menu_inst.fullscreen_check.button_pressed == true, "MainMenu reacted to fullscreen change")
	settings_mgr.set_setting("display", "fullscreen", false)
	assert_true(menu_inst.fullscreen_check.button_pressed == false, "MainMenu reacted to windowed mode change")

	menu_inst.close()
	assert_false(menu_inst.is_open, "Main menu close() works")

	# Test PromptBar instantiation, clean input line, and StatusToast
	var prompt_scene = load("res://ui/prompt_bar/prompt_bar.tscn")
	assert_true(prompt_scene != null, "prompt_bar.tscn loads")
	var prompt_inst = prompt_scene.instantiate()
	root.add_child(prompt_inst)
	prompt_inst._ready()
	prompt_inst.open()
	assert_true(prompt_inst.is_open, "PromptBar open() works")
	assert_true(prompt_inst.close_btn != null, "PromptBar has close button")
	assert_true(prompt_inst.line_edit != null, "PromptBar has line_edit")
	assert_true(prompt_inst.status_toast != null, "PromptBar has StatusToast container")
	assert_true(prompt_inst.status_label != null, "StatusToast has status_label")
	assert_true(prompt_inst.status_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "StatusLabel has AUTOWRAP_WORD_SMART")
	assert_true(prompt_inst.inspect_btn != null, "StatusToast has inspect button")
	assert_true(prompt_inst.toast_close_btn != null, "StatusToast has toast_close_btn")

	# Test setting long error message (must autowrap and not crash)
	var long_error_msg := "HTTP error 403 (FORBIDDEN): User location is not supported for Gemini API direct access. Please switch provider in API settings or use a valid proxy/OpenRouter."
	var received_diag: Dictionary = {}
	prompt_inst.inspect_requested.connect(func(diag): received_diag.merge(diag, true))
	prompt_inst.set_status(long_error_msg, Color(1, 0.25, 0.25, 1), {"error": long_error_msg, "code": 403})
	assert_true(prompt_inst.status_label.text == long_error_msg, "StatusLabel received long error text")

	# Test clicking inspect button
	prompt_inst.inspect_btn.pressed.emit()
	assert_true(not received_diag.is_empty(), "PromptBar inspect_requested emitted with diagnostic data")
	assert_true(received_diag.get("error") == long_error_msg, "Diagnostic data contains error string")

	# Test closing toast
	prompt_inst.toast_close_btn.pressed.emit()
	assert_false(prompt_inst.status_toast.visible, "StatusToast closed via toast_close_btn")

	prompt_inst.close()
	assert_false(prompt_inst.is_open, "PromptBar close() works")
	prompt_inst.queue_free()

	# ----------------------------------------------------
	# Group 6: App Icon verification
	# ----------------------------------------------------
	print("\n--- Testing App Icon Configuration ---")
	assert_true(FileAccess.file_exists("res://icon.svg"), "res://icon.svg exists")
	var icon_file = FileAccess.open("res://icon.svg", FileAccess.READ)
	assert_true(icon_file != null, "icon.svg readable")
	var icon_text = icon_file.get_as_text()
	icon_file.close()
	assert_true("<svg" in icon_text, "icon.svg has valid SVG root")
	assert_true("UNICORE" in icon_text, "icon.svg contains UNICORE emblem")

	# ----------------------------------------------------
	# Group 7: Full Main Scene Instantiation (space_viewport.tscn)
	# ----------------------------------------------------
	print("\n--- Testing Main Scene space_viewport.tscn ---")
	var main_scene = load("res://core/space_viewport.tscn")
	assert_true(main_scene != null, "space_viewport.tscn loads successfully")

	var viewport_inst = main_scene.instantiate()
	assert_true(viewport_inst != null, "space_viewport.tscn instantiates cleanly")
	root.add_child(viewport_inst)

	# Allow one frame of processing
	assert_true(viewport_inst.settings_manager != null, "space_viewport has SettingsManager")
	assert_true(viewport_inst.space_manager != null, "space_viewport has SpaceManager")
	assert_true(viewport_inst.top_bar != null, "space_viewport has TopBar")
	assert_true(viewport_inst.main_menu != null, "space_viewport has MainMenu")
	assert_true(viewport_inst.prompt_bar != null, "space_viewport has PromptBar")
	assert_true(viewport_inst.analysis_drawer != null, "space_viewport has AnalysisDrawer")
	assert_true(viewport_inst.module_toolbar != null, "space_viewport has ModuleToolbar")

	# Test wiring: PromptBar inspect_requested -> AnalysisDrawer open
	assert_false(viewport_inst.analysis_drawer.is_open, "AnalysisDrawer starts closed")
	viewport_inst.prompt_bar.inspect_requested.emit({"title": "Test Error", "error": "Test failure"})
	assert_true(viewport_inst.analysis_drawer.is_open, "AnalysisDrawer opened by prompt_bar.inspect_requested")
	viewport_inst.analysis_drawer.close()
	assert_false(viewport_inst.analysis_drawer.is_open, "AnalysisDrawer closed cleanly")

	# Test wiring: TopBar log_button_pressed -> AnalysisDrawer toggle
	viewport_inst.top_bar.log_button_pressed.emit()
	assert_true(viewport_inst.analysis_drawer.is_open, "AnalysisDrawer toggled open by top_bar.log_button_pressed")
	viewport_inst.top_bar.log_button_pressed.emit()
	assert_false(viewport_inst.analysis_drawer.is_open, "AnalysisDrawer toggled closed by top_bar.log_button_pressed")

	# ----------------------------------------------------
	# Group 8: Detroit CyberLife AnalysisDrawer & DiagnosticLogger
	# ----------------------------------------------------
	print("\n--- Testing AnalysisDrawer & DiagnosticLogger ---")
	var drawer_scene = load("res://ui/analysis_drawer/analysis_drawer.tscn")
	assert_true(drawer_scene != null, "analysis_drawer.tscn loads successfully")

	var drawer_inst = drawer_scene.instantiate()
	assert_true(drawer_inst != null, "analysis_drawer instantiates cleanly")
	root.add_child(drawer_inst)
	drawer_inst.setup(event_bus)

	# Test DiagnosticLogger
	var test_diag_logger := DiagnosticLogger.new()
	root.add_child(test_diag_logger)
	test_diag_logger.clear()
	test_diag_logger.log_system("INFO", "CORE", "System online")
	test_diag_logger.log_system("WARN", "MEMORY", "High memory usage")
	test_diag_logger.log_agent("ERROR", "AGENT", "API connection failed")
	var logs = test_diag_logger.get_recent_entries()
	assert_true(logs.size() == 3, "DiagnosticLogger stored 3 entries")
	var logs_text = test_diag_logger.export_session_log()
	assert_true("API connection failed" in logs_text, "DiagnosticLogger formatted text contains error log")
	test_diag_logger.queue_free()

	# Test opening AnalysisDrawer with rich diagnostic data
	var test_diag_data := {
		"title": "[СБОЙ СЕТИ] Ошибка региона API",
		"description": "User location is not supported for Gemini API direct access.",
		"http_code": 403,
		"url": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash",
		"provider": "GEMINI DIRECT",
		"model": "gemini-2.5-flash",
		"last_prompt": "Создай летающую сферу",
		"error_body": "{\"error\": {\"code\": 403, \"message\": \"User location is not supported.\"}}",
		"code": "extends UniCoreModule\nfunc get_module_id():\n    return 'flying_sphere'",
		"logs": logs
	}
	drawer_inst.open(test_diag_data)
	assert_true(drawer_inst.is_open, "AnalysisDrawer open() sets is_open to true")
	assert_true(drawer_inst.title_label.text == "[СБОЙ СЕТИ] Ошибка региона API", "Title matches diagnostic data")
	assert_true("Региональное ограничение" in drawer_inst.explanation_label.text, "Human-readable root cause analyzed correctly")
	assert_true("403" in drawer_inst.http_line_label.text, "HTTP Code 403 displayed")

	# Test clipboard report generation and copying
	var copied_report = drawer_inst.copy_report_to_clipboard()
	assert_true(not copied_report.is_empty(), "copy_report_to_clipboard returns non-empty report")
	assert_true("UNICORE CYBERLIFE DIAGNOSTIC REPORT" in copied_report, "Report contains CyberLife header")
	assert_true("HTTP Статус: 403" in copied_report, "Report contains HTTP 403")
	assert_true("flying_sphere" in copied_report, "Report contains generated GDScript source code")
	assert_true(drawer_inst.last_copied_report == copied_report, "drawer.last_copied_report matches copied report")

	# Test quick action signals
	var settings_req_section := [""]
	drawer_inst.open_settings_requested.connect(func(sec): settings_req_section[0] = sec)
	drawer_inst.settings_btn.pressed.emit()
	assert_true(settings_req_section[0] == "api", "SettingsButton emits open_settings_requested with 'api'")

	var retry_prompt := [""]
	drawer_inst.retry_requested.connect(func(p): retry_prompt[0] = p)
	drawer_inst.retry_btn.pressed.emit()
	assert_true(retry_prompt[0] == "Создай летающую сферу", "RetryButton emits retry_requested with last prompt")

	# Test toggle and close
	drawer_inst.close()
	assert_false(drawer_inst.is_open, "AnalysisDrawer close() works")
	drawer_inst.toggle()
	assert_true(drawer_inst.is_open, "AnalysisDrawer toggle() opens when closed")
	drawer_inst.toggle()
	assert_false(drawer_inst.is_open, "AnalysisDrawer toggle() closes when open")

	drawer_inst.queue_free()

	# Clean up test nodes and reset test settings
	viewport_inst.queue_free()
	menu_inst.queue_free()
	topbar_inst.queue_free()
	space_mgr.queue_free()
	mod_mgr.queue_free()
	world_root.queue_free()
	event_bus.queue_free()
	settings_mgr.reset_to_defaults()
	settings_mgr.queue_free()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		quit(0)
	else:
		quit(1)
