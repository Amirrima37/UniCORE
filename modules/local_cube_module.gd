extends UniCoreModule

## Name: Локальный Куб
## Description: Создан локальным ИИ без внешних ключей
## Tags: local, 3d, test

var _box: MeshInstance3D

func get_module_id() -> String:
	return "local_cube_module"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	_box = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	_box.mesh = mesh
	add_child(_box)
	return true

func cleanup() -> void:
	if is_instance_valid(_box):
		_box.queue_free()
	super.cleanup()