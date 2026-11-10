extends RefCounted
const Display = preload("res://core/cae/mesh_display.gd")
var records: Array = []
var metrics: Array = []
var data: Dictionary
func prepare(mesh: Dictionary) -> void:
	data = mesh
	records = Display.surface_records(mesh)
	metrics.clear()
	for cell in mesh.elements: metrics.append(Display.quality(mesh,cell))
func point(id: int) -> Vector3:
	var v = data.nodes[id]
	return Vector3(v[0],v[1],v[2])
func pick(camera: Camera3D, screen: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var distance := INF
	var hit := {}
	for record in records:
		var ids: Array = record.ids
		for i in range(1,ids.size()-1):
			var intersection = Geometry3D.ray_intersects_triangle(origin,direction,point(ids[0]),point(ids[i]),point(ids[i+1]))
			if intersection == null: continue
			var d: float = origin.distance_to(intersection)
			if d>=distance: continue
			distance=d
			hit={"element":record.element,"face":ids,"position":intersection}
	if hit.is_empty(): return hit
	var nearest := INF
	for id in hit.face:
		var d: float = camera.unproject_position(point(id)).distance_to(screen)
		if d<nearest:
			nearest=d
			hit.node=id
	hit.node_distance=nearest
	return hit
func contour(metric: String) -> Dictionary:
	var lo := INF
	var hi := -INF
	for q in metrics:
		lo=minf(lo,float(q[metric]))
		hi=maxf(hi,float(q[metric]))
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for record in records:
		var value: float = metrics[record.element][metric]
		var t := (value-lo)/(hi-lo) if hi>lo else 0.5
		var color := Color("3474ca").lerp(Color("e56742"),t)
		for i in range(1,record.ids.size()-1):
			for id in [record.ids[0],record.ids[i],record.ids[i+1]]:
				mesh.surface_set_color(color)
				mesh.surface_add_vertex(point(id))
	mesh.surface_end()
	return {"mesh":mesh,"min":lo,"max":hi}
