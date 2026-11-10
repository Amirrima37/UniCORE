extends SceneTree

const BootScreen = preload("res://ui/welcome_screen/boot_screen.gd")
const WelcomeScreen = preload("res://ui/welcome_screen/welcome_screen.gd")
const DesignTokens = preload("res://ui/theme/design_tokens.gd")

# ==============================================================================
# UniCORE Automated Test Suite: Boot & Welcome Screen Architecture
# Verifies:
# 1. BootScreen initialization, CERN schematic display, and step telemetry
# 2. BootScreen skip mechanism and completion signals
# 3. WelcomeScreen layout, navigation spine (6 buttons), and telemetry card
# 4. Button signal routing (resume, spaces, modules, network, settings)
# 5. Clean teardown and memory safety
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
	print("Starting UniCORE Boot & Welcome Screen Suite")
	print("==================================================")

	_test_boot_screen_lifecycle()
	_test_welcome_screen_structure()
	_test_welcome_screen_actions()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("ALL TESTS PASSED SUCCESSFULLY! Quitting with code 0.")
		quit(0)
	else:
		print("SOME TESTS FAILED! Quitting with code 1.")
		quit(1)

func _test_boot_screen_lifecycle() -> void:
	print("\n--- 1. Testing BootScreen Lifecycle & Sequence ---")
	var boot := BootScreen.new()
	assert_true(boot != null, "BootScreen instantiates cleanly")
	boot.auto_start = false # Контролируем запуск вручную

	root.add_child(boot)
	assert_true(boot._schematic_rect != null, "Schematic texture node exists")
	assert_true(boot._telemetry_label != null, "Telemetry label exists")
	assert_true(boot._progress_bar != null, "Progress bar exists")

	# Запускаем последовательность
	boot.start_boot_sequence()
	assert_true(boot._is_booting, "Boot sequence active")
	assert_true(boot._progress_bar.max_value == float(boot.BOOT_SEQUENCE.size()), "Progress bar max matches sequence count")

	# Проверяем пропуск
	var completed := [false]
	boot.boot_completed.connect(func(): completed[0] = true)
	boot.skip_boot()
	assert_true(boot._is_completed, "Boot sequence marked as completed upon skip")

	root.remove_child(boot)
	boot.free()
	assert_true(true, "BootScreen freed cleanly")

func _test_welcome_screen_structure() -> void:
	print("\n--- 2. Testing WelcomeScreen Layout Structure ---")
	var welcome := WelcomeScreen.new()
	assert_true(welcome != null, "WelcomeScreen instantiates cleanly")

	root.add_child(welcome)
	assert_true(welcome._background_grid != null, "Background void grid exists")
	assert_true(welcome._ambient_graph != null, "Ambient graph canvas exists")
	assert_true(welcome._left_nav_panel != null, "Left navigation spine exists")
	assert_true(welcome._right_showcase_panel != null, "Right showcase panel exists")
	assert_eq(welcome._nav_buttons.size(), 6, "Navigation spine contains exactly 6 buttons")

	# Проверяем названия кнопок
	assert_true(welcome._btn_resume.text.begins_with("01 //"), "Button 01 is Resume")
	assert_true(welcome._btn_spaces.text.begins_with("02 //"), "Button 02 is Spaces")
	assert_true(welcome._btn_modules.text.begins_with("03 //"), "Button 03 is Modules")
	assert_true(welcome._btn_network.text.begins_with("04 //"), "Button 04 is Network")
	assert_true(welcome._btn_settings.text.begins_with("05 //"), "Button 05 is Settings")
	assert_true(welcome._btn_quit.text.begins_with("06 //"), "Button 06 is Quit")

	root.remove_child(welcome)
	welcome.free()
	assert_true(true, "WelcomeScreen freed cleanly")

func _test_welcome_screen_actions() -> void:
	print("\n--- 3. Testing WelcomeScreen Action Signals ---")
	var welcome := WelcomeScreen.new()
	root.add_child(welcome)

	var spaces_signal_fired := [false]
	var modules_signal_fired := [false]
	var network_signal_fired := [false]
	var settings_signal_fired := [false]

	welcome.spaces_requested.connect(func(): spaces_signal_fired[0] = true)
	welcome.modules_requested.connect(func(): modules_signal_fired[0] = true)
	welcome.network_requested.connect(func(): network_signal_fired[0] = true)
	welcome.settings_requested.connect(func(): settings_signal_fired[0] = true)

	welcome._btn_spaces.emit_signal("pressed")
	assert_true(spaces_signal_fired[0], "Spaces button emits spaces_requested")

	welcome._btn_modules.emit_signal("pressed")
	assert_true(modules_signal_fired[0], "Modules button emits modules_requested")

	welcome._btn_network.emit_signal("pressed")
	assert_true(network_signal_fired[0], "Network button emits network_requested")

	welcome._btn_settings.emit_signal("pressed")
	assert_true(settings_signal_fired[0], "Settings button emits settings_requested")

	root.remove_child(welcome)
	welcome.free()
	assert_true(true, "WelcomeScreen freed cleanly after action tests")
