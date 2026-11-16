extends SceneTree
const M=preload("res://core/cae/cylinder_mesher.gd")
const D=preload("res://core/cae/mesh_display.gd")
var rows: Array=[]
func verify(mesh: Dictionary, owner: String) -> Dictionary:
	var faces: Dictionary={}; var unique: Dictionary={}; var used: Dictionary={}
	var adjacency: Array=[]
	assert(mesh.material_regions.size()==mesh.elements.size())
	for e in mesh.elements.size():
		adjacency.append([])
		var cell: Array=mesh.elements[e]
		var key: Array=cell.duplicate(); key.sort()
		assert(not unique.has(str(key))); unique[str(key)]=true
		assert(mesh.material_regions[e]==owner)
		assert(M.determinant(M.sub(mesh.nodes[cell[1]],mesh.nodes[cell[0]]),M.sub(mesh.nodes[cell[2]],mesh.nodes[cell[0]]),M.sub(mesh.nodes[cell[3]],mesh.nodes[cell[0]]))>0)
		for id in cell: used[id]=true
		# Local face template is independent of production exterior extraction.
		for local in [[0,2,1],[0,1,3],[1,2,3],[2,0,3]]:
			var f: Array=[cell[local[0]],cell[local[1]],cell[local[2]]]
			key=f.duplicate(); key.sort()
			if not faces.has(str(key)): faces[str(key)]=[]
			faces[str(key)].append({"face":f,"element":e})
	assert(used.size()==mesh.nodes.size())
	var boundary: Dictionary={}
	for region in mesh.surface_regions[owner]:
		for face in mesh.surface_regions[owner][region]:
			var key: Array=face.duplicate(); key.sort()
			assert(not boundary.has(str(key)))
			boundary[str(key)]=region
	var exterior:=0
	for key in faces:
		var entries: Array=faces[key]
		assert(entries.size()==1 or entries.size()==2)
		if entries.size()==1:
			exterior+=1; assert(boundary.has(key))
		else:
			assert(not boundary.has(key))
			var a: Array=entries[0].face; var b: Array=entries[1].face
			var at: int=b.find(a[0])
			assert(b[(at+1)%3]==a[2] and b[(at+2)%3]==a[1])
			adjacency[entries[0].element].append(entries[1].element)
			adjacency[entries[1].element].append(entries[0].element)
	assert(boundary.size()==exterior)
	var visited: Dictionary={0:true}; var queue: Array=[0]; var cursor:=0
	while cursor<queue.size():
		for next in adjacency[queue[cursor]]:
			if not visited.has(next): visited[next]=true; queue.append(next)
		cursor+=1
	assert(visited.size()==mesh.elements.size())
	return {"nodes":mesh.nodes.size(),"elements":mesh.elements.size(),"components":1,"exterior":exterior}

func _initialize():
	var doc=load("res://core/cae/cae_document.gd").new()
	doc.execute("CreatePart",{"kind":"Cylinder","parameters":{"diameter":0.2,"length":0.4}})
	doc.execute("SetRotation",{"index":0,"values":[0.3,0.7,-0.4]})
	doc.execute("SetPosition",{"index":0,"values":[1,-2,3]})
	for density in range(1,9):
		print("Topology density ",density," generate")
		var result: Dictionary=M.generate(doc.data,density)
		assert(not result.has("error"))
		print("Topology density ",density," verify")
		var row:=verify(result.mesh,doc.data.parts[0].id); row.density=density
		var again: Dictionary=M.generate(doc.data,density).mesh
		for key in ["nodes","elements","material_regions","surface_regions","regions"]: assert(result.mesh[key]==again[key])
		rows.append(row)
		print("Topology density ",density," passed")
	for field in ["position","rotation","scale"]:
		for value in [NAN,INF,-INF]:
			var changed: Dictionary=doc.data.duplicate(true)
			changed.parts[0][field][0]=value
			assert(M.generate(changed,1).has("error"))
	for field in ["position","rotation","scale"]:
		for invalid in [[1,2],"invalid"]:
			var changed: Dictionary=doc.data.duplicate(true); changed.parts[0][field]=invalid
			assert(M.generate(changed,1).has("error"))
	for values in [[0,1,1],[-1,1,-1],[1,1,2]]:
		var changed: Dictionary=doc.data.duplicate(true); changed.parts[0].scale=values
		assert(M.generate(changed,1).has("error"))
	for length in [0.0,-1.0,NAN,INF,1e-30,1e10]:
		var changed: Dictionary=doc.data.duplicate(true); changed.parts[0].dimensions[1]=length
		assert(M.generate(changed,1).has("error"))
	var file=FileAccess.open("res://docs/workbench-2/stage6-topology.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	print("Stage6 topology density 1-8 and invalid transforms PASS")
	quit()
