extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/cad21")
var rows=[]
var received={}
func completed(result: Dictionary):received=result
func fail(message: String):push_error(message);quit(1)
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	for name in ["fuse","step-cut"]:
		var error=w.document.open_project(OUT+"/"+name+".json")
		if not error.is_empty():fail(error);return
		while w.cad_preview_thread!=null:await process_frame
		var p=w.document.data.parts[0];w.selected=0
		var low=INF;var high=-INF
		for key in p.cad_faces:
			if p.cad_face_descriptors[key].type!="Plane":continue
			var center=p.cad_face_centers[key][1]
			if center<low:low=center;p.support=key
			if center>high:high=center;p.load_face=key
		if p.support==p.load_face or high<=low:fail("No axial end faces");return
		p.force=[0,1000,0];p.material.nu=0.0
		w.document.data.mesh=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/"+name+".mesh.json"))
		w.document.data.mesh.revision=w.document.data.revision
		w.solve();var deadline=Time.get_ticks_msec()+150000;var frames=0
		while w.solve_thread!=null and Time.get_ticks_msec()<deadline:frames+=1;await process_frame
		if not w.results_current():fail("Boolean CalculiX result stale/missing: "+w.status.text);return
		var r=w.document.data.results;var sum=Vector3.ZERO
		for reaction in r.reactions:sum+=Vector3(reaction[0],reaction[1],reaction[2])
		var imbalance=(sum+Vector3(0,1000,0)).length()/1000
		if imbalance>1e-5 or r.displacement.is_empty() or r.von_mises.is_empty():fail("Invalid Boolean result/equilibrium");return
		var volume=p.cad_volume;var revision=p.cad_geometry_revision
		var path=OUT+"/"+name+".ucae"
		if w.document.save_project(path)!=OK:fail("CAD save");return
		w.document.data={}
		if not w.document.open_project(path).is_empty() or not w.results_current():fail("CAD reopen stale");return
		if w.document.data.parts[0].cad_geometry_revision!=revision:fail("CAD revision changed");return
		var job=load("res://core/cae/cad_geometry_job.gd").new()
		var request={"model":w.document.data.parts[0].cad_model.duplicate(true),"part_id":p.id,"previous_faces":p.cad_face_descriptors,"quality":12}
		var worker=Thread.new();worker.start(func():return job.evaluate(request))
		while worker.is_alive():await process_frame
		var rebuilt=worker.wait_to_finish()
		if not rebuilt.get("ok",false) or absf(rebuilt.part.cad_volume/volume-1)>1e-8:fail("Graph reconstruction failed: "+str(rebuilt.get("error")));return
		var original=w.document.data.duplicate(true)
		w.document.data.parts[0].cad_model.nodes[0].position=[0.001,0,0]
		if w.results_current():fail("Changed CAD graph accepted as fresh");return
		w.document.data=original
		# Transactional graph replacement uses normal undo/redo and invalidates FEM.
		var changed=request.duplicate(true);changed.model.nodes[0].position=[0.001,0,0]
		worker=Thread.new();worker.start(func():return job.evaluate(changed))
		while worker.is_alive():await process_frame
		var edited=worker.wait_to_finish()
		if not edited.get("ok",false):fail("Edit recompute failed");return
		error=w.document.execute("CommitCADFeature",{"part":edited.part,"replace_ids":[p.id],"topology":edited.topology})
		if not error.is_empty() or w.results_current() or not w.document.data.mesh.is_empty():fail("CAD edit freshness invalidation");return
		w.document.undo()
		if not w.results_current():fail("Undo did not restore original result");return
		w.document.redo()
		if w.results_current():fail("Redo did not invalidate result");return
		rows.append({"case":name,"outcome":"PASS","backend":r.backend,"nodes":r.nodes.size(),"tet4":r.elements.size(),"maximum_displacement_m":r.max_displacement,"maximum_von_mises_Pa":r.von_mises.max(),"reaction_relative_imbalance":imbalance,"provenance":r.provenance,"save_reopen":true,"graph_reconstruction":true,"parameter_recompute":true,"undo_redo":true,"main_thread_frames":frames})
		var f=FileAccess.open(OUT+"/integration-receipt.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  ",true,true));f.close()
		print("CAD21_SOLVE ",name," ",r.max_displacement," equilibrium=",imbalance)
	# Actual workspace asynchronous publication rejects a changed document.
	while w.cad_preview_thread!=null:await process_frame
	var part=w.document.data.parts[0]
	w.start_cad_geometry({"model":part.cad_model.duplicate(true),"part_id":part.id,"quality":12},self)
	w.document.execute("Rename",{"index":0,"name":"Changed during CAD job"})
	var deadline=Time.get_ticks_msec()+60000
	while w.cad_geometry_thread!=null and Time.get_ticks_msec()<deadline:await process_frame
	if received.get("ok",true) or not received.get("error","").contains("stale"):fail("Stale CAD worker result accepted");return
	# Graph corruption is rejected before replacing the active document.
	var invalid={"schema":1,"units":"m","root":"cycle","nodes":[{"id":"cycle","type":"Cut","base":"cycle","tool":"other"},{"id":"other","type":"Box","dimensions":[1,1,1]}]}
	if preload("res://core/cae/cad_model.gd").validate(invalid).is_empty():fail("Cycle accepted");return
	w.queue_free();await process_frame;print("CAD21_INTEGRATION_PASS");quit()
