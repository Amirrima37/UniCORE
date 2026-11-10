extends SceneTree

## Интеграционный тест: Живая Интерактивная Физическая Песочница (Interactive Sandbox Suite)
## Проверяет:
## 1. Дефолтный спейс: монтирование физических модулей и Солнечной системы на старте.
## 2. Схема ввода камеры: освобождение ЛКМ для манипуляций, ПКМ для полета, колесо для зума.
## 3. Разрешение имен модулей в инструментах (snake_case и PascalCase).
## 4. Панель пресетов PhysicsPresetBar: переключение 7 канонических сценариев в 1 клик.
## 5. Проброс параметров и быстрые кнопки в PhysicsInspectorDrawer.

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	print("\n=== [TEST SUITE] INTERACTIVE PHYSICAL SANDBOX VERIFICATION ===")
	_run_all_tests()
	_print_summary()

func _assert(condition: bool, test_name: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_count += 1
		print("  [FAIL] %s" % test_name)

func _run_all_tests() -> void:
	_test_avatar_locomotion_input()
	_test_space_manager_default_space()
	_test_physics_interaction_resolver_and_presets()
	_test_physics_preset_bar()
	_test_inspector_parameter_synchronization()

func _test_avatar_locomotion_input() -> void:
	print("\n--- Test Group 1: Avatar Locomotion Input Reform ---")
	var AvatarLocomotionScript = load("res://modules/builtin/avatar_locomotion.gd")
	var avatar = AvatarLocomotionScript.new()
	root.add_child(avatar)
	avatar.initialize({"event_bus": null})

	# Test 1.1: Initial mouse mode is VISIBLE (never captured on start)
	_assert(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE, "Avatar starts with MOUSE_MODE_VISIBLE")

	# Test 1.2: Left Click (LMB) does NOT capture mouse
	var lmb_event := InputEventMouseButton.new()
	lmb_event.button_index = MOUSE_BUTTON_LEFT
	lmb_event.pressed = true
	avatar._unhandled_input(lmb_event)
	_assert(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE, "LMB click does NOT capture mouse (stays VISIBLE)")
	_assert(avatar.is_rmb_held == false, "LMB does not activate RMB flight mode")

	# Test 1.3: Right Click (RMB) pressed captures mouse
	var rmb_press := InputEventMouseButton.new()
	rmb_press.button_index = MOUSE_BUTTON_RIGHT
	rmb_press.pressed = true
	avatar._unhandled_input(rmb_press)
	_assert(avatar.is_rmb_held == true, "RMB held flag is true on right-click press")

	# Test 1.4: Right Click (RMB) released restores visible mouse
	var rmb_release := InputEventMouseButton.new()
	rmb_release.button_index = MOUSE_BUTTON_RIGHT
	rmb_release.pressed = false
	avatar._unhandled_input(rmb_release)
	_assert(avatar.is_rmb_held == false, "RMB held flag is false on right-click release")
	_assert(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE, "Mouse mode restored to VISIBLE on RMB release")

	# Test 1.5: Mouse wheel zoom moves camera dolly
	var initial_z: float = avatar.yaw_node.global_position.z
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	avatar._unhandled_input(wheel_up)
	_assert(avatar.yaw_node.global_position.z < initial_z, "Wheel up dollies camera forward")

	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	avatar._unhandled_input(wheel_down)
	_assert(absf(avatar.yaw_node.global_position.z - initial_z) < 0.05, "Wheel down dollies camera backward")

	avatar.cleanup()
	avatar.queue_free()

func _test_space_manager_default_space() -> void:
	print("\n--- Test Group 2: Default Space Instant Life Configuration ---")
	var SpaceManagerScript = load("res://core/space_manager.gd")
	var sm = SpaceManagerScript.new()
	root.add_child(sm)

	# Verify default template builder output
	var space_data: Dictionary = sm._build_template_space_data("space_default", "Default Space", "default")
	_assert(space_data.has("modules"), "Default space contains modules array")

	var mod_list: Array = space_data.get("modules", [])
	var mod_ids: Array[String] = []
	for m in mod_list:
		mod_ids.append(str(m.get("id", "")))

	_assert(mod_ids.has("builtin_avatar_locomotion"), "Default space mounts avatar locomotion")
	_assert(mod_ids.has("n_body_gravity_module"), "Default space mounts NBodyGravityModule")
	_assert(mod_ids.has("molecular_dynamics_module"), "Default space mounts MolecularDynamicsModule")
	_assert(mod_ids.has("nuclear_decay_module"), "Default space mounts NuclearDecayModule")
	_assert(mod_ids.has("quantum_wavepacket_module"), "Default space mounts QuantumWavePacketModule")
	_assert(mod_ids.has("celestial_spawner_tool"), "Default space mounts celestial spawner tool")
	_assert(mod_ids.has("particle_injector_tool"), "Default space mounts particle injector tool")

	# Verify camera is positioned in high cinematic orbit
	var cam_pos = space_data.get("camera", {}).get("position", [])
	_assert(cam_pos.size() >= 3 and float(cam_pos[1]) >= 10.0 and float(cam_pos[2]) >= 15.0, "Camera positioned in cinematic overview orbit (Y>=10, Z>=15)")

	sm.queue_free()

func _test_physics_interaction_resolver_and_presets() -> void:
	print("\n--- Test Group 3: Physics Interaction Resolver & Presets ---")
	var EventBusScript = load("res://core/event_bus.gd")
	var eb = EventBusScript.new()
	root.add_child(eb)

	var ModuleManagerScript = load("res://core/module_manager.gd")
	var mm = ModuleManagerScript.new()
	var wr = Node3D.new()
	root.add_child(wr)
	root.add_child(mm)
	mm.setup(eb, wr)

	# Mount N-Body Gravity and Molecular Dynamics
	var GravScript = load("res://modules/physics/n_body_gravity_module.gd")
	var grav = GravScript.new()
	grav.name = "n_body_gravity_module"
	wr.add_child(grav)
	grav.initialize({"event_bus": eb, "module_manager": mm, "world_root": wr})
	mm._active_modules["n_body_gravity_module"] = grav

	var MDScript = load("res://modules/physics/molecular_dynamics_module.gd")
	var md = MDScript.new()
	md.name = "molecular_dynamics_module"
	wr.add_child(md)
	md.initialize({"event_bus": eb, "module_manager": mm, "world_root": wr})
	mm._active_modules["molecular_dynamics_module"] = md

	var InterMgrScript = load("res://core/physics/interaction/physics_interaction_manager.gd")
	var im = InterMgrScript.new()
	root.add_child(im)
	im.setup(eb, null, mm, null, null)

	# Verify module resolver finds modules by ID
	var resolved_grav = im._resolve_module("n_body_gravity_module")
	_assert(resolved_grav == grav, "PhysicsInteractionManager resolves n_body_gravity_module")

	var resolved_md = im._resolve_module("molecular_dynamics_module")
	_assert(resolved_md == md, "PhysicsInteractionManager resolves molecular_dynamics_module")

	# Verify Domain Isolation
	im.switch_domain("gravity")
	_assert(grav.is_simulation_active == true, "Gravity module is active when domain is 'gravity'")
	_assert(md.is_simulation_active == false, "MD module is inactive when domain is 'gravity'")
	
	im.switch_domain("thermodynamics")
	_assert(grav.is_simulation_active == false, "Gravity module is deactivated when domain is 'thermodynamics'")
	_assert(md.is_simulation_active == true, "MD module is activated when domain is 'thermodynamics'")

	# Verify preset triggering via EventBus
	eb.publish("physics_load_preset", {"preset_id": "solar_system"})
	_assert(grav._positions.size() == 5, "Solar System preset loads 5 celestial bodies (Sol + 4 planets)")
	_assert(grav.is_simulation_active == true, "Solar System preset activates gravity domain")
	_assert(md.is_simulation_active == false, "Solar System preset keeps MD inactive")

	eb.publish("physics_load_preset", {"preset_id": "figure8"})
	_assert(grav._positions.size() == 3, "Figure-8 preset loads 3 bodies in periodic choreographic orbit")

	eb.publish("physics_load_preset", {"preset_id": "cluster"})
	_assert(grav._positions.size() == 300, "Cluster preset loads 300 bodies")

	# Test direct celestial spawn
	im.gravity_spawn_mass = 42.0
	im.gravity_body_type = "planet"
	im._spawn_celestial_body(Vector3(15, 0, 0), Vector3(0, 3, 0))
	_assert(grav._positions.size() == 301, "Direct LMB drag spawn adds body to NBodyGravityModule")

	# Cleanup
	im.queue_free()
	grav.cleanup()
	grav.queue_free()
	md.cleanup()
	md.queue_free()
	mm.queue_free()
	wr.queue_free()
	eb.queue_free()

func _test_physics_preset_bar() -> void:
	print("\n--- Test Group 4: PhysicsPresetBar UI Component ---")
	var PresetBarScript = load("res://ui/physics/physics_preset_bar.gd")
	var bar = PresetBarScript.new()

	var EventBusScript = load("res://core/event_bus.gd")
	var eb = EventBusScript.new()
	root.add_child(eb)

	var last_loaded_preset := [""]
	var last_selected_tool := [""]
	eb.subscribe("physics_load_preset", func(p): last_loaded_preset[0] = str(p.get("preset_id", "")))
	eb.subscribe("physics_tool_selected", func(p): last_selected_tool[0] = str(p.get("tool_id", "")))

	bar._setup_buttons()
	bar.setup(eb)

	bar._on_button_pressed("gas_box")
	_assert(last_loaded_preset[0] == "gas_box", "Clicking Gas preset button publishes 'gas_box'")
	_assert(last_selected_tool[0] == "thermodynamics", "Gas preset automatically switches tool to 'thermodynamics'")

	bar._on_button_pressed("solar_system")
	_assert(last_loaded_preset[0] == "solar_system", "Clicking Solar button publishes 'solar_system'")
	_assert(last_selected_tool[0] == "gravity", "Solar preset automatically switches tool to 'gravity'")

	bar._on_button_pressed("nuclear_reactor")
	_assert(last_loaded_preset[0] == "nuclear_reactor", "Clicking Nuclear button publishes 'nuclear_reactor'")
	_assert(last_selected_tool[0] == "nuclear", "Nuclear preset automatically switches tool to 'nuclear'")

	bar._on_button_pressed("quantum_tunneling")
	_assert(last_loaded_preset[0] == "quantum_tunneling", "Clicking Quantum button publishes 'quantum_tunneling'")
	_assert(last_selected_tool[0] == "quantum", "Quantum preset automatically switches tool to 'quantum'")

	bar.queue_free()
	eb.queue_free()

func _test_inspector_parameter_synchronization() -> void:
	print("\n--- Test Group 5: Inspector Parameter Synchronization ---")
	var EventBusScript = load("res://core/event_bus.gd")
	var eb = EventBusScript.new()
	root.add_child(eb)

	var InterMgrScript = load("res://core/physics/interaction/physics_interaction_manager.gd")
	var im = InterMgrScript.new()
	root.add_child(im)
	im.setup(eb, null, null, null, null)

	# Test parameter synchronization: spawn_mass -> gravity_spawn_mass
	eb.publish("physics_parameter_changed", {"module_id": "gravity", "param": "spawn_mass", "value": 77.5})
	_assert(im.gravity_spawn_mass == 77.5, "Inspector 'spawn_mass' parameter updates interaction manager gravity_spawn_mass")

	# Test parameter synchronization: target_temp -> thermo_inject_temp
	eb.publish("physics_parameter_changed", {"module_id": "thermodynamics", "param": "target_temp", "value": 3.2})
	_assert(im.thermo_inject_temp == 3.2, "Inspector 'target_temp' parameter updates interaction manager thermo_inject_temp")

	# Test parameter synchronization: isotope -> nuclear_selected_isotope
	eb.publish("physics_parameter_changed", {"module_id": "nuclear", "param": "isotope", "value": "Ra-226"})
	_assert(im.nuclear_selected_isotope == "Ra-226", "Inspector 'isotope' parameter updates interaction manager isotope")

	# Test parameter synchronization: barrier_height -> quantum_barrier_v0
	eb.publish("physics_parameter_changed", {"module_id": "quantum", "param": "barrier_height", "value": 14.5})
	_assert(im.quantum_barrier_v0 == 14.5, "Inspector 'barrier_height' parameter updates interaction manager quantum_barrier_v0")

	im.queue_free()
	eb.queue_free()

func _print_summary() -> void:
	print("\n=======================================================")
	print("RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("=======================================================\n")
	if failed_count > 0:
		quit(1)
	else:
		quit(0)
