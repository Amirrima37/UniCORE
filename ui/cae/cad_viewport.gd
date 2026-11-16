extends SubViewportContainer
signal body_picked(index: int, face: String)
signal camera_changed
var viewport: SubViewport
var scene_root: Node3D
var overlay_root: Node3D
var camera: Camera3D
var instances: Dictionary = {}
var geometry_keys: Dictionary = {}
var faces: Dictionary = {}
var triangle_faces: Dictionary = {}
var meshes: Array[MeshInstance3D] = []
var target := Vector3.ZERO
var orbit := Vector2(0.65, 0.45)
var distance := 2.5
var projection_name := "Perspective"
var transition: Tween
var geometry_builds := 0
var grid: MeshInstance3D
var grid_opacity := 0.25
var active := false

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	scene_root = Node3D.new()
	viewport.add_child(scene_root)
	overlay_root = Node3D.new()
	scene_root.add_child(overlay_root)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202429")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c1c9d2")
	environment.environment.ambient_light_energy = 0.65
	scene_root.add_child(environment)
	camera = Camera3D.new()
	camera.current = true
	camera.near = 0.001
	camera.far = 100
	scene_root.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-35,0)
	light.light_energy = 0.9
	scene_root.add_child(light)
	build_grid()
	gui_input.connect(navigate)
	resized.connect(invalidate)
	update_camera()

func set_active(value: bool) -> void:
	active = value
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if value else SubViewport.UPDATE_DISABLED
	viewport.gui_disable_input = not value
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	if not value: stop_transition()

func invalidate() -> void:
	if active: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func line_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	return material

func build_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-20,21):
		var v := float(i)*0.05
		mesh.surface_set_color(Color("444b53") if i%5 == 0 else Color("30363d"))
		mesh.surface_add_vertex(Vector3(v,0,-1))
		mesh.surface_add_vertex(Vector3(v,0,1))
		mesh.surface_add_vertex(Vector3(-1,0,v))
		mesh.surface_add_vertex(Vector3(1,0,v))
	for axis in 3:
		mesh.surface_set_color([Color("c45757"),Color("69a574"),Color("6295c9")][axis])
		mesh.surface_add_vertex(Vector3.ZERO)
		var point := Vector3.ZERO
		point[axis] = 0.2
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var grid_material := ShaderMaterial.new()
	grid_material.shader=preload("res://shaders/cae_grid.gdshader")
	grid_material.set_shader_parameter("opacity",grid_opacity)
	instance.material_override=grid_material
	grid=instance
	scene_root.add_child(instance)

func pipe_mesh(outer: float, inner: float, height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 48:
		var a := TAU*i/48.0
		var b := TAU*(i+1)/48.0
		var a0 := Vector3(cos(a)*outer,-height/2,sin(a)*outer)
		var a1 := a0 + Vector3.UP*height
		var b0 := Vector3(cos(b)*outer,-height/2,sin(b)*outer)
		var b1 := b0 + Vector3.UP*height
		var c0 := Vector3(cos(a)*inner,-height/2,sin(a)*inner)
		var c1 := c0 + Vector3.UP*height
		var d0 := Vector3(cos(b)*inner,-height/2,sin(b)*inner)
		var d1 := d0 + Vector3.UP*height
		for triangle in [[a0,a1,b1],[a0,b1,b0],[c0,d1,c1],[c0,d0,d1],[a1,c1,d1],[a1,d1,b1],[a0,d0,c0],[a0,b0,d0]]:
			var normal: Vector3 = (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).normalized()
			for point in triangle:
				surface.set_normal(normal)
				surface.add_vertex(point)
	return surface.commit()

func create_shape(p: Dictionary) -> Mesh:
	geometry_builds += 1
	var d: Array = p.dimensions
	match p.kind:
		"Box":
			var mesh := BoxMesh.new()
			mesh.size = Vector3(d[0],d[1],d[2])
			return mesh
		"Cylinder":
			var mesh := CylinderMesh.new()
			mesh.top_radius = d[0]/2
			mesh.bottom_radius = d[0]/2
			mesh.height = d[1]
			return mesh
		"Sphere":
			var mesh := SphereMesh.new()
			mesh.radius = d[0]/2
			mesh.height = d[0]
			return mesh
		"Pipe": return pipe_mesh(d[0]/2,p.inner_diameter/2,d[1])
		"CAD":
			var model: Dictionary=get_meta("cad_mesh",{})
			if model.is_empty() or not model.get("surface_regions",{}).has(p.id): return null
			var r = p.get("rotation",[0,0,0])
			var placement = Transform3D(Basis.from_euler(Vector3(r[0],r[1],r[2])),Vector3(p.position[0],p.position[1],p.position[2])).affine_inverse()
			var tool:=SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			triangle_faces[p.id]=[]
			for region in model.surface_regions[p.id]:
				var triangles=model.surface_regions[p.id][region]
				for triangle in triangles:
					triangle_faces[p.id].append(region)
					var points=[]
					for index in triangle:
						var xyz=model.nodes[int(index)];points.append(Vector3(xyz[0],xyz[1],xyz[2]))
					tool.set_normal(placement.basis * (points[1]-points[0]).cross(points[2]-points[0]).normalized())
					for index in triangle:
						var xyz: Array=model.nodes[int(index)]
						tool.add_vertex(placement * Vector3(xyz[0],xyz[1],xyz[2]))
			return tool.commit()
	return null

func sync_model(parts: Array, selected: int) -> void:
	invalidate()
	var alive := {}
	meshes.clear()
	for i in parts.size():
		var p: Dictionary = parts[i]
		alive[p.id] = true
		if not instances.has(p.id):
			var instance := MeshInstance3D.new()
			var material := StandardMaterial3D.new()
			material.roughness = 0.65
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			instance.material_override = material
			instances[p.id] = instance
			instance.set_meta("part_id", p.id)
			instance.set_meta("instance_uuid",p.get("instance_uuid",p.id))
			scene_root.add_child(instance)
		var instance: MeshInstance3D = instances[p.id]
		var key := JSON.stringify([p.kind,p.dimensions,p.get("inner_diameter",0),p.get("cad_sha256",""),p.position,p.get("rotation"),get_meta("cad_mesh",{}).get("element_tags",[]).size(),get_meta("cad_mesh",{}).get("nodes",[]).size()], "", true, true)
		if geometry_keys.get(p.id) != key:
			instance.mesh = create_shape(p)
			geometry_keys[p.id] = key
			faces[p.id] = instance.mesh.get_faces() if instance.mesh != null else PackedVector3Array()
		instance.position = Vector3(p.position[0],p.position[1],p.position[2])
		var rotation: Array = p.get("rotation",[0,0,0])
		var scale: Array = p.get("scale",[1,1,1])
		instance.rotation = Vector3(rotation[0],rotation[1],rotation[2])
		instance.scale = Vector3(scale[0],scale[1],scale[2])
		instance.visible = p.get("visible",true)
		instance.material_override.albedo_color = Color("e6b86b") if i == selected else Color("a1a7ae")
		meshes.append(instance)
	for id in instances.keys():
		if not alive.has(id):
			instances[id].queue_free()
			instances.erase(id)
			geometry_keys.erase(id)
			faces.erase(id)
			triangle_faces.erase(id)

func pick(point: Vector2) -> void:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var nearest := INF
	var selected := -1
	var selected_face := ""
	for i in meshes.size():
		var instance := meshes[i]
		if not instance.visible: continue
		var inverse := instance.global_transform.affine_inverse()
		var local_origin := inverse * origin
		var local_direction := (inverse.basis*direction).normalized()
		if instance.get_aabb().intersects_segment(local_origin, local_origin+local_direction*1000000) == null: continue
		var vertices: PackedVector3Array = faces[instance.get_meta("part_id")]
		for j in range(0,vertices.size(),3):
			var hit = Geometry3D.ray_intersects_triangle(local_origin,local_direction,vertices[j],vertices[j+1],vertices[j+2])
			if hit == null: continue
			var world: Vector3 = instance.global_transform * hit
			var length: float = world.distance_to(origin)
			if length >= nearest: continue
			nearest = length
			selected = i
			var normal: Vector3 = (vertices[j+1]-vertices[j]).cross(vertices[j+2]-vertices[j]).normalized()
			# Face signs come from local hit coordinates, independent of triangle winding.
			var axis := normal.abs().max_axis_index()
			selected_face = ["X","Y","Z"][axis] + ("+" if hit[axis] > 0 else "-")
			var table: Array=triangle_faces.get(instance.get_meta("part_id"),[])
			if not table.is_empty():
				selected_face=str(table[int(j/3)]) if int(j/3)<table.size() else ""
	body_picked.emit(selected,selected_face)

func update_camera() -> void:
	# Keep the clip-plane ratio bounded for small models on the compatibility renderer.
	camera.near = maxf(distance * 0.001, 0.000001)
	camera.far = maxf(distance * 100, 10)
	var direction := Vector3(sin(orbit.x)*cos(orbit.y),sin(orbit.y),cos(orbit.x)*cos(orbit.y))
	camera.position = target + direction*distance
	camera.look_at(target,Vector3.FORWARD if absf(direction.y) > 0.9999 else Vector3.UP)
	camera.size = distance*0.85
	if is_instance_valid(grid): grid.material_override.set_shader_parameter("fade_distance",distance*2.0)
	invalidate()
	camera_changed.emit()

func stop_transition() -> void:
	if transition != null: transition.kill()

func set_view(title: String, animate := true) -> void:
	stop_transition()
	projection_name = title
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE if title in ["Perspective","Isometric"] else Camera3D.PROJECTION_ORTHOGONAL
	# Isometric is the conventional parallel engineering view.
	if title == "Isometric": camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var destination: Vector2 = {"Front":Vector2(0,0),"Back":Vector2(PI,0),"Left":Vector2(-PI/2,0),"Right":Vector2(PI/2,0),"Top":Vector2(0,PI/2),"Bottom":Vector2(0,-PI/2),"Isometric":Vector2(PI/4,atan(1.0/sqrt(2.0))),"Perspective":Vector2(0.65,0.45)}.get(title,orbit)
	if not animate:
		orbit = destination
		update_camera()
		return
	var start := orbit
	transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transition.tween_method(func(t: float): orbit = start.lerp(destination,t); update_camera(),0.0,1.0,0.18)

func fit(selection := -1) -> void:
	var bounds := AABB()
	var found := false
	for i in meshes.size():
		if meshes[i].mesh==null or not meshes[i].visible or (selection >= 0 and selection != i): continue
		var box: AABB = meshes[i].global_transform * meshes[i].get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	target = bounds.get_center() if found else Vector3.ZERO
	if found:
		var diameter := maxf(bounds.size.length(),0.00001)
		var aspect := maxf(size.x,1.0)/maxf(size.y,1.0)
		var half_angle := atan(tan(deg_to_rad(camera.fov)*0.5)*minf(aspect,1.0))
		distance = diameter*0.56/maxf(sin(half_angle),0.01) if camera.projection==Camera3D.PROJECTION_PERSPECTIVE else diameter*1.12/(0.85*minf(aspect,1.0))
	else: distance=2.5
	update_camera()

func navigate(event: InputEvent) -> void:
	if not active: return
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE or (event.button_mask & MOUSE_BUTTON_MASK_RIGHT and event.shift_pressed):
			stop_transition()
			target += (-camera.global_transform.basis.x*event.relative.x + camera.global_transform.basis.y*event.relative.y)*distance/maxf(size.y,1)
			update_camera()
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			stop_transition()
			orbit += Vector2(-event.relative.x,event.relative.y)*0.008
			orbit.y = clampf(orbit.y,-1.565,1.565)
			update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(.002,distance*.88)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(100000,distance/0.88)
		elif event.button_index == MOUSE_BUTTON_LEFT: pick(event.position)
		update_camera()
	accept_event()
