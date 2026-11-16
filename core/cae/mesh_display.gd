extends RefCounted
## Topological exterior extraction. Shared volume faces never become exterior edges.
static func exterior_faces(elements: Array) -> Array:
	if not elements.is_empty() and elements[0].size()==10:
		var faces={}
		for c in elements:
			for local in [[0,2,1,6,5,4],[0,1,3,4,8,7],[1,2,3,5,9,8],[2,0,3,6,7,9]]:
				var a=c[local[0]];var b=c[local[1]];var d=c[local[2]];var ab=c[local[3]];var bd=c[local[4]];var da=c[local[5]]
				for tri in [[a,ab,da],[ab,b,bd],[da,bd,d],[ab,bd,da]]:
					var key=tri.duplicate();key.sort();var text=str(key)
					if faces.has(text):faces.erase(text)
					else:faces[text]=tri
		return faces.values()
	var faces := {}
	for cell in elements:
		var local: Array = [[0,2,1],[0,1,3],[1,2,3],[2,0,3]] if cell.size()==4 else [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]
		for face in local:
			var ids: Array = []
			for i in face: ids.append(cell[i])
			var sorted := ids.duplicate()
			sorted.sort()
			var key := Vector4i(sorted[0],sorted[1],sorted[2],sorted[3] if sorted.size()==4 else -1)
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
	if cell.size()==10:
		var q=quality(data,cell.slice(0,4));q["corner_shape_only"]=true;return q
	var p: Array[Vector3] = []
	for id in cell:
		var v = data.nodes[id]
		p.append(Vector3(v[0],v[1],v[2]))
	for v in p:
		if not v.is_finite():
			return {"mean_ratio":NAN,"edge_ratio":NAN,"jacobian_max":NAN,"jacobian":NAN,"volume":NAN,"aspect_ratio":NAN,"scaled_jacobian":NAN,"distortion":NAN,"inverted":false,"degenerate":false,"invalid":true,"status":"invalid (nonfinite coordinates)"}
	var edges: Array = [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]] if cell.size()==4 else [[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]]
	var shortest := INF
	var longest := 0.0
	for e in edges:
		var length: float = p[e[0]].distance_to(p[e[1]])
		shortest = minf(shortest,length)
		longest = maxf(longest,length)
	var mean_ratio := NAN
	var maximum := -INF
	var minimum := INF
	var volume := 0.0
	var scaled := INF
	if cell.size()==4:
		var a: Vector3 = p[1]-p[0]
		var b: Vector3 = p[2]-p[0]
		var c: Vector3 = p[3]-p[0]
		minimum = a.dot(b.cross(c))
		# q=12*(3*|V|)^(2/3)/sum(edge_length^2); regular tet=1.
		# Unsigned shape metric: orientation remains independently signed below.
		var edge_square_sum:=0.0
		for edge in edges: edge_square_sum+=p[edge[0]].distance_squared_to(p[edge[1]])
		mean_ratio=12.0*pow(absf(minimum)*0.5,2.0/3.0)/maxf(edge_square_sum,1e-300)
		maximum = minimum
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
					maximum = maxf(maximum,determinant)
					minimum = minf(minimum,determinant)
					volume += determinant
					scaled = minf(scaled,determinant/maxf(a.length()*b.length()*c.length(),1e-300))
	var degenerate := absf(minimum)<=pow(longest,3)*1e-12
	var aspect := longest/maxf(shortest,1e-300)
	var invalid := not (is_finite(minimum) and is_finite(volume) and is_finite(scaled) and is_finite(aspect))
	var status := "invalid" if invalid else "inverted" if minimum<0 else "degenerate" if degenerate else "warning" if scaled<0.2 or aspect>5 else "valid"
	return {"mean_ratio":mean_ratio,"edge_ratio":aspect,"invalid":invalid,"status":status,"jacobian_max":maximum,"jacobian":minimum,"volume":volume,"aspect_ratio":longest/maxf(shortest,1e-300),"scaled_jacobian":scaled,"distortion":1.0-scaled,"inverted":minimum<0,"degenerate":absf(minimum)<=pow(longest,3)*1e-12}

static func surface_records(data: Dictionary, progress := Callable()) -> Array:
	var records := {}
	for index in data.elements.size():
		if index%1024==0 and progress.is_valid() and not progress.call("Exterior faces %d / %d" % [index,data.elements.size()]):return []
		for ids in exterior_faces([data.elements[index]]):
			var sorted: Array = ids.duplicate()
			sorted.sort()
			var key := Vector4i(sorted[0],sorted[1],sorted[2],sorted[3] if sorted.size()==4 else -1)
			if records.has(key): records[key].count += 1
			else: records[key] = {"ids":ids,"element":index,"count":1}
	var result: Array = []
	for record in records.values():
		if record.count==1: result.append(record)
	return result
