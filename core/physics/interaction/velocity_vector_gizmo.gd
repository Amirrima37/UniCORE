class_name VelocityVectorGizmo
extends Node3D

## 3D Interactive Velocity Vector Gizmo for UniCORE.
## Dynamically visualizes impulse direction, magnitude, and energy during user click-and-drag.
## Uses lightweight procedural Cylinder (shaft) and Cone (head) without per-frame vertex allocations.

@export var shaft_radius: float = 0.05
@export var head_radius: float = 0.16
@export var head_length: float = 0.4
@export var default_color: Color = Color(0.0, 0.9, 1.0, 0.95)

var _shaft_mesh_inst: MeshInstance3D
var _head_mesh_inst: MeshInstance3D
var _material: StandardMaterial3D
var _current_origin: Vector3 = Vector3.ZERO
var _current_vector: Vector3 = Vector3.ZERO

func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = default_color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	_shaft_mesh_inst = MeshInstance3D.new()
	_shaft_mesh_inst.name = "Shaft"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = shaft_radius
	cylinder.bottom_radius = shaft_radius
	cylinder.height = 1.0
	_shaft_mesh_inst.mesh = cylinder
	_shaft_mesh_inst.material_override = _material
	add_child(_shaft_mesh_inst)

	_head_mesh_inst = MeshInstance3D.new()
	_head_mesh_inst.name = "Head"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0 # Cone tip
	cone.bottom_radius = head_radius
	cone.height = head_length
	_head_mesh_inst.mesh = cone
	_head_mesh_inst.material_override = _material
	add_child(_head_mesh_inst)
	
	visible = false

## Updates the arrow's origin, direction, and magnitude.
## Color automatically transitions: Cyan (subsonic/normal) -> Amber (fast) -> Crimson (relativistic).
func set_vector(origin: Vector3, vector: Vector3, max_speed_scale: float = 20.0) -> void:
	var length: float = vector.length()
	if length < 0.001:
		visible = false
		_current_vector = Vector3.ZERO
		return
	
	visible = true
	_current_origin = origin
	_current_vector = vector
	
	var dir: Vector3 = vector / length
	# Build rotation basis orienting +Y along the vector direction
	var up: Vector3 = Vector3.BACK if absf(dir.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var right: Vector3 = dir.cross(up).normalized()
	var forward: Vector3 = right.cross(dir).normalized()
	
	transform.basis = Basis(right, dir, forward)
	transform.origin = origin
	if is_inside_tree():
		global_position = origin
	
	var actual_head_len: float = minf(head_length, length * 0.4)
	var shaft_len: float = length - actual_head_len
	
	# Scale and position shaft (CylinderMesh center is Y=0, height=1)
	_shaft_mesh_inst.scale = Vector3(1.0, shaft_len, 1.0)
	_shaft_mesh_inst.position = Vector3(0.0, shaft_len * 0.5, 0.0)
	
	# Scale and position cone head
	_head_mesh_inst.scale = Vector3(1.0, actual_head_len / head_length, 1.0)
	_head_mesh_inst.position = Vector3(0.0, shaft_len + actual_head_len * 0.5, 0.0)
	
	# Dynamic color gradient based on speed
	var speed_ratio: float = clampf(length / max(max_speed_scale, 0.001), 0.0, 1.0)
	var arrow_color: Color
	if speed_ratio < 0.5:
		arrow_color = default_color.lerp(Color(1.0, 0.7, 0.0, 0.95), speed_ratio * 2.0)
	else:
		arrow_color = Color(1.0, 0.7, 0.0, 0.95).lerp(Color(1.0, 0.1, 0.3, 1.0), (speed_ratio - 0.5) * 2.0)
	
	_material.albedo_color = arrow_color

func get_vector() -> Vector3:
	return _current_vector

func get_origin() -> Vector3:
	return _current_origin

func hide_gizmo() -> void:
	visible = false
	_current_vector = Vector3.ZERO
