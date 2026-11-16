extends SceneTree
func _initialize():
	create_timer(90).timeout.connect(func():quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var doc=load("res://core/cae/cae_document.gd").new();doc.execute("CreatePart")
	doc.execute("SetDimensions",{"index":0,"values":[1,1,1]});doc.execute("AssignMaterial",{"index":0,"material":{"name":"Patch","E":1000,"nu":0,"density":1}})
	doc.execute("ApplySupport",{"index":0,"face":"X-"});doc.execute("ApplyLoad",{"index":0,"face":"X+","force":[1,0,0]});doc.execute("SetAnalysis",{"analysis":{"type":"static_structural","element":"HEX8"}})
	var tick:=Time.get_ticks_usec();assert(doc.generate_mesh(16)=="");var mesh_ms:=(Time.get_ticks_usec()-tick)/1000.0
	var model: Dictionary=doc.data.duplicate(true);model.profile=true
	tick=Time.get_ticks_usec();var baseline: Dictionary=ClassDB.instantiate("UniCoreStructuralSolver").solve_model(model);var normal_wall:=(Time.get_ticks_usec()-tick)/1000.0;assert(baseline.ok)
	var samples:=[]
	for threads in [1,2,4]:
		var manager=load("res://core/cae/extreme_jobs.gd").new();tick=Time.get_ticks_usec();var path: String=manager.launch(doc,threads,512);var export_ms:=(Time.get_ticks_usec()-tick)/1000.0;assert(not path.is_empty(),manager.last_error)
		while not FileAccess.file_exists(path+"/results.json"):await process_frame
		var actual: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/results.json"));var error:=0.0
		for i in baseline.displacement.size():
			for j in 3:error=maxf(error,absf(baseline.displacement[i][j]-actual.displacement_flat[i*3+j]))
		assert(error<1e-10)
		samples.append({"threads":threads,"export_launch_ms":export_ms,"total_runtime_ms":actual.total_runtime_ms,"assembly_ms":actual.assembly_ms,"solve_ms":actual.solve_ms,"post_ms":actual.post_ms,"maximum_difference":error,"peak_working_set_bytes":actual.peak_working_set_bytes})
	var file:=FileAccess.open("res://docs/extreme-mode/normal-comparison.json",FileAccess.WRITE);file.store_string(JSON.stringify({"dof":doc.data.mesh.nodes.size()*3,"elements":4096,"mesh_ms":mesh_ms,"normal_wall_ms":normal_wall,"normal_core_ms":baseline.get("timings_ms",{}),"standalone":samples},"\t",true,true));print("Normal/standalone numerical and timing comparison PASS");quit()
