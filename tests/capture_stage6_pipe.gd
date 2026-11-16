extends SceneTree
func capture(w, field: String):
	w.fit_model();w.cad.distance*=0.4;w.cad.update_camera()
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		w.cad.invalidate()
		for i in 10: await process_frame
		# Avoid re-entering frame_post_draw from its own awaited callback.
		RenderingServer.force_draw()
		assert(root.get_texture().get_image().get_size()==resolution)
		root.get_texture().get_image().save_png("res://docs/workbench-2/stage6-pipe-%s-%d.png"%[field,resolution.x])
func _initialize():
	print("pipe graphics: construct")
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	print("pipe graphics: create")
	w.create_part("Pipe")
	w.run_command("SetParameters",{"parameters":{"outer_radius":0.1,"inner_radius":0.05,"length":0.1}})
	w.run_command("AssignMaterial",{"material":{"name":"Pipe reference","E":1000.0,"nu":0.25,"density":1.0,"k":10.0,"cp":1.0}})
	w.run_command("ApplySupport",{"face":"InletEnd"})
	w.run_command("ApplyLoad",{"face":"OutletEnd","force":[0,1,0]})
	w.divisions.value=4;w.generate_analysis_mesh()
	w.quality_metric="mean_ratio";w.set_inspection_mode("quality")
	var deadline:=Time.get_ticks_msec()+20000
	while w.inspection_mesh_key.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	assert(not w.inspection_mesh_key.is_empty())
	print("pipe graphics: mesh ready")
	await capture(w,"mesh")
	w.face.select(0);w.show_selected_face()
	assert(is_instance_valid(w.face_highlight))
	await capture(w,"inner_wall")
	w.face_highlight.queue_free()
	var jobs=load("res://core/cae/extreme_jobs.gd").new()
	for study in ["static_structural","steady_thermal"]:
		if study=="steady_thermal":
			w.document.execute("ClearAnalysisConditions",{"index":0})
			w.document.execute("SetAnalysis",{"analysis":{"type":study,"element":"TET4"}})
			pass
			w.run_command("ApplyThermalBoundary",{"boundary":{"face":"InnerWall","kind":"temperature","value":400.0}})
			w.run_command("ApplyThermalBoundary",{"boundary":{"face":"OuterWall","kind":"temperature","value":300.0}})
			w.generate_analysis_mesh()
		var directory: String=jobs.launch(w.document,1,256);assert(not directory.is_empty(),jobs.last_error)
		deadline=Time.get_ticks_msec()+15000
		while jobs.status(directory).get("state")!="Completed" and Time.get_ticks_msec()<deadline: await process_frame
		var loaded: Dictionary=jobs.load_result(directory,w.document.data);assert(not loaded.is_empty(),jobs.last_error)
		w.document.data=loaded;w.document.changed.emit()
		w.inspection_mesh_key="";w.thermal_display_key="";w.overlay_key=[]
		w.deformation_scale=1.0 if study=="static_structural" else 1.0
		w.structural_wireframe=true
		for field in (["displacement"] if study=="static_structural" else ["temperature","heat_flux"]):
			w.select_result_field("temperature" if field=="heat_flux" else field)
			if field=="heat_flux":w.thermal_field="heat_flux";w.overlay_key=[];w.render_model();w.show_result_inspector()
			w.active_ribbon="Results";w.populate_ribbon()
			await capture(w,field)
	w.queue_free();await process_frame
	print("Pipe real Workbench mesh/dialog/regions/structural/thermal graphics PASS")
	quit()
