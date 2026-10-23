extends UniCoreModule

var _body: RigidBody3D
var _material: StandardMaterial3D

func get_module_id() -> String:
	return "physics_gravity"

func get_module_name() -> String:
	return "Физика: Интерактивный Физический Куб"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)

	_body = RigidBody3D.new()
	_body.name = "PhysicsCube"
	_body.mass = 2.0

	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = 0.65
	phys_mat.friction = 0.3
	_body.physics_material_override = phys_mat

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.2, 1.2)
	col.shape = shape
	_body.add_child(col)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.2, 1.2)
	mi.mesh = box

	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.4, 0.1)
	_material.metallic = 0.2
	_material.roughness = 0.3
	_material.emission_enabled = true
	_material.emission = Color(0.8, 0.2, 0.0)
	mi.material_override = _material
	_body.add_child(mi)

	_body.position = Vector3(0, 4.0, -3.0)
	add_child(_body)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not is_initialized or not _body:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_apply_bounce_impulse()

func _apply_bounce_impulse() -> void:
	if is_instance_valid(_body):
		var upward := Vector3(randf_range(-1.0, 1.0), 8.0, randf_range(-1.0, 1.0))
		_body.apply_central_impulse(upward)
		_body.apply_torque_impulse(Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))

func cleanup() -> void:
	if _body and is_instance_valid(_body):
		_body.queue_free()
	super.cleanup()
