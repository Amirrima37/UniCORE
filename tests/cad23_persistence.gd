extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/cad23")
var rows=[]
func check(ok: bool,name: String) -> bool:
	rows.append({"test":name,"outcome":"PASS" if ok else "FAIL"})
	var f=FileAccess.open(OUT+"/persistence-details.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
	if not ok:push_error(name)
	return ok
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	var path=OUT+"/tet10-axial-bar.ucae"
	var open_error=w.document.open_project(path)
	if not open_error.is_empty():print("OPEN_ERROR ",open_error)
	if open_error.is_empty() and not w.results_current():
		var d=w.document.data;var r=d.results
		for key in d.parts[0]:
			if r.model_parts[0].get(key)!=d.parts[0][key]:print("PART_DIFF ",key," saved=",r.model_parts[0].get(key)," restored=",d.parts[0][key])
		print("CURRENT_DIAG revision ",r.get("revision"),"/",d.revision," parts ",r.get("model_parts")==d.parts," analysis ",r.get("model_analysis")==d.analysis," settings ",preload("res://core/cae/mesh_config.gd").current(d)," meshhash ",r.get("source_mesh_sha256")==preload("res://core/cae/mesh_fingerprint.gd").fingerprint(d.mesh)," divisions ",r.get("mesh_divisions"),"/",d.mesh.get("divisions"))
	if not check(open_error.is_empty() and w.results_current(),"TET10-current-save-reopen"):quit(1);return
	w.selected=0;var original=w.document.data.duplicate(true)
	for change in ["midpoint","connectivity","material","load","geometry","sizing","order","analysis"]:
		w.document.data=original.duplicate(true)
		match change:
			"midpoint":w.document.data.mesh.nodes[int(w.document.data.mesh.elements[0][4])][0]+=1e-7
			"connectivity":var c=w.document.data.mesh.elements[0];var id=c[4];c[4]=c[5];c[5]=id
			"material":w.document.data.parts[0].material.E*=1.01
			"load":w.document.data.parts[0].force[1]+=1
			"geometry":w.document.data.parts[0].cad_sha256="changed"
			"sizing":w.document.data.parts[0].mesh_settings.target_size*=1.1
			"order":w.document.data.parts[0].mesh_settings.order=1
			"analysis":w.document.data.analysis.element="TET4"
		check(not w.results_current(),"reject-"+change+"-without-revision")
	w.document.data=original.duplicate(true)
	var display=load("res://core/cae/structural_display.gd").new();var mapped=display.build(w.document.data.results,"strain_xx",1)
	check(not mapped.has("error") and mapped.mesh.get_surface_count()>0,"quadratic-strain-display")
	var cases=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/numerical.json"));var source=""
	for row in cases:
		if row.case=="axial-bar" and row.order==2 and row.level==3:source=row.solver_job
	var model=JSON.parse_string(FileAccess.get_file_as_string(source+"/canonical-model.json"));var dat=FileAccess.get_file_as_string(source+"/model.dat");var adapter=load("res://core/cae/calculix_backend.gd").new()
	check(not adapter.parse_dat(dat,model).has("error"),"complete-four-IP-DAT")
	check(adapter.parse_dat(dat.substr(0,dat.length()/2),model).has("error"),"reject-truncated-quadratic-DAT")
	check(adapter.parse_dat(dat+dat,model).has("error"),"reject-duplicate-quadratic-DAT")
	check(adapter.parse_dat(dat.replace("E+","bad+"),model).has("error"),"reject-malformed-quadratic-DAT")
	var oversized="user://cad23-oversized-dat-"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(oversized)
	var f=FileAccess.open(oversized+"/model.inp",FileAccess.WRITE);f.store_string("adversarial parser fixture");f.close()
	f=FileAccess.open(oversized+"/model.dat",FileAccess.WRITE);f.seek(32*1024*1024);f.store_8(0);f.close()
	check(adapter.import_results({"directory":oversized,"input_sha256":FileAccess.get_sha256(oversized+"/model.inp"),"model":model}).has("error"),"reject-oversized-quadratic-DAT-before-reading")
	# Unknown cached mesh schemas cannot be interpreted as quadratic connectivity.
	var bad=original.duplicate(true);bad.mesh.mesh_schema=99
	w.document.data=bad;var badpath=OUT+"/corrupt-schema.ucae";w.document.save_project(badpath);w.document.data=original.duplicate(true)
	check(not w.document.open_project(badpath).is_empty() and w.document.data==original,"reject-unknown-quadratic-schema-before-document-replacement")
	# Actual order switching and solver publication in the existing Workbench.
	for order in [1,2]:
		var config=w.document.data.parts[0].mesh_settings.duplicate(true);config.order=order;config.target_size=.07;config.max_size=.07
		check(w.document.execute("SetMeshSettings",{"index":0,"settings":config}).is_empty() and not w.results_current(),"order-switch-invalidates-"+str(order))
		w.generate_analysis_mesh()
		while w.external_mesh_thread!=null:await process_frame
		check(w.document.data.mesh.formulation==("TET10" if order==2 else "TET4"),"actual-order-generated-"+str(order))
		w.solve()
		while w.solve_thread!=null:await process_frame
		check(w.results_current(),"recalculated-order-current-"+str(order))
	var config=w.document.data.parts[0].mesh_settings.duplicate(true);config.target_size=.06
	w.document.execute("SetMeshSettings",{"index":0,"settings":config});var generation=w.document.data.mesh.generation_id;w.generate_analysis_mesh()
	config.target_size=.055;w.document.execute("SetMeshSettings",{"index":0,"settings":config})
	while w.external_mesh_thread!=null:await process_frame
	check(not w.results_current() and w.document.data.mesh.generation_id==generation,"reject-stale-quadratic-worker")
	w.queue_free();await process_frame;var ok=rows.all(func(r):return r.outcome=="PASS");print("CAD23_PERSISTENCE_","PASS" if ok else "FAIL");quit(0 if ok else 1)
