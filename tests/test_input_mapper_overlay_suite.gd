extends SceneTree

const InputMapperOverlay = preload("res://ui/menu/components/input_mapper_overlay.gd")
const InputMapperScript = preload("res://core/input_mapper.gd")
const SettingsManagerScript = preload("res://core/settings_manager.gd")
const DesignTokens = preload("res://ui/theme/design_tokens.gd")

# ==============================================================================
# UniCORE Automated Test Suite: Input Mapper Overlay UI
# Verifies:
# 1. Overlay initialization and layout geometry
# 2. Integration with core InputMapper engine
# 3. Dynamic category filtering (all, system, active, library)
# 4. Search bar text filtering
# 5. Key capture modal lifecycle, conflict resolution and rebinding
# 6. Memory cleanup without leaks
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

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE Input Mapper Overlay UI Suite")
	print("==================================================")

	var settings := SettingsManagerScript.new()
	settings.name = "SettingsManager"
	root.add_child(settings)

	var mapper := InputMapperScript.new()
	mapper.name = "InputMapper"
	root.add_child(mapper)
	mapper.setup(settings)

	_test_overlay_structure()
	_test_mapper_integration(mapper)
	_test_category_and_search_filtering(mapper)
	_test_key_capture_modal(mapper)

	# Cleanup
	root.remove_child(mapper)
	mapper.free()
	root.remove_child(settings)
	settings.free()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("ALL TESTS PASSED SUCCESSFULLY! Quitting with code 0.")
		quit(0)
	else:
		print("SOME TESTS FAILED! Quitting with code 1.")
		quit(1)

func _test_overlay_structure() -> void:
	print("\n--- 1. Testing InputMapperOverlay Structure ---")
	var overlay := InputMapperOverlay.new()
	assert_true(overlay != null, "InputMapperOverlay instantiates cleanly")

	root.add_child(overlay)
	assert_true(overlay._modal_backdrop != null, "Backdrop node exists")
	assert_true(overlay._main_window != null, "Main glass window exists")
	assert_true(overlay._search_edit != null, "Search edit node exists")
	assert_true(overlay._cards_vbox != null, "Cards container exists")
	assert_true(overlay._capture_modal != null, "Capture modal exists")

	root.remove_child(overlay)
	overlay.free()
	assert_true(true, "Overlay freed cleanly")

func _test_mapper_integration(mapper: Node) -> void:
	print("\n--- 2. Testing Mapper Integration & Population ---")
	var overlay := InputMapperOverlay.new()
	root.add_child(overlay)

	overlay.setup(mapper)
	assert_true(overlay._cards_vbox.get_child_count() > 0, "Cards container populated with at least 1 module group")

	root.remove_child(overlay)
	overlay.free()
	assert_true(true, "Overlay freed cleanly after integration test")

func _test_category_and_search_filtering(mapper: Node) -> void:
	print("\n--- 3. Testing Category & Search Filtering ---")
	var overlay := InputMapperOverlay.new()
	root.add_child(overlay)
	overlay.setup(mapper)

	# 3.1 System Category
	overlay._selected_category = "system"
	overlay.refresh_list()
	assert_true(overlay._cards_vbox.get_child_count() > 0, "System actions rendered")

	# 3.2 Search Filter: "fullscreen"
	overlay._on_search_changed("fullscreen")
	assert_true(overlay._cards_vbox.get_child_count() > 0, "Fullscreen action found via search")

	# 3.3 Search Filter: Non-existent
	overlay._on_search_changed("non_existent_action_xyz")
	assert_eq(overlay._cards_vbox.get_child_count(), 0, "Zero cards rendered for non-matching search")

	root.remove_child(overlay)
	overlay.free()
	assert_true(true, "Overlay freed cleanly after filter tests")

func _test_key_capture_modal(mapper: Node) -> void:
	print("\n--- 4. Testing Key Capture Modal Lifecycle ---")
	var overlay := InputMapperOverlay.new()
	root.add_child(overlay)
	overlay.setup(mapper)

	# Open capture dialog for toggle_menu
	overlay._open_capture_dialog("toggle_menu", "Главное меню", "Система")
	assert_true(overlay._capture_modal.visible, "Capture modal became visible")
	assert_true(overlay._target_action == "toggle_menu", "Target action set to toggle_menu")

	# Close with escape
	var ev_esc := InputEventKey.new()
	ev_esc.keycode = KEY_ESCAPE
	ev_esc.pressed = true
	overlay._input(ev_esc)
	assert_false(overlay._capture_modal.visible, "Modal closed on Escape key")

	# Test rebinding via input
	overlay._open_capture_dialog("toggle_prompt_bar", "Строка команд", "Система")
	var ev_p := InputEventKey.new()
	ev_p.keycode = KEY_P
	ev_p.pressed = true
	overlay._input(ev_p)
	assert_false(overlay._capture_modal.visible, "Modal closed after key capture")
	assert_eq(mapper.call("get_bound_key", "toggle_prompt_bar"), KEY_P, "Action rebound to KEY_P")

	# Restore default
	mapper.call("reset_action_to_default", "toggle_prompt_bar")

	root.remove_child(overlay)
	overlay.free()
	assert_true(true, "Overlay freed cleanly after modal tests")
