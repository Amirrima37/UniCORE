extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/cad24-completion/gui-endurance")
var heartbeat=0
var maximum_frame_delta=0.0
var w
func _process(delta):
	heartbeat+=1;maximum_frame_delta=maxf(maximum_frame_delta,delta)
	return false
func fail(message: String):push_error(message);quit(1)
func _initialize():
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1280,720)
	w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	var error=w.document.open_project("res://docs/architecture/evidence/cad24-completion/step-scaled-tet2.ucae")
	if not error.is_empty():fail(error);return
	w.selected=0;w.select_body(0)
	var count=20 if OS.get_environment("UNICORE_CAD24_GUI_ENDURANCE_ITERATIONS").is_empty() else int(OS.get_environment("UNICORE_CAD24_GUI_ENDURANCE_ITERATIONS"))
	if count<20 or count>100:fail("GUI endurance workload must be 20..100 cycles");return
	for iteration in count:
		while w.cad_preview_thread!=null:await process_frame
		var before=heartbeat;var part=w.document.data.parts[0]
		var model=part.cad_model.duplicate(true);model.nodes[-1].position[0]=.101+.001*iteration
		var job=preload("res://core/cae/cad_geometry_job.gd").new();var worker=Thread.new();worker.start(func():return job.evaluate({"model":model,"part_id":part.id,"quality":8}))
		while worker.is_alive():await process_frame
		var evaluated=worker.wait_to_finish()
		if not evaluated.get("ok",false):fail(str(evaluated));return
		w.cad_preview=evaluated.preview
		error=w.document.execute("CommitCADFeature",{"part":evaluated.part,"replace_ids":[part.id],"topology":evaluated.topology})
		if not error.is_empty():fail(error);return
		if not w.document.data.mesh.is_empty() or w.results_current():fail("CAD edit retained stale CAE data");return
		part=w.document.data.parts[0];var low=INF;var high=-INF;var support="";var load_face=""
		for face in part.cad_faces:
			var y=float(part.cad_face_centers[face][1])
			if y<low:low=y;support=face
			if y>high:high=y;load_face=face
		for command in ["ApplySupport","ApplyLoad"]:
			error=w.document.execute(command,{"index":0,"face":support if command=="ApplySupport" else load_face,"force":[0,1000,0]})
			if not error.is_empty():fail(error);return
		w.selected=0;w.select_body(0);w.face.select(w.document.data.parts[0].cad_faces.find(load_face));w.show_selected_face()
		var solved=iteration%5==0 or iteration==count-1
		if solved:
			part=w.document.data.parts[0];part.mesh_settings=preload("res://core/cae/mesh_config.gd").defaults(.09);part.mesh_settings.schema=2;part.mesh_settings.order=1 if iteration%2==0 else 2
			w.document.data.analysis.element="TET4" if part.mesh_settings.order==1 else "TET10"
			while w.cad_preview_thread!=null:await process_frame
			w.generate_analysis_mesh()
			while w.external_mesh_thread!=null:await process_frame
			if not preload("res://core/cae/mesh_config.gd").current(w.document.data):fail(w.status.text);return
			w.solve()
			while w.solve_thread!=null:await process_frame
			if not w.results_current():fail(w.status.text);return
			var reaction=Vector3.ZERO
			for rf in w.document.data.results.reactions:reaction+=Vector3(rf[0],rf[1],rf[2])
			if (reaction+Vector3(0,1000,0)).length()/1000>1e-4:fail("Endurance reaction imbalance");return
		var saved=OUT+"/iteration-"+str(iteration)+".ucae"
		if w.document.save_project(saved)!=OK or not w.document.open_project(saved).is_empty():fail("Endurance save/reopen");return
		while w.cad_preview_thread!=null:await process_frame
		if solved and not w.results_current():fail("Endurance reopen freshness");return
		await process_frame;await process_frame
		var progress={"iteration":iteration,"heartbeat":heartbeat,"operation_heartbeat_frames":heartbeat-before,"maximum_frame_delta_s":maximum_frame_delta,"godot_static_memory_bytes":OS.get_static_memory_usage(),"node_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"solved":solved,"order":w.document.data.parts[0].mesh_settings.order if solved else 0,"result_current":w.results_current(),"archive_count":w.document.data.parts[0].get("cad_boundary_archive",[]).size()}
		var f=FileAccess.open(OUT+"/iteration-"+str(iteration)+".json",FileAccess.WRITE);f.store_string(JSON.stringify(progress));f.close()
		print("CAD24_GUI_ENDURANCE_ITERATION ",iteration)
	w.queue_free();await process_frame;print("CAD24_GUI_ENDURANCE_PASS");quit()
