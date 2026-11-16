extends SceneTree
var failures := 0
func check(ok: bool, title: String) -> void:
	if not ok: failures+=1; push_error(title)
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w)
	await process_frame
	w.set_active(true)
	w.create_part("Box")
	w.run_command("ApplySupport",{"face":"X-"})
	w.run_command("ApplyPressure",{"face":"X+","value":100})
	var catalog=load("res://core/cae/condition_catalog.gd")
	check(catalog.entries(w.document.data.parts[0]).size()==2,"Individual structural conditions")
	w.inspect_condition({"body":0,"key":"pressure"})
	check(is_instance_valid(w.face_highlight),"Condition target highlighting")
	var entry=catalog.entries(w.document.data.parts[0])[1]
	var args=catalog.edited_args(entry,[200])
	w.run_command(entry.command,args)
	check(w.document.data.parts[0].pressure.value==200,"Pressure edit")
	w.run_command("RemoveCondition",{"key":"pressure"})
	check(not w.document.data.parts[0].has("pressure"),"Individual deletion")
	w.document.undo()
	check(w.document.data.parts[0].pressure.value==200,"Undo condition deletion")
	w.document.redo()
	check(not w.document.data.parts[0].has("pressure"),"Redo deletion")
	w.document.undo()
	w.divisions.value=2
	w.generate_analysis_mesh()
	check(not w.document.data.mesh.is_empty(),"Box meshing")
	w.open_mesh_workspace()
	w.activate_mesh_pick("node")
	for i in 8: await process_frame
	check(w.mesh_pick_mode=="node","Node selection mode")
	w.activate_mesh_pick("element")
	check(w.mesh_pick_mode=="element","Element selection mode")
	w.fit_model()
	for i in 8: await process_frame
	w.inspect_mesh_click(w.camera.unproject_position(Vector3.ZERO))
	check(is_instance_valid(w.selection_highlight),"Actual element picking and highlighting")
	w.activate_mesh_pick("node")
	w.reset_mesh_selection()
	for node in w.mesh_inspection.data.nodes:
		var screen: Vector2=w.camera.unproject_position(Vector3(node[0],node[1],node[2]))
		var hit: Dictionary=w.mesh_inspection.pick(w.camera,screen,true,false)
		if not hit.is_empty() and hit.node_distance<14:
			w.inspect_mesh_click(screen)
			break
	check(is_instance_valid(w.selection_highlight),"Actual node picking and highlighting")

	w.solve()
	var deadline=Time.get_ticks_msec()+30000
	while w.solve_thread!=null and Time.get_ticks_msec()<deadline: await process_frame
	check(w.results_current(),"Structural solve")
	w.run_command("ApplyPressure",{"face":"X+","value":300})
	check(not w.results_current() and w.document.data.mesh.is_empty(),"Condition edit invalidates snapshots")
	w.run_command("ClearAnalysisConditions")
	w.document.execute("SetAnalysis",{"analysis":{"type":"steady_thermal","element":"TET4"}})
	w.run_command("AssignMaterial",{"material":{"name":"Conductor","E":210e9,"nu":0.3,"density":7850,"k":10,"cp":500}})
	w.run_command("ApplyThermalBoundary",{"boundary":{"kind":"temperature","face":"X-","value":300}})
	w.run_command("ApplyThermalBoundary",{"boundary":{"kind":"temperature","face":"X+","value":400}})
	w.run_command("ApplyThermalBoundary",{"boundary":{"kind":"radiation","face":"Y+","emissivity":0.5,"surroundings":300}})
	check(catalog.entries(w.document.data.parts[0]).size()==3,"Thermal condition entries")
	w.open_analysis_editor()
	w.analysis_editor.boundary.select(4)
	w.analysis_editor.refresh_fields()
	check(w.analysis_editor.captions[1].text.contains("Surroundings"),"Radiation editor fields")
	w.analysis_editor.hide()
	var revision=w.document.data.revision
	w.run_command("ApplyThermalBoundary",{"boundary":{"kind":"temperature","face":"X-","value":-1}})
	check(w.document.data.revision==revision,"Negative Kelvin rejected")
	w.divisions.value=2
	w.generate_analysis_mesh()
	w.solve()
	deadline=Time.get_ticks_msec()+30000
	while w.solve_thread!=null and Time.get_ticks_msec()<deadline: await process_frame
	check(w.results_current() and w.document.data.results.has("temperature"),"Thermal solve")
	var options={"preconditioner":"ic0","relative_tolerance":1e-11,"absolute_tolerance":1e-11,"max_iterations":20000,"threads":1,"memory_mb":256}
	var study={"type":"transient_thermal","element":"TET4","time_step":0.1,"steps":2,"initial_temperature":300,"extreme_solver":options}
	check(w.document.execute("SetAnalysis",{"analysis":study}).is_empty(),"Persist supported Extreme solver configuration")
	w.open_solver_configuration()
	w.open_analysis_editor()
	check(w.analysis_editor.current_settings().extreme_solver==options,"Analysis editor preserves advanced settings")
	w.analysis_editor.hide()
	w.document.generate_mesh(2)
	var manager=load("res://core/cae/extreme_jobs.gd").new()
	var directory: String=manager.launch(w.document,1,256)
	check(not directory.is_empty(),"Independent configured job launch: "+manager.last_error)
	if not directory.is_empty():
		deadline=Time.get_ticks_msec()+15000
		while manager.load_result(directory).is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		var configuration=JSON.parse_string(FileAccess.get_file_as_string(directory+"/configuration.json"))
		check(configuration is Dictionary and configuration.get("preconditioner")=="ic0" and absf(configuration.get("pcg_relative_tolerance",0)-1e-11)<1e-24,"Actual native configuration matches UI settings")
		var imported: Dictionary=manager.load_result(directory)
		check(not imported.is_empty(),"Completed result import")
		if not imported.is_empty(): w.document.data=imported; w.document.changed.emit()
		var flags:=PackedStringArray(["--job",ProjectSettings.globalize_path(directory+"/model.ucjob"),"--output",ProjectSettings.globalize_path(directory),"--pause-after","1"])
		flags.append_array(manager.solver_arguments(w.document.data))
		var code:=OS.execute(ProjectSettings.globalize_path("res://bin/unicore_solver.exe"),flags)
		check(code==3,"Physical-step checkpoint")
		check(manager.restart(directory,1,256),"Restart with preserved solver options")
		deadline=Time.get_ticks_msec()+15000
		while manager.load_result(directory).is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		check(not manager.load_result(directory).is_empty(),"Restart result import")
	w.document.save_project("res://.tools/stage3.ucae")
	var restored=load("res://core/cae/cae_document.gd").new()
	check(restored.open_project("res://.tools/stage3.ucae").is_empty(),"Study/result persistence")
	check(restored.data.analysis.type==w.document.data.analysis.type and restored.data.analysis.element==w.document.data.analysis.element,"Analysis type/formulation persistence")
	check(restored.data.analysis.extreme_solver.preconditioner=="ic0" and absf(restored.data.analysis.extreme_solver.relative_tolerance-1e-11)<1e-24,"Solver settings precision after project round-trip")
	w.workflow_check()
	print("Stage 3 failures=",failures)
	w.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
