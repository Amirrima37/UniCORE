## Name: Приветственный Голографический Куб
## Description: Создаёт приветственный вращающийся куб в сцене с интерактивным управлением. По нажатию клавиши F спавнит дополнительные кубы вокруг камеры, по клавише G — очищает все созданные объекты. Демонстрирует базовую механику спавна и взаимодействия в UniCORE.
## Tags: demo, spawner, cube, interactive, hello

extends UniCoreModule

var _world_root: Node3D
var _event_bus: Node
var _module_manager: Node
var _spawned: Array[Node3D] = []
var _main_cube: MeshInstance3D
var _time: float = 0.0
var _spawn_count: int = 0


func get_module_id() -> String:
	return "hello_holographic_cube"


func get_module_name() -> String:
	return "Приветственный Голографический Куб"


func get_action_bindings() -> Array[Dictionary]:
	return [
		{ 'action': 'hello_spawn_cube', 'label': 'Спавн куба', 'default_key': KEY_F, 'description': 'Создать новый куб рядом с камерой' },
		{ 'action': 'hello_clear_cubes', 'label': 'Очистить кубы', 'default_key': KEY_G, 'description': 'Удалить все созданные кубы' }
	]


func initialize(context: Dictionary) -> bool:
	_world_root = context.get("world_root", null)
	_event_bus = context.get("event_bus", null)
	_module_manager = context.get("module_manager", null)

	if _world_root == null:
		push_error("[hello_holographic_cube] world_root отсутствует в контексте")
		return false

	_register_input_actions()
	_spawn_main_cube()

	if _event_bus and _event_bus.has_signal("module_initialized"):
		_event_bus.emit_signal("module_initialized", get_module_id())

	print("[hello_holographic_cube] Модуль инициализирован. Нажмите F для спавна, G для очистки.")
	return true


func _register_input_actions() -> void:
	if not InputMap.has_action("hello_spawn_cube"):
		InputMap.add_action("hello_spawn_cube")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F
		InputMap.action_add_event("hello_spawn_cube", ev)

	if not InputMap.has_action("hello_clear_cubes"):
		InputMap.add_action("hello_clear_cubes")
		var ev2 := InputEventKey.new()
		ev2.physical_keycode = KEY_G
		InputMap.action_add_event("hello_clear_cubes", ev2)


func _spawn_main_cube() -> void:
	_main_cube = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	_main_cube.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.5, 0.9)
	mat.emission_energy_multiplier = 0.6
	mat.metallic = 0.4
	mat.roughness = 0.2
	_main_cube.material_override = mat

	_main_cube.position = Vector3(0, 1.5, -3.0)
	_main_cube.name = "HelloMainCube"

	_world_root.add_child(_main_cube)
	_spawned.append(_main_cube)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hello_spawn_cube"):
		_spawn_extra_cube()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hello_clear_cubes"):
		_clear_extra_cubes()
		get_viewport().set_input_as_handled()


func _spawn_extra_cube() -> void:
	_spawn_count += 1

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var s := randf_range(0.4, 1.0)
	box.size = Vector3(s, s, s)
	mi.mesh = box

	var mat := StandardMaterial3D.new()
	var hue := fmod(float(_spawn_count) * 0.13, 1.0)
	mat.albedo_color = Color.from_hsv(hue, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.5
	mi.material_override = mat

	var angle := randf() * TAU
	var radius := randf_range(2.0, 5.0)
	var height := randf_range(0.5, 3.5)
	mi.position = Vector3(cos(angle) * radius, height, sin(angle) * radius - 3.0)
	mi.name = "HelloCube_%d" % _spawn_count

	_world_root.add_child(mi)
	_spawned.append(mi)

	if _event_bus and _event_bus.has_signal("object_spawned"):
		_event_bus.emit_signal("object_spawned", mi)


func _clear_extra_cubes() -> void:
	for i in range(_spawned.size() - 1, 0, -1):
		var node := _spawned[i]
		if is_instance_valid(node):
			node.queue_free()
		_spawned.remove_at(i)
	_spawn_count = 0
	print("[hello_holographic_cube] Дополнительные кубы удалены.")


func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(_main_cube):
		_main_cube.rotate_y(delta * 0.8)
		_main_cube.position.y = 1.5 + sin(_time * 1.5) * 0.3


func cleanup() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	_main_cube = null
	print("[hello_holographic_cube] Модуль очищен.")
	queue_free()