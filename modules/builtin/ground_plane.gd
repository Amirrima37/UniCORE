extends UniCoreModule

## Предустановленный модуль: Нулевая плоскость мира (Ground Plane)
## Создает бесконечную или процедурную сетку на уровне Y = 0.

var mesh_instance: MeshInstance3D

func get_module_id() -> String:
	return "builtin_ground_plane"

func get_module_name() -> String:
	return "Ground Plane (Built-in)"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)

	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "GroundGridVisual"

	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(2000.0, 2000.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.93, 0.95, 1.0)
	material.roughness = 0.9

	mesh_instance.mesh = plane_mesh
	mesh_instance.material_override = material

	add_child(mesh_instance)
	return true

func cleanup() -> void:
	if mesh_instance:
		mesh_instance.queue_free()
	super.cleanup()
