extends SceneTree
func _initialize():
	create_timer(60).timeout.connect(func():quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var workspace=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(workspace);await process_frame
	workspace.set_active(true);workspace.create_part("Box")
	workspace.run_command("ApplySupport",{"face":"X-"});workspace.run_command("ApplyLoad",{"face":"X+","force":[1,0,0]})
	var manager=load("res://core/cae/extreme_jobs.gd").new()
	for kind in ["static_structural","transient_thermal"]:
		workspace.document.execute("SetAnalysis",{"analysis":{"type":kind,"time_step":0.1,"steps":3,"initial_temperature":400}})
		if kind=="transient_thermal":
			workspace.run_command("AssignMaterialById",{"material_id":"Stainless steel 316"})
			workspace.run_command("ApplyThermalBoundary",{"boundary":{"kind":"temperature","face":"X-","value":600}})
			workspace.run_command("ApplyThermalBoundary",{"boundary":{"kind":"radiation","face":"X+","emissivity":0.8,"surroundings":300}})
		workspace.document.generate_mesh(2)
		workspace.cad.set_active(false)
		var directory: String=manager.launch(workspace.document,2,256);assert(not directory.is_empty(),manager.last_error)
		while manager.status(directory).get("state","")!="Completed":await process_frame
		var rediscovered=load("res://core/cae/extreme_jobs.gd").new();assert(rediscovered.jobs().has(directory.get_file()))
		if kind=="transient_thermal":
			var code:=OS.execute(ProjectSettings.globalize_path("res://bin/unicore_solver.exe"),PackedStringArray(["--job",ProjectSettings.globalize_path(directory+"/model.ucjob"),"--output",ProjectSettings.globalize_path(directory),"--pause-after","1"]))
			assert(code==3 and manager.load_result(directory).is_empty())
			assert(manager.restart(directory,2,256))
			while manager.status(directory).get("state","")!="Completed":await process_frame
		var data: Dictionary=manager.load_result(directory);assert(not data.is_empty())
		workspace.document.data=data;workspace.document.changed.emit();workspace.inspection_mode="";workspace.quality_metric="";workspace.show_results=true;workspace.cad.set_active(true);workspace.overlay_key=[];workspace.render_model();workspace.show_result_inspector();workspace.fit_model()
		for i in 5:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/extreme-mode/"+kind+".png")
	workspace.queue_free();await process_frame
	print("Extreme GUI: launch, persistent discovery, import, minimal rendering and thermal restart PASS");quit()
