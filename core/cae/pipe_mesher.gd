extends RefCounted
## Annular disk and conforming axial extrusion; FP64 coordinates.
## Conforming sorted-vertex prism split; SI FP64 arrays.
static func sub(a: Array,b: Array) -> Array:
	return [a[0]-b[0],a[1]-b[1],a[2]-b[2]]
static func determinant(a: Array,b: Array,c: Array) -> float:
	return a[0]*(b[1]*c[2]-b[2]*c[1])-a[1]*(b[0]*c[2]-b[2]*c[0])+a[2]*(b[0]*c[1]-b[1]*c[0])
static func transform(p: Array,part: Dictionary) -> Array:
	var r: Array=part.get("rotation",[0,0,0])
	var scale: Array=part.get("scale",[1,1,1])
	var x: float=p[0]*scale[0]; var y: float=p[1]*scale[1]; var z: float=p[2]*scale[2]
	var a: float=x*cos(r[2])-y*sin(r[2]); var b: float=x*sin(r[2])+y*cos(r[2])
	var c: float=b*sin(r[0])+z*cos(r[0]); b=b*cos(r[0])-z*sin(r[0])
	return [a*cos(r[1])+c*sin(r[1])+part.position[0],b+part.position[1],-a*sin(r[1])+c*cos(r[1])+part.position[2]]
static func generate(data: Dictionary,density: int) -> Dictionary:
	var start:=Time.get_ticks_usec()
	if density<1 or density>8: return {"error":"Pipe density must be 1…8"}
	if data.parts.size()!=1: return {"error":"Pipe requires exactly one body"}
	var sectors:=16*density
	var stride:=(density+1)*sectors
	var nodes: Array=[]; var elements: Array=[]; var owners: Array=[]; var regions: Dictionary={}
	var min_det:=INF; var volume:=0.0; var max_aspect:=1.0
	for part in data.parts:
		if part.kind!="Pipe": return {"error":"Pipe path requires pipe-only bodies; mixed primitives are not yet supported"}
		for key in ["scale","position","rotation"]:
			var vector=part.get(key,[0,0,0] if key!="scale" else [1,1,1])
			if not vector is Array or vector.size()!=3: return {"error":"Pipe transform requires three components: "+key}
			for value in vector:
				if not (value is float or value is int) or not is_finite(float(value)): return {"error":"Pipe transform must be finite: "+key}
		var scale: Array=part.get("scale",[1,1,1])
		if scale[0]!=scale[2] or scale.min()<=0: return {"error":"Pipe requires positive equal radial X/Z scaling"}
		if not is_finite(float(part.dimensions[0])) or not is_finite(float(part.dimensions[1])) or part.dimensions[0]<=0 or part.dimensions[1]<=0: return {"error":"Pipe dimensions must be positive"}
		var inner: float=part.get("inner_diameter",0)*0.5
		var outer: float=part.dimensions[0]*0.5
		if not is_finite(inner) or inner<=0 or inner>=outer: return {"error":"Pipe requires 0 < inner radius < outer radius"}
		var angular_request: float=ceil(TAU*outer*density/(outer-inner)/16)*16
		if not is_finite(angular_request) or angular_request>10000: return {"error":"Pipe circumferential subdivision limit"}
		sectors=maxi(sectors,int(angular_request));stride=(density+1)*sectors
		var requested: float=ceil(part.dimensions[1]*scale[1]/((outer-inner)*scale[0]/density))
		if not is_finite(requested) or requested>10000: return {"error":"Pipe axial subdivision limit: 10000"}
		var axial:=maxi(1,int(requested))
		if not is_finite(float(axial)) or axial>10000 or nodes.size()+stride*(axial+1)>10000:
			return {"error":"Pipe node limit: 10000; reduce density or length/radius ratio"}
		if 6*density*sectors*axial>50000: return {"error":"Pipe element limit: 50000"}
		var offset:=nodes.size()
		var groups: Dictionary={"InletEnd":[],"OutletEnd":[],"InnerWall":[],"OuterWall":[]}
		var triangles: Array=[]
		var disk: Array=[]
		for ring in density+1:
			for j in sectors:
				var angle:=TAU*j/sectors
				var radius:=inner+(outer-inner)*ring/density
				disk.append([radius*cos(angle),radius*sin(angle)])
		for ring in density:
			for j in sectors:
				var a:=ring*sectors+j;var b:=ring*sectors+(j+1)%sectors
				var c:=a+sectors;var d:=b+sectors
				triangles.append([a,c,d]);triangles.append([a,d,b])
		for layer in axial+1:
			var y: float=part.dimensions[1]*(float(layer)/axial-0.5)
			for point in stride:
				var local: Array=[disk[point][0],y,disk[point][1]]
				var id:=nodes.size(); nodes.append(transform(local,part))
				if layer==0: groups.InletEnd.append(id)
				if layer==axial: groups.OutletEnd.append(id)
				if point<sectors: groups.InnerWall.append(id)
				if point>stride-sectors-1: groups.OuterWall.append(id)
		for layer in axial:
			for tri in triangles:
				var sorted: Array=tri.duplicate(); sorted.sort()
				var a: int=offset+layer*stride+sorted[0]; var b: int=offset+layer*stride+sorted[1]; var c: int=offset+layer*stride+sorted[2]
				for tet in [[a,b,c,c+stride],[a,b,b+stride,c+stride],[a,a+stride,b+stride,c+stride]]:
					var det:=determinant(sub(nodes[tet[1]],nodes[tet[0]]),sub(nodes[tet[2]],nodes[tet[0]]),sub(nodes[tet[3]],nodes[tet[0]]))
					if det<0: var swap=tet[1]; tet[1]=tet[2]; tet[2]=swap; det=-det
					if not is_finite(det) or det<=1e-24: return {"error":"Degenerate pipe tetrahedron; change dimensions/density"}
					min_det=minf(min_det,det); volume+=det/6
					var shortest:=INF; var longest:=0.0
					for edge in [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]]:
						var delta:=sub(nodes[tet[edge[0]]],nodes[tet[edge[1]]])
						var length:=sqrt(delta[0]*delta[0]+delta[1]*delta[1]+delta[2]*delta[2])
						shortest=minf(shortest,length); longest=maxf(longest,length)
					max_aspect=maxf(max_aspect,longest/shortest)
					elements.append(tet); owners.append(part.id)
		regions[part.id]=groups
	var surfaces: Dictionary={}
	var exterior: Array=preload("res://core/cae/mesh_display.gd").exterior_faces(elements)
	for body in regions:
		surfaces[body]={"InletEnd":[],"OutletEnd":[],"InnerWall":[],"OuterWall":[]}
		for triangle in exterior:
			for region in regions[body]:
				if triangle.all(func(id): return regions[body][region].has(id)): surfaces[body][region].append(triangle)
	return {"mesh":{"surface_regions":surfaces,"nodes":nodes,"elements":elements,"material_regions":owners,"regions":regions,"formulation":"TET4","divisions":density,"circumferential_sectors":sectors,"revision":data.revision,"geometry_backend":"annular_pipe_v1","quality":{"minimum_jacobian":min_det,"maximum_aspect_ratio":max_aspect,"inverted_elements":0,"degenerate_elements":0,"total_volume":volume,"connected_components":data.parts.size(),"generation_ms":(Time.get_ticks_usec()-start)/1000.0}}}
