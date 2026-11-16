extends RefCounted
## Structured spherified cube. Shared grid vertices and six-tet Freudenthal split.
const Arithmetic=preload("res://core/cae/cylinder_mesher.gd")
const Display=preload("res://core/cae/mesh_display.gd")
static func generate(data: Dictionary,density: int) -> Dictionary:
	if density<1 or density>4: return {"error":"Sphere density must be 1..4"}
	if data.parts.size()!=1 or data.parts[0].kind!="Sphere": return {"error":"Sphere meshing supports one sphere only; mixed bodies unsupported"}
	var part: Dictionary=data.parts[0]
	for key in ["position","rotation","scale"]:
		var value=part.get(key)
		if not value is Array or value.size()!=3: return {"error":"Sphere requires three-component "+key}
		for component in value:
			if not (component is float or component is int) or not is_finite(float(component)): return {"error":"Sphere transform must be finite"}
	var scale: Array=part.scale
	if scale.min()<=0 or scale[0]!=scale[1] or scale[0]!=scale[2]: return {"error":"Sphere requires positive uniform scaling; ellipsoids unsupported"}
	var radius: float=part.dimensions[0]*0.5
	if not is_finite(radius) or radius<=0 or not is_finite(radius*scale[0]): return {"error":"Sphere radius must be positive and finite"}
	var n:=2*density; var side:=n+1
	if side*side*side>10000 or 6*n*n*n>50000: return {"error":"Sphere mesh resource limit"}
	var tick:=Time.get_ticks_usec()
	var nodes: Array=[];var elements: Array=[];var owners: Array=[];var local_y: Array=[]
	for k in side:
		for j in side:
			for i in side:
				var x:=2.0*i/n-1;var y:=2.0*j/n-1;var z:=2.0*k/n-1
				var p: Array=[radius*x*sqrt(1-y*y/2-z*z/2+y*y*z*z/3),radius*y*sqrt(1-z*z/2-x*x/2+z*z*x*x/3),radius*z*sqrt(1-x*x/2-y*y/2+x*x*y*y/3)]
				nodes.append(Arithmetic.transform(p,part));local_y.append(y)
	var volume:=0.0;var minimum:=INF
	for k in n:
		for j in n:
			for i in n:
				var a:=i+side*j+side*side*k
				var hex: Array=[a,a+1,a+1+side,a+side,a+side*side,a+side*side+1,a+side*side+side+1,a+side*side+side]
				for split in [[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6],[0,5,1,6]]:
					var tet: Array=[]
					for index in split: tet.append(hex[index])
					var det:=Arithmetic.determinant(Arithmetic.sub(nodes[tet[1]],nodes[tet[0]]),Arithmetic.sub(nodes[tet[2]],nodes[tet[0]]),Arithmetic.sub(nodes[tet[3]],nodes[tet[0]]))
					if det<0: var swap=tet[1];tet[1]=tet[2];tet[2]=swap;det=-det
					if not is_finite(det) or det<=1e-24: return {"error":"Degenerate sphere tetrahedron; change radius, position or density"}
					minimum=minf(minimum,det);volume+=det/6
					elements.append(tet);owners.append(part.id)
	var surfaces: Dictionary={"OuterSurface":[],"PositiveY":[],"NegativeY":[]}
	var groups: Dictionary={"OuterSurface":[],"PositiveY":[],"NegativeY":[]}
	var sets: Dictionary={"OuterSurface":{},"PositiveY":{},"NegativeY":{}}
	for face in Display.exterior_faces(elements):
		var y: float=local_y[face[0]]+local_y[face[1]]+local_y[face[2]]
		var hemisphere: String="PositiveY" if y>0 else "NegativeY"
		for region in ["OuterSurface",hemisphere]:
			surfaces[region].append(face)
			for id in face: sets[region][id]=true
	for region in sets:
		groups[region]=sets[region].keys();groups[region].sort()
	return {"mesh":{"nodes":nodes,"elements":elements,"material_regions":owners,"regions":{part.id:groups},"surface_regions":{part.id:surfaces},"formulation":"TET4","divisions":density,"revision":data.revision,"geometry_backend":"spherified_cube_v1","quality":{"total_volume":volume,"minimum_jacobian":minimum,"inverted_elements":0,"degenerate_elements":0,"generation_ms":(Time.get_ticks_usec()-tick)/1000.0}}}
