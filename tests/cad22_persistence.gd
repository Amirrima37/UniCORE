extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/cad22")
const Config=preload("res://core/cae/mesh_config.gd")
var rows=[]
func check(ok: bool,name: String) -> bool:
	rows.append({"test":name,"outcome":"PASS" if ok else "FAIL"})
	var f=FileAccess.open(OUT+"/persistence-details.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
	if not ok:push_error(name)
	return ok
func native_pid_alive(pid: int) -> bool:
	var python=OS.get_environment("UNICORE_PYTHON");var output=[]
	return OS.execute(python,PackedStringArray([ProjectSettings.globalize_path("res://tests/cad22_pid_probe.py"),str(pid)]),output,true)==0
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	if not check(w.document.open_project("res://docs/architecture/evidence/cad21/fuse.json").is_empty(),"open-CAD21-compatibility"):quit(1);return
	while w.cad_preview_thread!=null:await process_frame
	w.selected=0;var p=w.document.data.parts[0];var low=INF;var high=-INF
	for face in p.cad_faces:
		var y=float(p.cad_face_centers[face][1])
		if y<low:low=y;p.support=face
		if y>high:high=y;p.load_face=face
	p.force=[0,1000,0]
	var config=Config.defaults(.04)
	config.local=[{"id":"end","face":p.load_face,"enabled":true,"needs_review":false,"mode":"face","size":.02,"dist_min":0,"dist_max":.03}]
	if not check(w.document.execute("SetMeshSettings",{"index":0,"settings":config}).is_empty(),"apply-settings-and-face-rule"):quit(1);return
	w.generate_analysis_mesh()
	while w.external_mesh_thread!=null:await process_frame
	if not check(Config.current(w.document.data),"generated-mesh-current"):quit(1);return
	w.solve()
	while w.solve_thread!=null:await process_frame
	if not check(w.results_current(),"genuine-CalculiX-current"):quit(1);return
	var path=OUT+"/persistence.ucae";var exact=Config.encode_numbers(w.document.data.parts[0].mesh_settings)
	if not check(w.document.save_project(path)==OK and w.document.open_project(path).is_empty() and w.results_current() and Config.current(w.document.data) and Config.encode_numbers(w.document.data.parts[0].mesh_settings)==exact,"lossless-settings-mesh-result-save-reopen"):quit(1);return
	var retained=w.document.data.mesh.duplicate(true);config.target_size=.03
	w.document.execute("SetMeshSettings",{"index":0,"settings":config})
	check(not Config.current(w.document.data) and not w.results_current() and w.document.data.mesh==retained,"settings-edit-retains-old-mesh-but-rejects-freshness")
	w.solve();check(w.solve_thread==null,"stale-mesh-solve-rejected")
	w.document.undo();check(w.results_current(),"undo-settings-restores-current-result")
	var healthy=w.document.data.duplicate(true)
	var old_generation=healthy.mesh.generation_id
	var first=config.duplicate(true);first.target_size=.025
	w.document.execute("SetMeshSettings",{"index":0,"settings":first});w.generate_analysis_mesh()
	check(w.document.save_project(OUT+"/save-while-meshing.ucae")==OK,"save-during-active-meshing")
	first.target_size=.035;w.document.execute("SetMeshSettings",{"index":0,"settings":first})
	while w.external_mesh_thread!=null:await process_frame
	check(w.document.data.mesh.generation_id==old_generation and not Config.current(w.document.data) and not w.results_current(),"reject-stale-asynchronous-mesh-publication-after-settings-edit")
	w.document.data=healthy.duplicate(true)
	var early_job=load("res://core/cae/calculix_workbench.gd").new();early_job.cancel()
	var early_worker=Thread.new();early_worker.start(func():return early_job.generate_mesh(healthy,.04))
	while early_worker.is_alive():await process_frame
	var cancelled=early_worker.wait_to_finish();var terminal=JSON.parse_string(FileAccess.get_file_as_string(early_job.directory+"/receipt.json"))
	check(cancelled.has("error") and terminal is Dictionary and terminal.get("state")=="cancelled","cancel-before-owned-mesh-launch")
	for corruption in ["schema","nan","face","encoding"]:
		var other=load("res://core/cae/cae_document.gd").new();other.data=healthy.duplicate(true)
		match corruption:
			"schema":other.data.parts[0].mesh_settings.schema=99
			"nan":other.data.parts[0].mesh_settings.target_size=NAN
			"face":other.data.parts[0].mesh_settings.local[0].face="unrelated"
		var bad=OUT+"/corrupt-"+corruption+".ucae";other.save_project(bad)
		if corruption=="encoding":
			var text=FileAccess.get_file_as_string(bad).replace("unicore-mesh-settings-v1","unknown-mesh-settings-v99")
			var f=FileAccess.open(bad,FileAccess.WRITE);f.store_string(text);f.close()
		var error=w.document.open_project(bad)
		check(not error.is_empty() and w.document.data==healthy,"reject-corrupt-"+corruption+"-without-document-replacement")
	# Recompute CAD with changed end face, preserving the user's invalidated rule.
	var model=healthy.parts[0].cad_model.duplicate(true);model.nodes[0].dimensions[0]*=1.1
	var job=load("res://core/cae/cad_geometry_job.gd").new();var worker=Thread.new()
	worker.start(func():return job.evaluate({"model":model,"part_id":healthy.parts[0].id,"previous_faces":healthy.parts[0].cad_face_descriptors,"quality":12}))
	while worker.is_alive():await process_frame
	var edited=worker.wait_to_finish()
	if not check(edited.get("ok",false),"CAD-edit-for-local-rule-safety"):quit(1);return
	var error=w.document.execute("CommitCADFeature",{"part":edited.part,"replace_ids":[healthy.parts[0].id],"topology":edited.topology})
	var rule=w.document.data.parts[0].mesh_settings.local[0]
	check(error.is_empty() and not rule.enabled and rule.needs_review and rule.face==config.local[0].face,"modified-face-rule-disabled-for-review-with-original-ID")
	while w.cad_preview_thread!=null:await process_frame
	var shutdown_settings=w.document.data.parts[0].mesh_settings.duplicate(true);shutdown_settings.target_size=.008;shutdown_settings.max_size=.008;shutdown_settings.min_size=.002
	w.document.execute("SetMeshSettings",{"index":0,"settings":shutdown_settings})
	w.generate_analysis_mesh();var deadline=Time.get_ticks_msec()+15000;var directory="";var running={}
	while Time.get_ticks_msec()<deadline and w.external_mesh_thread!=null:
		directory=w.native_solver.directory
		if not directory.is_empty() and FileAccess.file_exists(directory+"/running.json"):
			var state=JSON.parse_string(FileAccess.get_file_as_string(directory+"/running.json"))
			if state is Dictionary:running=state;break
		await process_frame
	var observed=native_pid_alive(int(running.get("pid",-1)))
	print("SHUTDOWN_OBSERVATION ",directory," pid=",running," native_active=",observed)
	check(not running.is_empty() and observed,"observe-owned-Gmsh-active-before-Workbench-shutdown")
	w.queue_free();await process_frame;await process_frame
	var shutdown=JSON.parse_string(FileAccess.get_file_as_string(directory+"/receipt.json"))
	check(shutdown is Dictionary and shutdown.get("state") in ["cancelled","completed"] and not native_pid_alive(int(running.get("pid",-1))),"safe-Workbench-shutdown-joins-owned-Gmsh-child")
	var ok=rows.all(func(row):return row.outcome=="PASS");print("CAD22_PERSISTENCE_","PASS" if ok else "FAIL");quit(0 if ok else 1)
