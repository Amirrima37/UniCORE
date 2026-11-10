extends SceneTree

const SettingsManagerScript = preload("res://core/settings_manager.gd")
const EventBusScript = preload("res://core/event_bus.gd")
const ModuleManagerScript = preload("res://core/module_manager.gd")
const ModuleLibraryScript = preload("res://core/module_library.gd")
const InputMapperScript = preload("res://core/input_mapper.gd")
const MainMenuScene = preload("res://ui/menu/main_menu.tscn")
const UniCoreModuleScript = preload("res://core/base_module.gd")

# ==============================================================================
# UniCORE Test Suite: Input Mapper & Graphic Keybindings Manager
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

class MockModuleWithBindings extends "res://core/base_module.gd":
	func get_module_id() -> String:
		return "mock_vehicle_tool"
	func get_module_name() -> String:
		return "Кибер-Вездеход"
	func get_action_bindings() -> Array[Dictionary]:
		return [
			{
				"action": "vehicle_accelerate",
				"label": "Газ / Ускорение",
				"default_key": KEY_W,
				"description": "Подача тяги на двигатели"
			},
			{
				"action": "vehicle_brake",
				"label": "Тормоз / Реверс",
				"default_key": KEY_S,
				"description": "Электродинамическое торможение"
			},
			{
				"action": "vehicle_horn",
				"label": "Звуковой сигнал",
				"default_key": KEY_H,
				"description": "Предупредительный гудок"
			}
		]

class MockModuleWithSource extends "res://core/base_module.gd":
	func get_module_id() -> String:
		return "mock_laser_turret"
	func get_module_name() -> String:
		return "Лазерная турель"

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE Input Mapper Test Suite")
	print("==================================================")

	var eb = EventBusScript.new()
	var sm = SettingsManagerScript.new()
	root.add_child(sm)
	sm.setup(eb)

	var mm = ModuleManagerScript.new()
	root.add_child(mm)
	var world = Node3D.new()
	root.add_child(world)
	mm.setup(eb, world)

	var ml = ModuleLibraryScript.new()
	root.add_child(ml)
	ml.setup(mm, eb)

	var im = InputMapperScript.new()
	root.add_child(im)
	im.setup(sm, mm, ml, eb)
	im.reset_all_to_defaults()

	_test_system_actions(im)
	_test_active_module_discovery(im, mm)
	_test_source_code_parsing(im)
	_test_rebinding_and_input_map(im, sm)
	_test_key_formatting(im)
	_test_conflict_detection(im)
	_test_reset_bindings(im)
	_test_ui_integration(im, sm, mm, ml, eb)

	im.free()
	ml.free()
	world.free()
	mm.free()
	sm.free()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("ALL TESTS PASSED SUCCESSFULLY! Quitting with code 0.")
		quit(0)
	else:
		print("SOME TESTS FAILED! Quitting with code 1.")
		quit(1)

func _test_system_actions(im: Node) -> void:
	print("\n--- 1. Testing System Actions Registration ---")
	var sys_actions: Array = im.get_actions_by_category("system")
	assert_true(sys_actions.size() >= 5, "Registered at least 5 system actions")

	var act_names: Array[String] = []
	for a in sys_actions:
		act_names.append(a["action"])

	assert_true(act_names.has("toggle_menu"), "Has toggle_menu")
	assert_true(act_names.has("toggle_fullscreen"), "Has toggle_fullscreen")
	assert_true(act_names.has("toggle_prompt_bar"), "Has toggle_prompt_bar")
	assert_true(act_names.has("toggle_analysis_drawer"), "Has toggle_analysis_drawer")
	assert_true(act_names.has("toggle_module_gallery"), "Has toggle_module_gallery")

	assert_eq(im.get_bound_key("toggle_fullscreen"), KEY_F11, "toggle_fullscreen default is KEY_F11")
	assert_eq(im.get_bound_key("toggle_menu"), KEY_ESCAPE, "toggle_menu default is KEY_ESCAPE")

func _test_active_module_discovery(im: Node, mm: ModuleManager) -> void:
	print("\n--- 2. Testing Active Module Action Discovery ---")
	var mod := MockModuleWithBindings.new()
	mm.register_module_instance(mod.get_module_id(), mod)
	im.refresh_actions()

	var active_groups: Dictionary = im.get_actions_grouped_by_module("active")
	assert_true(active_groups.has("mock_vehicle_tool"), "Active group contains mock_vehicle_tool")

	var grp: Dictionary = active_groups["mock_vehicle_tool"]
	assert_eq(grp["name"], "Кибер-Вездеход", "Module name matches")
	var actions: Array = grp["actions"]
	assert_eq(actions.size(), 3, "Discovered 3 actions")

	var act_ids: Array[String] = []
	for a in actions:
		act_ids.append(a["action"])
	assert_true(act_ids.has("vehicle_accelerate"), "Has vehicle_accelerate")
	assert_true(act_ids.has("vehicle_brake"), "Has vehicle_brake")
	assert_true(act_ids.has("vehicle_horn"), "Has vehicle_horn")

	assert_eq(im.get_default_key("vehicle_accelerate"), KEY_W, "vehicle_accelerate default key is KEY_W")
	assert_eq(im.get_default_key("vehicle_horn"), KEY_H, "vehicle_horn default key is KEY_H")
	im.reset_action_to_default("vehicle_accelerate")
	im.reset_action_to_default("vehicle_horn")
	assert_eq(im.get_bound_key("vehicle_accelerate"), KEY_W, "vehicle_accelerate bound key is KEY_W")
	assert_eq(im.get_bound_key("vehicle_horn"), KEY_H, "vehicle_horn bound key is KEY_H")

func _test_source_code_parsing(im: Node) -> void:
	print("\n--- 3. Testing Source Code Action Directives Parsing ---")
	var fake_code := """
extends UniCoreModule
## Name: Тестовая пушка
## Action: cannon_fire = KEY_F ("Огонь из пушки", "Выстрел основным калибром")
## Action: cannon_zoom = KEY_Z ("Прицел", "Оптический зум")

func _process(delta):
	if Input.is_action_pressed("cannon_overload"):
		pass
"""
	im._parse_actions_from_source(fake_code, "test_cannon", "Тестовая пушка", "library")

	var all_actions: Array = im.get_all_actions()
	var action_map := {}
	for a in all_actions:
		action_map[a["action"]] = a

	assert_true(action_map.has("cannon_fire"), "Parsed cannon_fire from comments")
	assert_eq(action_map["cannon_fire"]["label"], "Огонь из пушки", "Parsed action label")
	assert_eq(action_map["cannon_fire"]["default_key"], KEY_F, "Parsed default key KEY_F")

	assert_true(action_map.has("cannon_zoom"), "Parsed cannon_zoom from comments")
	assert_eq(action_map["cannon_zoom"]["default_key"], KEY_Z, "Parsed default key KEY_Z")

	assert_true(action_map.has("cannon_overload"), "Parsed cannon_overload from is_action_pressed")

func _test_rebinding_and_input_map(im: Node, sm: SettingsManager) -> void:
	print("\n--- 4. Testing Rebinding and InputMap Synchronization ---")
	var success: bool = im.rebind_action("vehicle_horn", KEY_B, true)
	assert_true(success, "rebind_action returned true")
	assert_eq(im.get_bound_key("vehicle_horn"), KEY_B, "Bound key updated in InputMapper")
	assert_eq(sm.get_binding("vehicle_horn"), KEY_B, "Bound key persisted in SettingsManager")

	assert_true(InputMap.has_action("vehicle_horn"), "InputMap has action vehicle_horn")
	var events := InputMap.action_get_events("vehicle_horn")
	assert_true(events.size() > 0, "InputMap has events for vehicle_horn")
	var key_ev: InputEventKey = events[0] as InputEventKey
	assert_true(key_ev != null, "Event is InputEventKey")
	assert_eq(int(key_ev.keycode), KEY_B, "InputMap event keycode is KEY_B")

func _test_key_formatting(im: Node) -> void:
	print("\n--- 5. Testing Key Display Names ---")
	assert_eq(InputMapperScript.get_key_display_name(KEY_W), "W", "Format KEY_W")
	assert_eq(InputMapperScript.get_key_display_name(KEY_SPACE), "SPACE", "Format KEY_SPACE")
	assert_eq(InputMapperScript.get_key_display_name(KEY_ESCAPE), "ESC", "Format KEY_ESCAPE")
	assert_eq(InputMapperScript.get_key_display_name(KEY_F11), "F11", "Format KEY_F11")
	assert_eq(InputMapperScript.get_key_display_name(KEY_NONE), "—", "Format KEY_NONE")

	assert_eq(InputMapperScript.parse_key_string_to_code("KEY_W"), KEY_W, "Parse KEY_W")
	assert_eq(InputMapperScript.parse_key_string_to_code("SPACE"), KEY_SPACE, "Parse SPACE")
	assert_eq(InputMapperScript.parse_key_string_to_code("F11"), KEY_F11, "Parse F11")

func _test_conflict_detection(im: Node) -> void:
	print("\n--- 6. Testing Key Conflict Detection ---")
	# vehicle_accelerate is KEY_W, vehicle_brake is KEY_S
	var conflict1: Dictionary = im.check_conflict("vehicle_brake", KEY_W)
	assert_true(conflict1["has_conflict"], "Detected conflict for KEY_W with vehicle_accelerate")
	assert_eq(conflict1["conflicting_action"], "vehicle_accelerate", "Conflict identified correctly")

	var conflict2: Dictionary = im.check_conflict("vehicle_brake", KEY_K)
	assert_false(conflict2["has_conflict"], "No conflict for unused key KEY_K")

func _test_reset_bindings(im: Node) -> void:
	print("\n--- 7. Testing Reset Actions to Default ---")
	# Rebind accelerate
	im.rebind_action("vehicle_accelerate", KEY_UP, true)
	assert_eq(im.get_bound_key("vehicle_accelerate"), KEY_UP, "Rebound to KEY_UP")

	# Reset single action
	im.reset_action_to_default("vehicle_accelerate")
	assert_eq(im.get_bound_key("vehicle_accelerate"), KEY_W, "Reset single action to KEY_W")

	# Rebind multiple and reset all
	im.rebind_action("vehicle_accelerate", KEY_I, true)
	im.rebind_action("vehicle_brake", KEY_K, true)
	im.reset_all_to_defaults()
	assert_eq(im.get_bound_key("vehicle_accelerate"), KEY_W, "Reset all restored accelerate to KEY_W")
	assert_eq(im.get_bound_key("vehicle_brake"), KEY_S, "Reset all restored brake to KEY_S")

func _test_ui_integration(im: Node, sm: SettingsManager, mm: ModuleManager, ml: ModuleLibrary, eb: EventBus) -> void:
	print("\n--- 8. Testing MainMenu Keybindings UI Integration ---")
	var menu: MainMenu = MainMenuScene.instantiate()
	root.add_child(menu)
	menu.setup(sm, null, mm, eb, ml, null, null, null, null, null, im)

	assert_true(menu.keybindings_section_panel != null, "KeybindingsSection created in MainMenu")
	assert_true(menu.active_bindings_container != null, "Active bindings container created")
	assert_true(menu.system_bindings_container != null, "System bindings container created")
	assert_true(menu.reset_all_bindings_btn != null, "Reset all bindings button created")

	# Trigger open and verify cards populated
	menu.open("settings")
	assert_true(menu.active_bindings_container.get_child_count() > 0, "Active bindings container populated with cards")
	assert_true(menu.system_bindings_container.get_child_count() > 0, "System bindings container populated with card")

	# Test Key Capture Modal opening
	menu._open_key_capture("vehicle_accelerate", "Газ", "Кибер-Вездеход")
	assert_true(menu._key_capture_modal != null, "Key capture modal instantiated")
	assert_true(menu._key_capture_modal.visible, "Key capture modal is visible")

	# Test Key Capture cancellation with Esc
	menu._handle_captured_key(KEY_ESCAPE)
	assert_false(menu._key_capture_modal.visible, "Modal closed on Esc")

	# Test Key Capture rebinding
	menu._open_key_capture("vehicle_accelerate", "Газ", "Кибер-Вездеход")
	menu._handle_captured_key(KEY_O)
	assert_false(menu._key_capture_modal.visible, "Modal closed after key capture")
	assert_eq(im.get_bound_key("vehicle_accelerate"), KEY_O, "Rebound vehicle_accelerate to KEY_O via modal")

	# Clean up
	im.reset_all_to_defaults()
	menu.close()
	menu.queue_free()
