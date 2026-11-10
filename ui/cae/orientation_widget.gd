extends Control
signal view_requested(title: String)
var camera: Camera3D
var endpoints: Array[Vector2] = []
func _ready() -> void:
	custom_minimum_size = Vector2(100,100)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "World axes (Y up). Click an axis for a standard view."
func _draw() -> void:
	if camera == null: return
	var origin := size/2
	endpoints.clear()
	var inverse := camera.global_transform.basis.inverse()
	for axis in 3:
		var v := Vector3.ZERO
		v[axis] = 1
		var projected: Vector3 = inverse*v
		var end := origin+Vector2(projected.x,-projected.y)*32
		endpoints.append(end)
		var color: Color = [Color("e57878"),Color("7dc48e"),Color("78a9e6")][axis]
		draw_line(origin,end,color,2,true)
		draw_circle(end,9,Color("252a30"))
		draw_string(ThemeDB.fallback_font,end+Vector2(-4,4),["X","Y","Z"][axis],HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in endpoints.size():
			if event.position.distance_to(endpoints[i]) < 13: view_requested.emit(["Right","Top","Front"][i])
		accept_event()
