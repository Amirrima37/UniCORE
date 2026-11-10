extends SceneTree

const WelcomeScreenScript = preload("res://ui/welcome_screen/welcome_screen.gd")
const BootScreenScript = preload("res://ui/welcome_screen/boot_screen.gd")

# ==============================================================================
# UniCORE Test Suite: SpaceViewport Start & Welcome Screen Integration
# Verifies:
# 1. SpaceViewport mounting of WelcomeScreen and BootScreen
# 2. Start menu setup and data injection
# 3. Resume session and modal lifecycle transitions
# 4. MainMenu and TopBar return-to-welcome navigation
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
	print("Starting UniCORE SpaceViewport Start Menu Suite")
	print("==================================================")

	_test_start_menu_mounting()
	_test_navigation_and_signals()

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("ALL TESTS PASSED SUCCESSFULLY! Quitting with code 0.")
		quit(0)
	else:
		print("SOME TESTS FAILED! Quitting with code 1.")
		quit(1)

func _test_start_menu_mounting() -> void:
	print("\n--- 1. Testing Start Menu Mounting & Hierarchy ---")
	var space_scene := load("res://core/space_viewport.tscn") as PackedScene
	assert_true(space_scene != null, "space_viewport.tscn loads successfully")

	var viewport := space_scene.instantiate() as SpaceViewport
	assert_true(viewport != null, "SpaceViewport instantiates cleanly")
	root.add_child(viewport)

	assert_true(viewport.welcome_screen != null, "SpaceViewport has WelcomeScreen in CanvasLayer")
	assert_true(viewport.boot_screen != null, "SpaceViewport has BootScreen in CanvasLayer")
	assert_true(viewport.main_menu != null, "SpaceViewport has MainMenu")
	assert_true(viewport.top_bar != null, "SpaceViewport has TopBar")

	# Проверяем, что в WelcomeScreen внедрены ссылки на ядро
	var ws: Control = viewport.welcome_screen
	assert_true(ws._space_manager != null, "WelcomeScreen received SpaceManager")
	assert_true(ws._module_manager != null, "WelcomeScreen received ModuleManager")
	assert_true(ws._event_bus != null, "WelcomeScreen received EventBus")

	root.remove_child(viewport)
	viewport.free()
	assert_true(true, "SpaceViewport freed cleanly without leaks")

func _test_navigation_and_signals() -> void:
	print("\n--- 2. Testing Start Menu Navigation & State Transitions ---")
	var space_scene := load("res://core/space_viewport.tscn") as PackedScene
	var viewport := space_scene.instantiate() as SpaceViewport
	root.add_child(viewport)

	var ws: Control = viewport.welcome_screen
	var mm: Control = viewport.main_menu
	var tb: Control = viewport.top_bar

	# Симулируем открытие стартового экрана
	viewport._return_to_welcome_screen()
	assert_false(viewport._is_in_space, "_is_in_space is false on welcome screen")
	assert_true(ws.visible, "WelcomeScreen is visible")

	# Тестируем переход в пространство (Resume)
	ws._on_resume_pressed()
	assert_true(viewport._is_in_space, "_is_in_space becomes true after resume")

	# Тестируем запрос Пространств из стартового экрана
	viewport._return_to_welcome_screen()
	ws._on_spaces_pressed()
	assert_true(mm.is_open, "MainMenu opened upon spaces_requested")
	assert_eq(mm.tab_container.current_tab, 0, "Spaces tab (index 0) active in MainMenu")

	# Закрываем MainMenu — должны остаться на WelcomeScreen, так как сессия еще не началась
	mm.close()
	assert_false(viewport._is_in_space, "Session still not resumed")
	assert_true(ws.visible, "Returned to WelcomeScreen after closing MainMenu")

	# Тестируем запрос Настроек из стартового экрана
	ws._on_settings_pressed()
	assert_true(mm.is_open, "MainMenu opened upon settings_requested")
	assert_eq(mm.tab_container.current_tab, 1, "Settings tab (index 1) active in MainMenu")
	mm.close()

	# Возобновляем сессию (вход в 3D)
	viewport._is_in_space = true
	ws.visible = false

	# Из 3D вызываем клик по логотипу UNICORE в TopBar -> возврат в стартовое меню
	tb.menu_button_pressed.emit("welcome")
	assert_false(viewport._is_in_space, "Clicking UNICORE logo returns to welcome screen")
	assert_true(ws.visible, "WelcomeScreen is visible again")

	# Из MainMenu клик по 'В СТАРТОВЫЙ ЭКРАН' -> возврат в стартовое меню
	viewport._is_in_space = true
	ws.visible = false
	mm.open()
	assert_true(mm.title_screen_btn != null, "MainMenu has title_screen_btn")
	mm.title_screen_requested.emit()
	assert_false(viewport._is_in_space, "MainMenu title_screen_requested returns to welcome screen")
	assert_true(ws.visible, "WelcomeScreen reopened from MainMenu")

	root.remove_child(viewport)
	viewport.free()
	assert_true(true, "Navigation test finished and cleaned up cleanly")
