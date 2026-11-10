extends Node3D

# Collider-free runtime picking for generated meshes and simulation-backed bodies.
const Rays = preload("res://core/physics/interaction/screen_raycaster.gd")
var dispatcher: Node
var modules: Node
var clock: Node
var bus: Node
var target: MeshInstance3D
var gravity: Node
var body_name := ""
var dragging := false
var was_paused := false
var anchor := Vector3.ZERO
var offset := Vector3.ZERO
var original := Vector3.ZERO
var original_state := {}
var mode := "Move"
var outline: MeshInstance3D
var panel: VBoxContainer
var fields := {}
var selection_key := ""
var debug_interaction := false
var initial_state := {}

func setup(owner_dispatcher: Node, manager: Node, time_controller: Node, event_bus: Node) -> void:
	dispatcher = owner_dispatcher
	modules = manager
	clock = time_controller
	bus = event_bus
	outline = MeshInstance3D.new()
	var box := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.1, 0.9, 1.0)
	box.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for axis in range(3):
		for a in [-0.5, 0.5]:
			for b in [-0.5, 0.5]:
				var start := Vector3.ZERO
				start[axis] = -0.5
				start[(axis + 1) % 3] = a
				start[(axis + 2) % 3] = b
				var end := start
				end[axis] = 0.5
				box.surface_add_vertex(start)
				box.surface_add_vertex(end)
	box.surface_end()
	outline.mesh = box
	add_child(outline)
	outline.hide()
	call_deferred("_attach_inspector")

func _attach_inspector() -> void:
	if not is_inside_tree():
		return
	var drawer := get_tree().root.find_child("PhysicsInspectorDrawer", true, false)
	if drawer:
		panel = VBoxContainer.new()
		drawer.section_entity_info.add_child(panel)

func snapshot() -> Dictionary:
	if is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree():
		return {"name": str(target.name), "position": target.global_position,
			"rotation": target.rotation_degrees, "scale": target.scale}
	if is_instance_valid(gravity) and not body_name.is_empty() and gravity.is_simulation_active:
		return gravity.get_editable_body(body_name)
	return {}

func clear_selection() -> void:
	_end_drag(false)
	target = null
	gravity = null
	body_name = ""
	selection_key = ""
	if is_instance_valid(outline):
		outline.hide()
	_rebuild_fields()
	if bus:
		bus.publish("physics_entity_selected", {})

func _process(_delta: float) -> void:
	var data := snapshot()
	if data.is_empty():
		if not selection_key.is_empty():
			clear_selection()
		return
	if is_instance_valid(target):
		var bounds := target.get_aabb()
		outline.global_transform = target.global_transform * Transform3D(Basis.IDENTITY.scaled(_positive(bounds.size, 0.01)), bounds.get_center())
	else:
		outline.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * float(data.radius) * 2.1), data.position)
	outline.show()
	for key in fields:
		var widgets: Array = fields[key]
		for i in range(widgets.size()):
			var widget = widgets[i]
			if widget is SpinBox and not widget.get_line_edit().has_focus():
				widget.set_value_no_signal(data[key][i] if data[key] is Vector3 else data[key])

func _unhandled_input(event: InputEvent) -> void:
	if dispatcher.current_tool_mode != 0 or Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var camera := get_viewport().get_camera_3d()
		if camera:
			pick(camera, event.position)
			var data := snapshot()
			if not data.is_empty():
				original = data.position
				original_state = data.duplicate(true)
				anchor = original
				var hit = Rays.cast_to_camera_facing_plane(camera, event.position, anchor)
				if hit != null:
					offset = original - hit
					dragging = true
					if clock:
						was_paused = clock.is_paused
						clock.set_paused(true)
			get_viewport().set_input_as_handled()

# An active gesture owns motion/release even when the pointer crosses the inspector.
func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_end_drag(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var camera := get_viewport().get_camera_3d()
		if not camera:
			_end_drag(false)
			return
		var data := snapshot()
		if data.is_empty():
			clear_selection()
			return
		if mode == "Move":
			var hit = Rays.cast_to_camera_facing_plane(camera, event.position, anchor)
			if hit != null:
				edit("position", hit + offset)
		elif mode == "Rotate" and is_instance_valid(target):
			edit("rotation", target.rotation_degrees + Vector3(event.relative.y, event.relative.x, 0))
		elif mode == "Scale":
			var factor := exp(clampf(event.relative.x * 0.01, -1.0, 1.0))
			if is_instance_valid(target):
				edit("scale", target.scale * factor)
			else:
				edit("radius", data.radius * factor)
		get_viewport().set_input_as_handled()

func _end_drag(cancel: bool) -> void:
	if dragging:
		if cancel:
			for property in ["position", "rotation", "scale", "radius"]:
				if original_state.has(property):
					edit(property, original_state[property])
		dragging = false
		if is_instance_valid(clock):
			clock.set_paused(was_paused)

func pick(camera: Camera3D, screen: Vector2) -> void:
	clear_selection()
	var ro := camera.project_ray_origin(screen)
	var rd := camera.project_ray_normal(screen)
	var best := camera.far
	if not is_instance_valid(modules):
		return
	for module in modules.get_active_modules():
		if module.get_module_id() in ["builtin_ground_plane", "builtin_avatar_locomotion"]:
			continue
		if module.has_method("get_editable_body") and module.is_simulation_active:
			var hit: Dictionary = module.find_body_near_ray(ro, rd, best)
			if not hit.is_empty():
				best = ro.distance_to(hit.position)
				gravity = module
				target = null
				body_name = hit.name
		for mesh in module.find_children("*", "MeshInstance3D", true, false):
			if not mesh.is_visible_in_tree() or mesh.mesh == null or mesh.global_transform.basis.determinant() == 0:
				continue
			var inverse: Transform3D = mesh.global_transform.affine_inverse()
			var hit = mesh.get_aabb().intersects_ray(inverse * ro, inverse.basis * rd)
			if hit is Vector3:
				var distance := ro.distance_to(mesh.global_transform * hit)
				if distance < best:
					best = distance
					target = mesh
					gravity = null
					body_name = ""
	var data := snapshot()
	if data.is_empty():
		return
	selection_key = str(target.get_instance_id()) if is_instance_valid(target) else body_name
	initial_state = data.duplicate(true)
	if debug_interaction:
		print("Picked ", data.name, " at ", data.position)
	_rebuild_fields()
	if bus:
		bus.publish("physics_entity_selected", {"entity_id": selection_key, "entity": data})

func edit(property: String, value: Variant) -> void:
	if is_instance_valid(target):
		match property:
			"position": target.global_position = value
			"rotation": target.rotation_degrees = value
			"scale": target.scale = _positive(value, 0.001)
			"name":
				if not str(value).strip_edges().is_empty(): target.name = str(value)
	elif is_instance_valid(gravity):
		if gravity.edit_body(body_name, property, value) and property == "name":
			body_name = str(value)
	if bus and not snapshot().is_empty():
		bus.publish("physics_entity_updated", {"entity_id": selection_key, "entity": snapshot()})

func entity_action(action: String) -> void:
	if action == "delete":
		if is_instance_valid(target):
			target.queue_free()
		elif is_instance_valid(gravity):
			gravity.remove_body_by_name(body_name)
		clear_selection()
	elif action == "reset":
		for property in initial_state:
			if property != "name":
				edit(property, initial_state[property])

func _rebuild_fields() -> void:
	fields.clear()
	if not is_instance_valid(panel):
		return
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	var data := snapshot()
	if data.is_empty():
		return
	var modes := OptionButton.new()
	for item in ["Move", "Rotate", "Scale"]:
		modes.add_item(item)
	modes.select(["Move", "Rotate", "Scale"].find(mode))
	modes.set_item_disabled(1, not is_instance_valid(target))
	if not is_instance_valid(target) and mode == "Rotate":
		mode = "Move"
		modes.select(0)
	modes.item_selected.connect(func(i: int): mode = modes.get_item_text(i))
	panel.add_child(modes)
	var name_field := LineEdit.new()
	name_field.text = data.name
	name_field.text_submitted.connect(func(v: String): edit("name", v))
	panel.add_child(name_field)
	var help := Label.new()
	help.text = "Drag to transform. Esc cancels. Enter confirms name."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(help)
	for property in ["position", "rotation", "scale", "velocity", "mass", "radius"]:
		if not data.has(property):
			continue
		var label := Label.new()
		label.text = property.capitalize() + (" (degrees)" if property == "rotation" else "")
		panel.add_child(label)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var widgets: Array = []
		var count := 3 if data[property] is Vector3 else 1
		for axis in range(count):
			var spin := SpinBox.new()
			spin.min_value = 0.001 if property in ["scale", "mass", "radius"] else -1000000.0
			spin.max_value = 1000000.0
			spin.step = 0.01
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.value = data[property][axis] if count == 3 else data[property]
			spin.value_changed.connect(_field_changed.bind(property, axis))
			row.add_child(spin)
			widgets.append(spin)
		fields[property] = widgets

func _field_changed(value: float, property: String, axis: int) -> void:
	var data := snapshot()
	if not data.has(property):
		return
	if data[property] is Vector3:
		var vector: Vector3 = data[property]
		vector[axis] = value
		edit(property, vector)
	else:
		edit(property, value)

func _exit_tree() -> void:
	_end_drag(false)
	if is_instance_valid(panel):
		panel.queue_free()

func _positive(v: Vector3, minimum: float) -> Vector3:
	return Vector3(maxf(v.x, minimum), maxf(v.y, minimum), maxf(v.z, minimum))

