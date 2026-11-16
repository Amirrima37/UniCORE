extends RefCounted
const Display = preload("res://core/cae/mesh_display.gd")
var records: Array = []
var full_records: Array=[]
var full_bvh := {}
var metrics: Array = []
var connectivity: Array = []
var contour_cache := {}
var contour_data_cache := {}
var statistics := {}
var bvh := {}
var geometry_cache := {}
var buffer_cache := {}
var invalid_bvh := {}
var current_section := 1.0
var timings := {}
var data: Dictionary
func prepare(mesh: Dictionary, progress := Callable(), reuse: Dictionary={}) -> bool:
	if progress.is_valid() and not progress.call("Exterior faces"): return false
	data = mesh
	current_section=1.0
	if not reuse.is_empty():
		metrics=reuse.metrics;connectivity=reuse.connectivity;statistics=reuse.statistics
		records=reuse.records;full_records=records;bvh=reuse.bvh;full_bvh=bvh
		timings={"reused_quality":true}
		return true
	var tick := Time.get_ticks_usec()
	records = Display.surface_records(mesh,progress)
	timings.faces_ms=(Time.get_ticks_usec()-tick)/1000.0
	tick=Time.get_ticks_usec()
	geometry_cache.clear()
	buffer_cache.clear()
	invalid_bvh.clear()
	if progress.is_valid() and not progress.call("Spatial acceleration"): return false
	bvh = build_bvh(records.duplicate())
	full_records=records;full_bvh=bvh
	timings.bvh_ms=(Time.get_ticks_usec()-tick)/1000.0
	tick=Time.get_ticks_usec()
	if progress.is_valid() and not progress.call("Connectivity"): return false
	metrics.clear()
	contour_cache.clear()
	contour_data_cache.clear()
	connectivity.clear()
	connectivity.resize(mesh.nodes.size())
	for id in connectivity.size(): connectivity[id] = []
	for element in mesh.elements.size():
		for id in mesh.elements[element]: connectivity[id].append(element)
	timings.connectivity_ms=(Time.get_ticks_usec()-tick)/1000.0
	tick=Time.get_ticks_usec()
	for id in mesh.elements.size():
		if id%256==0 and progress.is_valid() and not progress.call("Quality %d / %d" % [id,mesh.elements.size()]): return false
		metrics.append(Display.quality(mesh,mesh.elements[id]))
		if mesh.elements[id].size() in [4,10] and id<mesh.get("quality",{}).get("per_element",[]).size():
			var exact=mesh.quality.per_element[id]
			for key in ["jacobian","volume","mean_ratio","edge_ratio"]:metrics[-1][key]=exact[key]
			metrics[-1].jacobian_max=exact.jacobian
			if mesh.elements[id].size()==10:
				metrics[-1].jacobian_max=exact.jacobian_max;metrics[-1].quadratic_quality=exact.quadratic_quality
				metrics[-1].corner_mean_ratio=exact.corner_mean_ratio;metrics[-1].corner_shape_only=false
				metrics[-1].gauss_jacobian_min=exact.gauss_jacobian_min;metrics[-1].gauss_jacobian_max=exact.gauss_jacobian_max
	statistics={"hex":0,"tet":0,"invalid":0,"degenerate":0,"inverted":0,"warning":0}
	for id in metrics.size():
		statistics.hex+=int(mesh.elements[id].size()==8)
		statistics.tet+=int(mesh.elements[id].size() in [4,10])
		var q: Dictionary=metrics[id]
		statistics.invalid+=int(q.invalid or q.degenerate or q.inverted)
		statistics.degenerate+=int(q.degenerate)
		statistics.inverted+=int(q.inverted)
		statistics.warning+=int(q.status=="warning")
	timings.quality_ms=(Time.get_ticks_usec()-tick)/1000.0
	return true
func point(id: int) -> Vector3:
	var v = data.nodes[id]
	return Vector3(v[0],v[1],v[2])
func pick(camera: Camera3D, screen: Vector2, node_mode := false, invalid_only := false) -> Dictionary:
	var tree := bvh
	if invalid_only:
		if invalid_bvh.is_empty(): invalid_bvh=build_bvh(invalid_records())
		tree=invalid_bvh
	if tree.is_empty(): return {}
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var distance := INF
	var hit := {}
	for record in ray_records(origin,direction,tree):
		var ids: Array = record.ids
		for i in range(1,ids.size()-1):
			var intersection = Geometry3D.ray_intersects_triangle(origin,direction,point(ids[0]),point(ids[i]),point(ids[i+1]))
			if intersection == null: continue
			var d: float = origin.distance_to(intersection)
			if d>=distance: continue
			distance=d
			hit={"element":record.element,"face":ids,"position":intersection}
	if node_mode:
		var tolerance := maxf(14.0,camera.get_viewport().get_visible_rect().size.y*0.018)
		var span: float = camera.size if camera.projection==Camera3D.PROJECTION_ORTHOGONAL else maxf(0.000001,camera.global_position.distance_to(tree.bounds.get_center())+tree.bounds.size.length()/2.0)*tan(deg_to_rad(camera.fov)/2.0)*2.0
		var padding: float = span*tolerance/maxf(1,camera.get_viewport().get_visible_rect().size.y)
		var nearest_node := tolerance
		var seen := {}
		for record in ray_records(origin,direction,tree,padding):
			for id in record.ids:
				if seen.has(id): continue
				seen[id]=true
				var p := point(id)
				if camera.is_position_behind(p): continue
				if not hit.is_empty() and origin.distance_to(p)>distance+padding*2.0: continue
				var pixels := camera.unproject_position(p).distance_to(screen)
				if pixels<nearest_node:
					nearest_node=pixels
					hit={"element":record.element,"face":record.ids,"position":p,"node":id,"node_distance":pixels}
		return hit if hit.has("node") else {}
	if hit.is_empty(): return hit
	var nearest := INF
	for id in hit.face:
		var d: float = camera.unproject_position(point(id)).distance_to(screen)
		if d<nearest:
			nearest=d
			hit.node=id
	hit.node_distance=nearest
	return hit
func contour_data(metric: String, invalid_only := false, palette := "viridis", low := NAN, high := NAN, bands := 0) -> Dictionary:
	var cache_key := metric + str(invalid_only)+palette+str(low)+str(high)+str(bands)
	if contour_data_cache.has(cache_key): return contour_data_cache[cache_key]
	var lo := INF
	var hi := -INF
	var finite_count := 0
	for q in metrics:
		if not is_finite(float(q[metric])): continue
		finite_count+=1
		lo=minf(lo,float(q[metric]))
		hi=maxf(hi,float(q[metric]))
	if lo == INF: lo = 0.0; hi = 0.0
	if is_finite(low) and is_finite(high) and high>low: lo=low;hi=high
	var vertices:=PackedVector3Array()
	var colors:=PackedColorArray()
	var contour_records: Array = records
	if invalid_only: contour_records=invalid_records()
	for record in contour_records:
		if not finite_face(record): continue
		if invalid_only and not (metrics[record.element].inverted or metrics[record.element].degenerate or not is_finite(float(metrics[record.element][metric]))): continue
		var value: float = metrics[record.element][metric]
		var t := clampf((value-lo)/(hi-lo),0.0,1.0) if hi-lo>maxf(absf(lo),absf(hi))*1e-6 and is_finite(value) else 0.5
		var color := preload("res://core/cae/engineering_visuals.gd").color(value,lo,hi,palette,bands)
		var q: Dictionary = metrics[record.element]
		if not is_finite(value): color = Color.MAGENTA
		elif q.inverted: color = Color("d020e0")
		elif q.degenerate: color = Color("ffff00")
		elif q.status=="warning": color = Color("ff9900")
		for i in range(1,record.ids.size()-1):
			for id in [record.ids[0],record.ids[i],record.ids[i+1]]:
				colors.append(color)
				vertices.append(point(id))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	contour_data_cache[cache_key] = {"arrays":arrays,"min":lo,"max":hi,"finite_count":finite_count}
	return contour_data_cache[cache_key]

func contour(metric: String, invalid_only := false, palette := "viridis", low := NAN, high := NAN, bands := 0) -> Dictionary:
	var key := metric+str(invalid_only)+palette+str(low)+str(high)+str(bands)
	if contour_cache.has(key):return contour_cache[key]
	var resource_start:=Time.get_ticks_usec()
	var result: Dictionary=contour_data(metric,invalid_only,palette,low,high,bands).duplicate(false)
	var mesh:=ArrayMesh.new()
	if not result.arrays[Mesh.ARRAY_VERTEX].is_empty():mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result.arrays)
	result.mesh=mesh;contour_cache[key]=result
	timings.contour_resource_ms=(Time.get_ticks_usec()-resource_start)/1000.0
	return result

# Section removes whole cells above an X threshold and extracts the newly exposed boundary.
# It deliberately follows cell boundaries, preserving original FEM node and element IDs.
func section(fraction: float, progress := Callable()) -> void:
	if fraction==current_section: return
	current_section=fraction
	var section_start:=Time.get_ticks_usec()
	geometry_cache.clear()
	buffer_cache.clear()
	contour_cache.clear()
	contour_data_cache.clear()
	var lo := INF
	var hi := -INF
	for n in data.nodes:
		lo = minf(lo,n[0]); hi = maxf(hi,n[0])
	var cells: Array = []
	var ids: Array = []
	for id in data.elements.size():
		var center := 0.0
		for node in data.elements[id]: center += point(node).x
		center /= data.elements[id].size()
		if fraction >= 1.0 or center <= lerpf(lo,hi,fraction):
			cells.append(data.elements[id]); ids.append(id)
	records = Display.surface_records({"elements":cells},progress)
	for record in records: record.element = ids[record.element]
	bvh = build_bvh(records.duplicate())
	timings.section_ms=(Time.get_ticks_usec()-section_start)/1000.0

func build_bvh(items: Array, depth := 0) -> Dictionary:
	if depth==0:
		items=items.filter(func(record): return finite_face(record))
		for record in items:
			var box := AABB(point(record.ids[0]),Vector3.ZERO)
			for id in record.ids: box=box.expand(point(id))
			record.bounds=box.grow(0.000001)
			record.center=box.get_center()
	if items.is_empty(): return {}
	var bounds: AABB=items[0].bounds
	for record in items: bounds=bounds.merge(record.bounds)
	if items.size()<=12: return {"bounds":bounds,"items":items}
	var axis := bounds.size.max_axis_index()
	items.sort_custom(func(a,b): return a.center[axis]<b.center[axis])
	var middle := items.size()/2
	return {"bounds":bounds,"left":build_bvh(items.slice(0,middle),depth+1),"right":build_bvh(items.slice(middle),depth+1)}

func ray_records(origin: Vector3, direction: Vector3, tree: Dictionary, padding := 0.0) -> Array:
	if tree.is_empty() or tree.bounds.grow(padding).intersects_ray(origin,direction) == null: return []
	if tree.has("items"): return tree.items
	return ray_records(origin,direction,tree.left,padding) + ray_records(origin,direction,tree.right,padding)

func geometry_arrays(kind: String) -> Array:
	var buffer_start:=Time.get_ticks_usec()
	var vertices := PackedVector3Array()
	for id in data.nodes.size(): vertices.append(point(id) if point(id).is_finite() else Vector3.ZERO)
	var indices := PackedInt32Array()
	var edges := {}
	var nodes := {}
	for record in records:
		if not finite_face(record): continue
		for i in record.ids.size():
			var a: int = record.ids[i]
			var b: int = record.ids[(i+1)%record.ids.size()]
			edges[Vector2i(mini(a,b),maxi(a,b))] = true
			nodes[a] = true
		if kind == "solid":
			for i in range(1,record.ids.size()-1):
				for id in [record.ids[0],record.ids[i],record.ids[i+1]]: indices.append(id)
	if kind == "edges":
		for edge in edges: indices.append(edge.x); indices.append(edge.y)
	if kind == "nodes":
		for id in nodes: indices.append(id)
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	timings[kind+"_buffer_ms"]=(Time.get_ticks_usec()-buffer_start)/1000.0
	return arrays

func geometry(kind: String) -> Mesh:
	if geometry_cache.has(kind): return geometry_cache[kind]
	var arrays: Array=buffer_cache.get(kind,[])
	if arrays.is_empty(): arrays=geometry_arrays(kind); buffer_cache[kind]=arrays
	var mesh := ArrayMesh.new()
	if not arrays[Mesh.ARRAY_INDEX].is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS if kind=="nodes" else Mesh.PRIMITIVE_LINES if kind=="edges" else Mesh.PRIMITIVE_TRIANGLES,arrays)
	geometry_cache[kind] = mesh
	return mesh

func invalid_records() -> Array:
	var result: Array=[]
	for id in metrics.size():
		if metrics[id].inverted or metrics[id].degenerate or metrics[id].invalid:
			for face in Display.exterior_faces([data.elements[id]]): result.append({"ids":face,"element":id})
	return result

func finite_face(record: Dictionary) -> bool:
	for id in record.ids:
		if not point(id).is_finite(): return false
	return true

## Finite-only distribution, computed on request rather than every render update.
func quality_summary(metric: String) -> Dictionary:
	var values: Array=[]
	var sum:=0.0
	for q in metrics:
		var value: float=q.get(metric,NAN)
		if is_finite(value): values.append(value); sum+=value
	if values.is_empty(): return {"count":0}
	values.sort()
	var n:=values.size()
	var bins: Array=[0,0,0,0,0]
	for value in values:
		var index:=mini(4,int(5*(value-values[0])/(values[-1]-values[0]))) if values[-1]>values[0] else 0
		bins[index]+=1
	return {"count":n,"missing":metrics.size()-n,"min":values[0],"max":values[-1],"mean":sum/n,"median":(values[(n-1)/2]+values[n/2])/2.0,"bins":bins}

static func metric_label(metric: String) -> String:
	if metric=="quadratic_quality":return "TET10 corner shape * certified Jacobian bound ratio (dimensionless)"
	if metric=="mean_ratio":return "Corner/TET4 mean ratio (not curved-Jacobian certification)"
	return {"edge_ratio":"Longest/shortest edge ratio (lower is better)","aspect_ratio":"Longest/shortest edge ratio (lower is better)","mean_ratio":"TET4 mean ratio (higher is better; regular = 1)","scaled_jacobian":"Legacy scaled Jacobian (TET4 vertex 0)","volume":"Signed volume (m^3)","jacobian":"Signed det J (m^3)","distortion":"1 - legacy scaled Jacobian"}.get(metric,metric)
