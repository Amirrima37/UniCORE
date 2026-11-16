extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/cad22/screenshots")
var w
func fail(message: String):push_error(message);quit(1)
func capture(name: String):
	for width in [1280,1920]:
		root.size=Vector2i(width,720 if width==1280 else 1080)
		for i in 6:await process_frame
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png(OUT+"/%s-%d.png" % [name,width])
	print("CAD22_GUI_STAGE ",name)
func _initialize():
	DirAccess.make_dir_recursive_absolute(OUT)
	w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	var error=w.document.open_project("res://docs/architecture/evidence/cad22/refined-hole.ucae")
	if not error.is_empty() or not w.results_current():fail("Refined project reopen: "+error);return
	w.selected=0;w.select_body(0);w.cad.set_view("Isometric",false);w.fit_model();w.open_gmsh_workspace()
	w.open_gmsh_settings(false)
	var panel=w.get_children().filter(func(child):return child.get_script()==load("res://ui/cae/gmsh_mesh_panel.gd"))[-1]
	await process_frame
	if panel.size.y>700 or panel.size.x>1200:fail("Mesh dialog exceeds supported 1280x720 layout");return
	await capture("global-settings")
	panel.queue_free();await process_frame
	var p=w.document.data.parts[0];var hole=p.mesh_settings.local[0].face;w.face.select(p.cad_faces.find(hole));w.show_selected_face()
	w.open_gmsh_settings(true);panel=w.get_children().filter(func(child):return child.get_script()==load("res://ui/cae/gmsh_mesh_panel.gd"))[-1]
	panel.rule_picker.select(0);panel.load_rule();await capture("local-face-refinement")
	# Exercise actual edit/apply, generation and solver from this graphical app.
	panel.numeric.curvature_points.value=26
	if not panel.apply_settings():fail("Mesh controls did not apply");return
	w.generate_analysis_mesh();var deadline=Time.get_ticks_msec()+180000;var heartbeat=0
	while w.external_mesh_thread!=null and Time.get_ticks_msec()<deadline:heartbeat+=1;await process_frame
	if not preload("res://core/cae/mesh_config.gd").current(w.document.data) or w.results_current():fail("Graphical remesh freshness");return
	w.show_results=false;w.mesh_visible=true;w.render_model();w.fit_model();await capture("refined-through-hole-mesh")
	w.open_gmsh_workspace();await capture("mesh-statistics")
	w.quality_metric="mean_ratio";w.set_inspection_mode("quality")
	deadline=Time.get_ticks_msec()+60000
	while not w.preparation_jobs.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	w.render_model();await capture("mean-ratio-quality")
	w.inspect_worst_mesh_element();await capture("worst-element-metrics")
	w.inspection_mode="";w.quality_metric="";w.solve();deadline=Time.get_ticks_msec()+180000
	while w.solve_thread!=null and Time.get_ticks_msec()<deadline:heartbeat+=1;await process_frame
	if not w.results_current():fail("Graphical refined CalculiX failed: "+w.status.text);return
	w.deformation_scale=w.automatic_deformation_scale();w.structural_wireframe=true
	w.select_result_field("displacement");await capture("refined-displacement")
	w.select_result_field("von_mises");await capture("refined-von-mises")
	var path=preload("res://tests/development_paths.gd").output_file("CAD/cad22/gui-refined.ucae")
	if w.document.save_project(path)!=OK or not w.document.open_project(path).is_empty() or not w.results_current():fail("Graphical settings save/reopen");return
	var f=FileAccess.open(preload("res://tests/development_paths.gd").output_file("CAD/cad22/gui-details.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"outcome":"PASS","heartbeat_frames":heartbeat,"nodes":w.document.data.mesh.nodes.size(),"tet4":w.document.data.mesh.elements.size(),"quality":w.document.data.mesh.quality.minimum_mean_ratio,"mesh_volume_error":w.document.data.mesh.quality.relative_volume_difference}));f.close()
	w.queue_free();await process_frame;print("CAD22_GUI_PASS");quit()
