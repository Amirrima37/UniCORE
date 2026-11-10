extends SceneTree

func _init() -> void:
	print("Step 1: EventBus")
	var eb_script = load("res://core/event_bus.gd")
	var event_bus = eb_script.new()
	root.add_child(event_bus)

	print("Step 2: SettingsManager")
	var settings_script = load("res://core/settings_manager.gd")
	var settings_mgr = settings_script.new()
	root.add_child(settings_mgr)
	settings_mgr.setup(event_bus)

	print("Step 3: ModuleManager")
	var mod_mgr_script = load("res://core/module_manager.gd")
	var mod_mgr = mod_mgr_script.new()
	root.add_child(mod_mgr)
	var world_root = Node3D.new()
	root.add_child(world_root)
	mod_mgr.setup(event_bus, world_root)

	print("Step 4: SpaceManager")
	var space_mgr_script = load("res://core/space_manager.gd")
	var space_mgr = space_mgr_script.new()
	root.add_child(space_mgr)
	space_mgr.setup(mod_mgr, event_bus, world_root, null, settings_mgr)

	print("Step 5: MainMenu instantiate")
	var menu_scene = load("res://ui/menu/main_menu.tscn")
	var menu_inst = menu_scene.instantiate()
	root.add_child(menu_inst)

	print("Step 6: menu_inst.setup")
	menu_inst.setup(settings_mgr, space_mgr, mod_mgr, event_bus)

	print("Step 7: menu_inst.open")
	menu_inst.open("settings")

	print("Testing reactive fullscreen:")
	settings_mgr.set_setting("display", "fullscreen", true)
	print("menu_inst.fullscreen_check.button_pressed = ", menu_inst.fullscreen_check.button_pressed)
	settings_mgr.set_setting("display", "fullscreen", false)
	print("menu_inst.fullscreen_check.button_pressed = ", menu_inst.fullscreen_check.button_pressed)

	print("Testing PromptBar:")
	var prompt_scene = load("res://ui/prompt_bar/prompt_bar.tscn")
	var prompt_inst = prompt_scene.instantiate()
	root.add_child(prompt_inst)
	prompt_inst.open()
	print("PromptBar opened: ", prompt_inst.is_open)
	prompt_inst.close()
	print("PromptBar closed: ", prompt_inst.is_open)
	prompt_inst.queue_free()

	print("Done test!")
	quit(0)
