extends RefCounted
const Display=preload("res://core/cae/mesh_display.gd")
const Colors=preload("res://core/cae/engineering_visuals.gd")
var records: Array=[]
var surface_cache := {}
var material_cache := {}
var timings := {}
func prepare(result: Dictionary) -> void:
	var start:=Time.get_ticks_usec()
	records=Display.surface_records(result)
	surface_cache.clear();material_cache.clear()
	timings.exterior_faces_ms=(Time.get_ticks_usec()-start)/1000.0
func point(result: Dictionary,id: int) -> Vector3:
	var p: Array=result.nodes[id];return Vector3(p[0],p[1],p[2])
func surface(result: Dictionary,values: Array,lo: float,hi: float,palette: String,element_centered := false,bands := 0,cache_key := "") -> ArrayMesh:
	if not cache_key.is_empty() and surface_cache.has(cache_key):return surface_cache[cache_key]
	var start:=Time.get_ticks_usec()
	var vertices:=PackedVector3Array();var colors:=PackedColorArray();var scalar:=PackedVector2Array()
	for record in records:
		for i in range(1,record.ids.size()-1):
			for id in [record.ids[0],record.ids[i],record.ids[i+1]]:
				vertices.append(point(result,id));scalar.append(Vector2(values[record.element] if element_centered else values[id],0));colors.append(Colors.color(values[record.element] if element_centered else values[id],lo,hi,palette,bands))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=scalar
	var mesh:=ArrayMesh.new()
	if not vertices.is_empty():mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if surface_cache.size()>=8:surface_cache.erase(surface_cache.keys()[0])
	if not cache_key.is_empty():surface_cache[cache_key]=mesh
	timings.surface_ms=(Time.get_ticks_usec()-start)/1000.0
	return mesh
func arrows(result: Dictionary,flux: Array,stride: int,scale: float,normalized: bool) -> ArrayMesh:
	var vertices:=PackedVector3Array()
	var maximum:=0.0
	for q in flux: maximum=maxf(maximum,Vector3(q[0],q[1],q[2]).length())
	for record_index in range(0,records.size(),maxi(1,stride)):
		var record: Dictionary=records[record_index]
		var index: int=record.element
		var q: Array=flux[index];var vector:=Vector3(q[0],q[1],q[2])
		if vector.length_squared()==0:continue
		var center:=Vector3.ZERO
		for id in record.ids:center+=point(result,id)
		center/=record.ids.size()
		var normal: Vector3=(point(result,record.ids[1])-point(result,record.ids[0])).cross(point(result,record.ids[2])-point(result,record.ids[0])).normalized()
		var cell_center:=Vector3.ZERO
		for id in result.elements[index]:cell_center+=point(result,id)
		cell_center/=result.elements[index].size()
		if normal.dot(center-cell_center)<0:normal=-normal
		center+=normal*scale*0.02
		var direction:=vector.normalized();var length: float=scale*(1 if normalized else vector.length()/maxf(maximum,1e-30))
		var end: Vector3=center+direction*length;var side:=direction.cross(Vector3.UP)
		if side.length()<0.01:side=direction.cross(Vector3.RIGHT)
		side=side.normalized()*length*0.2
		vertices.append_array(PackedVector3Array([center,end,end,end-direction*length*0.3+side,end,end-direction*length*0.3-side]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh:=ArrayMesh.new()
	if not vertices.is_empty():mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arrays)
	return mesh
func isolines(result: Dictionary,values: Array,lo: float,hi: float,count: int) -> ArrayMesh:
	var vertices:=PackedVector3Array()
	if hi>lo:
		for record in records:
			for t in range(1,count+1):
				var level:=lerpf(lo,hi,float(t)/(count+1));var intersections:=[]
				for j in record.ids.size():
					var a: int=record.ids[j];var b: int=record.ids[(j+1)%record.ids.size()]
					if (values[a]<level and values[b]>=level) or (values[b]<level and values[a]>=level): intersections.append(point(result,a).lerp(point(result,b),(level-values[a])/(values[b]-values[a])))
				if intersections.size()==2: vertices.append(intersections[0]);vertices.append(intersections[1])
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh:=ArrayMesh.new()
	if not vertices.is_empty():mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arrays)
	return mesh

func radiation_surface(result: Dictionary,field: String,lo: float,hi: float,values: Array=[]) -> ArrayMesh:
	var vertices:=PackedVector3Array();var colors:=PackedColorArray()
	for i in result.get("radiation_surface_nodes",[]).size():
		if result.surface_emissivity[i]<=0:continue
		for id in result.radiation_surface_nodes[i]:vertices.append(point(result,id));colors.append(Colors.color(result[field][i] if values.is_empty() else values[i],lo,hi,"temperature"))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh:=ArrayMesh.new()
	if not vertices.is_empty():mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
