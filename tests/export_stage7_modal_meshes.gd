extends SceneTree
func _initialize():
	var rows: Array=[]
	for density in [1,2,3]:
		var doc=load("res://core/cae/cae_document.gd").new()
		assert(doc.execute("CreatePart",{"kind":"Cylinder","parameters":{"diameter":0.2,"length":0.2}}).is_empty())
		assert(doc.generate_mesh(density).is_empty())
		var mesh: Dictionary=doc.data.mesh
		var repeat: Dictionary=load("res://core/cae/cylinder_mesher.gd").generate(doc.data,density).mesh
		assert(mesh.nodes==repeat.nodes and mesh.elements==repeat.elements)
		assert(mesh.quality.minimum_jacobian>0)
		rows.append({"density":density,"nodes":mesh.nodes,"elements":mesh.elements,"bottom":mesh.regions[doc.data.parts[0].id].Bottom})
	var file=FileAccess.open("res://.tools/stage7-modal-meshes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  ",true,true));file.close()
	print("Stage 6 cylinder modal fixtures: three densities, positive quality and exact repeated nodes/connectivity PASS")
	quit()
