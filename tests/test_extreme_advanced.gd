extends SceneTree
func _initialize():
	create_timer(60).timeout.connect(func():quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var rows:=[]
	for element in ["TET4","HEX8"]:
		for kind in ["pressure","gravity","prescribed"]:
			var doc=load("res://core/cae/cae_document.gd").new();doc.execute("CreatePart")
			doc.execute("AssignMaterialById",{"index":0,"material_id":"Aluminum 6061-T6"})
			doc.execute("SetAnalysis",{"analysis":{"type":"static_structural","element":element}})
			doc.execute("ApplySupport",{"index":0,"face":"X-"})
			if kind=="pressure":doc.execute("ApplyPressure",{"index":0,"face":"X+","value":1000})
			elif kind=="gravity":doc.execute("ApplyGravity",{"index":0,"values":[0,-9.81,0]})
			else:doc.execute("ApplyDisplacement",{"index":0,"face":"X+","values":[0.001,0,0]})
			doc.generate_mesh(2)
			var baseline: Dictionary=ClassDB.instantiate("UniCoreStructuralSolver").solve_model(doc.data);assert(baseline.ok)
			var manager=load("res://core/cae/extreme_jobs.gd").new();var directory: String=manager.launch(doc,1,256);assert(not directory.is_empty(),manager.last_error)
			while not FileAccess.file_exists(directory+"/results.json"):await process_frame
			var result: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"/results.json"));var error:=0.0
			for i in baseline.displacement.size():
				for j in 3:error=maxf(error,absf(baseline.displacement[i][j]-result.displacement_flat[i*3+j]))
			assert(error<1e-12)
			rows.append({"element":element,"load":kind,"displacement_error":error})
	var file:=FileAccess.open("res://docs/extreme-mode/advanced-loads.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"))
	print("HEX8/TET4 pressure, gravity and prescribed-displacement equivalence PASS");quit()
