extends SceneTree
const Mesher=preload("res://core/cae/cylinder_mesher.gd")
const Display=preload("res://core/cae/mesh_display.gd")
func _initialize():
	var regular={"nodes":[[0,0,0],[1,0,0],[0.5,sqrt(3.0)/2,0],[0.5,sqrt(3.0)/6,sqrt(2.0/3)]]}
	for permutation in [[0,1,2,3],[3,0,2,1],[1,0,2,3]]:
		assert(abs(Display.quality(regular,permutation).mean_ratio-1)<1e-6)
	var right={"nodes":[[0,0,0],[1,0,0],[0,1,0],[0,0,1]]}
	assert(abs(Display.quality(right,[0,1,2,3]).mean_ratio-12*pow(0.5,2.0/3)/9)<1e-6)
	var doc=load("res://core/cae/cae_document.gd").new()
	doc.execute("CreatePart",{"kind":"Cylinder","parameters":{"length":0.4,"diameter":0.2}})
	assert(doc.generate_mesh(4).is_empty())
	var mesh: Dictionary=doc.data.mesh
	var again: Dictionary=Mesher.generate(doc.data,4).mesh
	for key in ["nodes","elements","regions","surface_regions","material_regions"]: assert(mesh[key]==again[key])
	var faces: Dictionary={}; var cells: Dictionary={}; var mean: Array=[]
	for cell in mesh.elements:
		var sorted: Array=cell.duplicate(); sorted.sort()
		assert(not cells.has(str(sorted))); cells[str(sorted)]=true
		assert(Mesher.determinant(Mesher.sub(mesh.nodes[cell[1]],mesh.nodes[cell[0]]),Mesher.sub(mesh.nodes[cell[2]],mesh.nodes[cell[0]]),Mesher.sub(mesh.nodes[cell[3]],mesh.nodes[cell[0]]))>0)
		mean.append(Display.quality(mesh,cell).mean_ratio)
		for face in Display.exterior_faces([cell]):
			var key: Array=face.duplicate();key.sort()
			faces[str(key)]=faces.get(str(key),0)+1
	var exterior:=0
	for count in faces.values():
		assert(count==1 or count==2)
		exterior+=int(count==1)
	var boundary: Dictionary={}
	for region in mesh.surface_regions[doc.data.parts[0].id].values():
		for face in region:
			var key: Array=face.duplicate(); key.sort()
			assert(faces[str(key)]==1 and not boundary.has(str(key)))
			boundary[str(key)]=true
	assert(boundary.size()==exterior)
	# Every generated node participates in a volume element.
	var used: Dictionary={}
	for cell in mesh.elements:
		for id in cell: used[id]=true
	assert(used.size()==mesh.nodes.size())
	mean.sort()
	var inspection=load("res://core/cae/mesh_inspection.gd").new()
	inspection.metrics=[{"mean_ratio":0.25},{"mean_ratio":0.5},{"mean_ratio":1.0},{"mean_ratio":NAN}]
	var summary: Dictionary=inspection.quality_summary("mean_ratio")
	assert(summary.count==3 and summary.missing==1)
	assert(summary.min==0.25 and summary.max==1.0 and summary.median==0.5)
	assert(abs(summary.mean-1.75/3)<1e-12 and summary.bins==[1,1,0,0,1])
	print("Stage6 topology/determinism/quality fixtures PASS; mean ratio min=",mean[0]," median=",mean[mean.size()/2])
	quit()
