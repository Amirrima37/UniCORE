extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/step-final")
var rows=[]
func record(name: String, ok: bool, detail: String="") -> bool:
	rows.append({"test":name,"outcome":"PASS" if ok else "FAIL","detail":detail})
	var f=FileAccess.open(OUT+"/workbench-lifecycle.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
	if not ok:push_error(name+": "+detail)
	return ok
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	var path="res://.tools/step-calculix/workbench/bar.ucae"
	if not record("open_completed_study",w.document.open_project(path).is_empty() and w.results_current()):quit(1);return
	var baseline=w.document.data.duplicate(true)
	# Validate physical-group rejection through the production solve adapter.
	var invalid=baseline.duplicate(true)
	invalid.mesh.groups[invalid.parts[0].id].erase(invalid.parts[0].support)
	var bridge=load("res://core/cae/calculix_workbench.gd").new()
	record("missing_boundary_group",not bridge.solve_model(invalid).get("ok",false))
	var installed=bridge.executable;bridge.executable="res://missing-calculix.exe"
	record("missing_solver_actionable",bridge.solve_model(baseline).get("error","").contains("Restore the pinned"))
	bridge.executable=installed
	for phase in ["mesh","solve"]:
		w.document.data=baseline.duplicate(true)
		if phase=="mesh":w.generate_analysis_mesh()
		else:w.document.data.parts[0].force[1]*=1.5;w.solve()
		var deadline=Time.get_ticks_msec()+15000
		var active=false;var frames=0
		while Time.get_ticks_msec()<deadline:
			frames+=1
			if w.native_solver!=null and not w.native_solver.directory.is_empty() and FileAccess.file_exists(w.native_solver.directory+"/running.json"):
				active=true;break
			if (phase=="mesh" and w.external_mesh_thread==null) or (phase=="solve" and w.solve_thread==null):break
			await process_frame
		record(phase+"_observed_owned_launch",active)
		record(phase+"_save_while_active",w.document.save_project(OUT+"/active-"+phase+".ucae")==OK)
		# Exercise rapid repeated launches while operation guard is active.
		var original_thread=w.external_mesh_thread if phase=="mesh" else w.solve_thread
		for repeat in 5:
			if phase=="mesh":w.generate_analysis_mesh()
			else:w.solve()
		record(phase+"_overlap_guard",original_thread==(w.external_mesh_thread if phase=="mesh" else w.solve_thread))
		w.native_solver.cancel()
		deadline=Time.get_ticks_msec()+15000
		while Time.get_ticks_msec()<deadline and (w.external_mesh_thread!=null or w.solve_thread!=null):frames+=1;await process_frame
		record(phase+"_cancel_join",w.external_mesh_thread==null and w.solve_thread==null)
		record(phase+"_main_thread_frames",frames>1,str(frames))
		if phase=="solve":record("cancelled_solve_not_published",not w.results_current())
		record(phase+"_reopen_after_cancel",w.document.open_project(path).is_empty() and w.results_current())
	# Normal graceful removal must cancel and join the owned solver.
	w.document.data.parts[0].force[1]*=2;w.solve()
	var deadline=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline and w.solve_thread!=null:
		if not w.native_solver.directory.is_empty() and FileAccess.file_exists(w.native_solver.directory+"/running.json"):break
		await process_frame
	var job=w.native_solver.directory
	w.queue_free();await process_frame;await process_frame
	var receipt=JSON.parse_string(FileAccess.get_file_as_string(job+"/receipt.json"))
	record("shutdown_owned_solver",receipt is Dictionary and receipt.get("state") in ["cancelled","completed"],str(receipt))
	var ok=rows.all(func(row):return row.outcome=="PASS")
	print("STEP_WORKBENCH_LIFECYCLE_","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
