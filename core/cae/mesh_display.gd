extends RefCounted
## Topological exterior extraction. Shared volume faces never become exterior edges.
static func exterior_faces(elements: Array) -> Array:
	var faces := {}
	for cell in elements:
		var local: Array = [[0,2,1],[0,1,3],[1,2,3],[2,0,3]] if cell.size()==4 else [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]
		for face in local:
			var ids: Array = []
			for i in face: ids.append(cell[i])
			var sorted := ids.duplicate()
			sorted.sort()
			var key := str(sorted)
			if faces.has(key): faces[key].count += 1
			else: faces[key] = {"ids":ids,"count":1}
	var result: Array = []
	for entry in faces.values():
		if entry.count == 1: result.append(entry.ids)
	return result

static func boundary_edges(data: Dictionary) -> ArrayMesh:
	var edges := {}
	for face in exterior_faces(data.elements):
		for i in range(face.size()):
			var a: int = face[i]
			var b: int = face[(i+1)%face.size()]
			edges[Vector2i(mini(a,b),maxi(a,b))] = true
	var vertices := PackedVector3Array()
	for node in data.nodes: vertices.append(Vector3(node[0],node[1],node[2]))
	var indices := PackedInt32Array()
	for edge in edges:
		indices.append(edge.x)
		indices.append(edge.y)
	var mesh := ArrayMesh.new()
	if not indices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arrays)
	return mesh

static func quality(data: Dictionary, cell: Array) -> Dictionary:
	var p: Array[Vector3] = []
	for id in cell:
		var v = data.nodes[id]
		p.append(Vector3(v[0],v[1],v[2]))
	var edges: Array = [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]] if cell.size()==4 else [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]
	var shortest := INF
	var longest := 0.0
	for e in edges:
		var length: float = p[e[0]].distance_to(p[e[1]])
		shortest = minf(shortest,length)
		longest = maxf(longest,length)
	var minimum := INF
	var volume := 0.0
	var scaled := INF
	if cell.size()==4:
		var a: Vector3 = p[1]-p[0]
		var b: Vector3 = p[2]-p[0]
		var c: Vector3 = p[3]-p[0]
		minimum = a.dot(b.cross(c))
		volume = minimum/6.0
		scaled = minimum/maxf(a.length()*b.length()*c.length(),1e-300)
	else:
		var signs := [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1),Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)]
		var g := 1.0/sqrt(3.0)
		for x in [-g,g]:
			for y in [-g,g]:
				for z in [-g,g]:
					var a := Vector3.ZERO
					var b := Vector3.ZERO
					var c := Vector3.ZERO
					for i in 8:
						var s: Vector3 = signs[i]
						a += p[i]*s.x*(1+s.y*y)*(1+s.z*z)/8.0
						b += p[i]*s.y*(1+s.x*x)*(1+s.z*z)/8.0
						c += p[i]*s.z*(1+s.x*x)*(1+s.y*y)/8.0
					var determinant := a.dot(b.cross(c))
					minimum = minf(minimum,determinant)
					volume += determinant
					scaled = minf(scaled,determinant/maxf(a.length()*b.length()*c.length(),1e-300))
	return {"jacobian":minimum,"volume":volume,"aspect_ratio":longest/maxf(shortest,1e-300),"distortion":1.0-scaled,"inverted":minimum<0,"degenerate":absf(minimum)<=pow(longest,3)*1e-12}

static func surface_records(data: Dictionary) -> Array:
	var records := {}
	for index in data.elements.size():
		for ids in exterior_faces([data.elements[index]]):
			var sorted: Array = ids.duplicate()
			sorted.sort()
			var key := str(sorted)
			if records.has(key): records[key].count += 1
			else: records[key] = {"ids":ids,"element":index,"count":1}
	var result: Array = []
	for record in records.values():
		if record.count==1: result.append(record)
	return result
