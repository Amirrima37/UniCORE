extends SceneTree
func capture(w, name: String):
	if DisplayServer.get_name()=="headless":return
	for width in [1280,1920]:
		root.size=Vector2i(width,720 if width==1280 else 1080)
		for i in 5:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tests/development_paths.gd").godot_environment("workbench/%s-%d.png") % [name,width])
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w)
	await process_frame
	w.set_active(true)
	DirAccess.make_dir_recursive_absolute(preload("res://tests/development_paths.gd").godot_environment("workbench"))
	for kind in ["Box","Cylinder"]:
		w.document.data={"schema":1,"revision":0,"units":"m-N-Pa-kg","parts":[],"mesh":{},"results":{}}
		w.create_part(kind)
		w.document.execute("SetAnalysis",{"analysis":{"type":"static_structural","element":"TET4","backend":"calculix"}})
		var p=w.document.data.parts[0]
		assert(w.document.execute("ApplySupport",{"index":0,"face":"X-" if kind=="Box" else "Bottom"}).is_empty())
		assert(w.document.execute("ApplyLoad",{"index":0,"face":"X+" if kind=="Box" else "Top","force":[1000.0,0.0,0.0] if kind=="Box" else [0.0,1000.0,0.0]}).is_empty())
		w.divisions.value=2
		w.generate_analysis_mesh()
		while w.external_mesh_thread!=null:await process_frame
		if w.document.data.mesh.is_empty(): push_error("Missing Gmsh mesh");quit(1);return
		w.mesh_visible=true;w.show_results=false;w.fit_model();w.render_model()
		await capture(w,kind+"-mesh")
		w.open_analysis_editor()
		await capture(w,kind+"-backend")
		w.analysis_editor.hide()
		# Exercise the same adapter cancellation method used by the existing Cancel action.
		w.solve();w.native_solver.cancel()
		var cancellation_deadline=Time.get_ticks_msec()+150000
		while w.solve_thread!=null and Time.get_ticks_msec()<cancellation_deadline:await process_frame
		if not w.document.data.results.is_empty():push_error("Cancelled result published");quit(1);return
		w.solve()
		await capture(w,kind+"-execution")
		var deadline=Time.get_ticks_msec()+150000
		while w.solve_thread!=null and Time.get_ticks_msec()<deadline: await process_frame
		if not w.document.data.results.get("ok",false): push_error("No CalculiX Workbench result");quit(1);return
		if not w.results_current(): push_error("New result not current");quit(1);return
		w.fit_model()
		w.deformation_scale=w.automatic_deformation_scale()
		w.structural_wireframe=true
		for field in ["displacement","von_mises"]:
			w.select_result_field(field)
			if DisplayServer.get_name()!="headless":
				for width in [1280,1920]:
					root.size=Vector2i(width,720 if width==1280 else 1080)
					for i in 5: await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(preload("res://tests/development_paths.gd").godot_environment("workbench/%s-%s-%d.png") % [kind,field,width])
		var path=preload("res://tests/development_paths.gd").godot_environment("workbench/")+kind+".json"
		assert(w.document.save_project(path)==OK)
		assert(w.document.open_project(path).is_empty())
		assert(w.results_current())
		for key in ["geometry","material","mesh","load"]:
			var original=w.document.data.duplicate(true)
			match key:
				"geometry":w.document.data.parts[0].dimensions[0]*=1.1
				"material":w.document.data.parts[0].material.E*=2
				"mesh":w.document.data.mesh.nodes[0][0]+=0.01
				"load":w.document.data.parts[0].force[0]+=1
			assert(not w.results_current())
			w.document.data=original
		print("CALCULIX_WORKBENCH_PASS "+kind)
	w.queue_free();await process_frame;quit()

