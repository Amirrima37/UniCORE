class_name PeerMarker
extends Node3D

## UniCORE 3D Peer Presence Marker
## Отображает присутствие, направление взгляда и активность пира в пространстве.

var peer_id: int = 0
var peer_name: String = "UniNode"
var peer_color: Color = Color(0.0, 0.9, 1.0, 1.0)
var peer_activity: String = "idle"

var target_position: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO

@onready var direction_mesh: MeshInstance3D = get_node_or_null("DirectionMesh")
@onready var led_sphere: MeshInstance3D = get_node_or_null("LedSphere")
@onready var name_label: Label3D = get_node_or_null("NameLabel")
@onready var activity_label: Label3D = get_node_or_null("ActivityLabel")

func _ready() -> void:
	_ensure_components()
	_apply_color(peer_color)
	if name_label != null:
		name_label.text = peer_name
	if activity_label != null:
		activity_label.text = peer_activity

func _process(delta: float) -> void:
	var t: float = clampf(12.0 * delta, 0.0, 1.0)
	position = position.lerp(target_position, t)
	rotation.x = lerp_angle(rotation.x, target_rotation.x, t)
	rotation.y = lerp_angle(rotation.y, target_rotation.y, t)
	rotation.z = lerp_angle(rotation.z, target_rotation.z, t)

## Инициализация маркера параметрами узла
func setup(p_id: int, p_name: String, p_color: Color) -> void:
	peer_id = p_id
	peer_name = p_name
	peer_color = p_color
	_ensure_components()
	_apply_color(peer_color)
	if name_label != null:
		name_label.text = peer_name
		name_label.modulate = peer_color

## Обновление сетевого состояния (позиция, вращение, активность)
func update_state(new_state: Dictionary) -> void:
	if new_state.has("position"):
		var raw_pos = new_state["position"]
		if raw_pos is Vector3:
			target_position = raw_pos
		elif raw_pos is Array and raw_pos.size() >= 3:
			target_position = Vector3(float(raw_pos[0]), float(raw_pos[1]), float(raw_pos[2]))
			
	if new_state.has("rotation"):
		var raw_rot = new_state["rotation"]
		if raw_rot is Vector3:
			target_rotation = raw_rot
		elif raw_rot is Array and raw_rot.size() >= 3:
			target_rotation = Vector3(float(raw_rot[0]), float(raw_rot[1]), float(raw_rot[2]))
			
	if new_state.has("name"):
		peer_name = String(new_state["name"])
		if name_label != null:
			name_label.text = peer_name
			
	if new_state.has("color") and new_state["color"] is Color:
		peer_color = new_state["color"]
		_apply_color(peer_color)
		
	if new_state.has("activity"):
		peer_activity = String(new_state["activity"])
		var act_text: String = peer_activity
		if new_state.has("last_prompt") and not String(new_state["last_prompt"]).is_empty():
			act_text += " (" + String(new_state["last_prompt"]).left(25) + ")"
		if activity_label != null:
			activity_label.text = act_text

func _apply_color(c: Color) -> void:
	if direction_mesh != null:
		var dir_mat: StandardMaterial3D = StandardMaterial3D.new()
		dir_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dir_mat.albedo_color = Color(c.r, c.g, c.b, 0.7)
		dir_mat.emission_enabled = true
		dir_mat.emission = c
		dir_mat.emission_energy_multiplier = 2.0
		dir_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		direction_mesh.material_override = dir_mat

	if led_sphere != null:
		var led_mat: StandardMaterial3D = StandardMaterial3D.new()
		led_mat.albedo_color = c
		led_mat.emission_enabled = true
		led_mat.emission = c
		led_mat.emission_energy_multiplier = 3.5
		led_sphere.material_override = led_mat

	if name_label != null:
		name_label.modulate = c

func _ensure_components() -> void:
	if direction_mesh == null:
		var existing_dir: Node = get_node_or_null("DirectionMesh")
		if existing_dir is MeshInstance3D:
			direction_mesh = existing_dir
		else:
			direction_mesh = MeshInstance3D.new()
			direction_mesh.name = "DirectionMesh"
			var cylinder: CylinderMesh = CylinderMesh.new()
			cylinder.top_radius = 0.0
			cylinder.bottom_radius = 0.35
			cylinder.height = 0.8
			direction_mesh.mesh = cylinder
			direction_mesh.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			add_child(direction_mesh)

	if led_sphere == null:
		var existing_led: Node = get_node_or_null("LedSphere")
		if existing_led is MeshInstance3D:
			led_sphere = existing_led
		else:
			led_sphere = MeshInstance3D.new()
			led_sphere.name = "LedSphere"
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.12
			sphere.height = 0.24
			led_sphere.mesh = sphere
			led_sphere.position = Vector3(0.0, 0.6, 0.0)
			add_child(led_sphere)

	if name_label == null:
		var existing_nl: Node = get_node_or_null("NameLabel")
		if existing_nl is Label3D:
			name_label = existing_nl
		else:
			name_label = Label3D.new()
			name_label.name = "NameLabel"
			name_label.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			name_label.font_size = 28
			name_label.outline_size = 4
			name_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
			name_label.position = Vector3(0.0, 1.1, 0.0)
			name_label.text = peer_name
			add_child(name_label)

	if activity_label == null:
		var existing_al: Node = get_node_or_null("ActivityLabel")
		if existing_al is Label3D:
			activity_label = existing_al
		else:
			activity_label = Label3D.new()
			activity_label.name = "ActivityLabel"
			activity_label.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			activity_label.font_size = 18
			activity_label.outline_size = 2
			activity_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.7)
			activity_label.modulate = Color(0.8, 0.85, 0.9, 0.8)
			activity_label.position = Vector3(0.0, 0.85, 0.0)
			activity_label.text = peer_activity
			add_child(activity_label)
