extends UniCoreModule

## Инструмент создания красных кубов (Cube Spawner Tool)
var _spawned_cubes: Array[Node3D] = []
var _material: StandardMaterial3D

func get_module_id() -> String:
	return "cube_spawner_tool"

func get_module_name() -> String:
	return "Инструмент: Спавнер Красных Кубов"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.15, 0.15, 1.0)
	_material.roughness = 0.3
	_material.metallic = 0.1
	spawn_cube(Vector3(0, 1.5, -4.0))
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized:
		return
	var should_spawn := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			should_spawn = true
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F or event.keycode == KEY_E:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				should_spawn = true
	if should_spawn:
		var cam := get_viewport().get_camera_3d()
		var spawn_pos := Vector3(0, 1.5, -4.0)
		if cam:
			spawn_pos = cam.global_position - cam.global_transform.basis.z * 4.0
		spawn_cube(spawn_pos)
		get_viewport().set_input_as_handled()

func spawn_cube(pos: Vector3) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.2, 1.2)
	mesh_inst.mesh = box
	mesh_inst.material_override = _material
	mesh_inst.position = pos
	add_child(mesh_inst)
	_spawned_cubes.append(mesh_inst)
	return mesh_inst

func cleanup() -> void:
	for c in _spawned_cubes:
		if is_instance_valid(c):
			c.queue_free()
	_spawned_cubes.clear()
	super.cleanup()
