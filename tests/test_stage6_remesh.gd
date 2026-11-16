extends SceneTree
func _initialize():
	var doc=load("res://core/cae/cae_document.gd").new()
	var jobs=load("res://core/cae/extreme_jobs.gd").new()
	doc.execute("CreatePart",{"kind":"Cylinder","parameters":{"diameter":0.2,"length":0.4}})
	doc.execute("AssignMaterialById",{"index":0,"material_id":"Aluminum 6061-T6"})
	doc.execute("ApplySupport",{"index":0,"face":"Bottom"})
	doc.execute("ApplyPressure",{"index":0,"face":"Top","value":-1.0})
	for name in ["Bottom","Top"]:
		doc.execute("ApplyThermalBoundary",{"index":0,"boundary":{"face":name,"kind":"temperature","value":300.0 if name=="Bottom" else 400.0}})
	assert(doc.generate_mesh(1).is_empty())
	var directory: String=jobs.launch(doc,1,256)
	assert(not directory.is_empty(),jobs.last_error)
	var deadline:=Time.get_ticks_msec()+15000
	while jobs.status(directory).get("state")!="Completed" and Time.get_ticks_msec()<deadline: await process_frame
	assert(not jobs.load_result(directory,doc.data).is_empty(),jobs.last_error)
	for edit in [{"command":"SetParameters","parameters":{"radius":0.12}},{"command":"SetParameters","parameters":{"length":0.5}},{"command":"SetRotation","values":[0.3,0.7,-0.4]},{"command":"SetPosition","values":[1,-2,3]},{"command":"density"}]:
		var before: Dictionary=doc.data.mesh
		if edit.command!="density":
			var args: Dictionary=edit.duplicate();args.index=0
			assert(doc.execute(edit.command,args).is_empty())
		assert(doc.generate_mesh(2 if edit.command=="density" else 1).is_empty())
		assert(before.nodes!=doc.data.mesh.nodes)
		assert(jobs.load_result(directory,doc.data).is_empty())
		assert(doc.data.parts[0].thermal.size()==2 and doc.data.parts[0].thermal[0].face=="Bottom" and doc.data.parts[0].thermal[1].face=="Top")
		assert(doc.data.parts[0].support=="Bottom" and doc.data.parts[0].pressure.face=="Top")
		for name in ["Bottom","Top"]:
			var regions: Dictionary=doc.data.mesh.regions[doc.data.parts[0].id]
			assert(not regions[name].is_empty())
			for face in doc.data.mesh.surface_regions[doc.data.parts[0].id][name]:
				for id in face: assert(regions[name].has(id))
	print("Stage6 semantic support/pressure preservation and stale import rejection: radius/length/rotation/translation/density PASS")
	quit()
