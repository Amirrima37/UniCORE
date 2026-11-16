extends RefCounted
## Graded polygon disk (8*r sectors per ring), balanced axial spacing.
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
	if density<1 or density>8: return {"error":"Cylinder density must be 1…8"}
	if data.parts.is_empty() or data.parts.size()>16: return {"error":"Cylinder body count must be 1…16"}
	var sectors:=8*density
	var stride:=1+4*density*(density+1)
	var nodes: Array=[]; var elements: Array=[]; var owners: Array=[]; var regions: Dictionary={}
	var min_det:=INF; var volume:=0.0; var max_aspect:=1.0
	for part in data.parts:
		if part.kind!="Cylinder": return {"error":"Cylinder path requires cylinder-only bodies; mixed primitives are not yet supported"}
		for key in ["scale","position","rotation"]:
			var vector=part.get(key,[0,0,0] if key!="scale" else [1,1,1])
			if not vector is Array or vector.size()!=3: return {"error":"Cylinder transform requires three components: "+key}
			for value in vector:
				if not (value is float or value is int) or not is_finite(float(value)): return {"error":"Cylinder transform must be finite: "+key}
		var scale: Array=part.get("scale",[1,1,1])
		if absf(scale[0]-scale[2])>1e-12 or scale.min()<=0: return {"error":"Cylinder requires positive equal radial X/Z scaling"}
		if not is_finite(float(part.dimensions[0])) or not is_finite(float(part.dimensions[1])) or part.dimensions[0]<=0 or part.dimensions[1]<=0: return {"error":"Cylinder dimensions must be positive"}
		var requested: float=ceil(part.dimensions[1]*scale[1]/(part.dimensions[0]*0.5*scale[0]/density))
		if not is_finite(requested) or requested>10000: return {"error":"Cylinder axial subdivision limit: 10000"}
		var axial:=maxi(1,int(requested))
		if not is_finite(float(axial)) or axial>10000 or nodes.size()+stride*(axial+1)>10000:
			return {"error":"Cylinder node limit: 10000; reduce density or length/radius ratio"}
		var offset:=nodes.size()
		var groups: Dictionary={"Bottom":[],"Top":[],"Lateral":[]}
		var triangles: Array=[]
		var disk: Array=[[0.0,0.0]]
		for ring in range(1,density+1):
			for j in 8*ring:
				var angle:=TAU*j/(8*ring)
				disk.append([float(ring)/density*cos(angle),float(ring)/density*sin(angle)])
		for j in 8: triangles.append([0,1+j,1+(j+1)%8])
		for ring in range(1,density):
			var n:=8*ring; var m:=8*(ring+1)
			var inner:=1+4*(ring-1)*ring; var outer:=1+4*ring*(ring+1)
			var i:=0; var j:=0
			while i<n or j<m:
				# Integer angle comparison gives reproducible zipper triangulation.
				if i<n and (j==m or (i+1)*m<=(j+1)*n):
					triangles.append([inner+i%n,inner+(i+1)%n,outer+j%m]); i+=1
				else:
					triangles.append([inner+i%n,outer+(j+1)%m,outer+j%m]); j+=1
		for layer in axial+1:
			var y: float=part.dimensions[1]*(float(layer)/axial-0.5)
			for point in stride:
				var local: Array=[disk[point][0]*part.dimensions[0]*0.5,y,disk[point][1]*part.dimensions[0]*0.5]
				var id:=nodes.size(); nodes.append(transform(local,part))
				if layer==0: groups.Bottom.append(id)
				if layer==axial: groups.Top.append(id)
				if point>stride-sectors-1: groups.Lateral.append(id)
		for layer in axial:
			for tri in triangles:
				var sorted: Array=tri.duplicate(); sorted.sort()
				var a: int=offset+layer*stride+sorted[0]; var b: int=offset+layer*stride+sorted[1]; var c: int=offset+layer*stride+sorted[2]
				for tet in [[a,b,c,c+stride],[a,b,b+stride,c+stride],[a,a+stride,b+stride,c+stride]]:
					var det:=determinant(sub(nodes[tet[1]],nodes[tet[0]]),sub(nodes[tet[2]],nodes[tet[0]]),sub(nodes[tet[3]],nodes[tet[0]]))
					if det<0: var swap=tet[1]; tet[1]=tet[2]; tet[2]=swap; det=-det
					if not is_finite(det) or det<=1e-24: return {"error":"Degenerate cylinder tetrahedron; change dimensions/density"}
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
		surfaces[body]={"Top":[],"Bottom":[],"Lateral":[]}
		for triangle in exterior:
			for region in regions[body]:
				if triangle.all(func(id): return regions[body][region].has(id)): surfaces[body][region].append(triangle)
	return {"mesh":{"surface_regions":surfaces,"nodes":nodes,"elements":elements,"material_regions":owners,"regions":regions,"formulation":"TET4","divisions":density,"revision":data.revision,"geometry_backend":"graded_polygonal_cylinder_v2","quality":{"minimum_jacobian":min_det,"maximum_aspect_ratio":max_aspect,"inverted_elements":0,"degenerate_elements":0,"total_volume":volume,"connected_components":data.parts.size(),"generation_ms":(Time.get_ticks_usec()-start)/1000.0}}}
