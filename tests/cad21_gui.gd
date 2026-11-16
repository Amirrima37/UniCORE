extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/cad21/screenshots")
var w
func fail(message: String):push_error(message);quit(1)
func capture(name: String):
	if DisplayServer.get_name()=="headless":return
	for width in [1280,1920]:
		root.size=Vector2i(width,720 if width==1280 else 1080)
		for i in 5:await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OUT+"/%s-%d.png" % [name,width])
	print("CAD21_GUI_STAGE ",name)
func wait_geometry():
	var deadline=Time.get_ticks_msec()+60000
	while w.cad_geometry_thread!=null and Time.get_ticks_msec()<deadline:await process_frame
func _initialize():
	DirAccess.make_dir_recursive_absolute(OUT)
	w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	w.create_part("Box");w.document.execute("SetDimensions",{"index":0,"values":[.1,.2,.1]})
	w.create_part("Cylinder");w.document.execute("SetDimensions",{"index":1,"values":[.04,.3,.04]})
	w.selected=0;w.active_ribbon="Geometry";w.populate_ribbon()
	w.open_cad_boolean(false)
	var panel=w.get_children().filter(func(child):return child.get_script()==load("res://ui/cae/cad_boolean_panel.gd"))[-1]
	panel.base_picker.select(0);panel.tool_picker.select(1);panel.operation.select(1)
	await capture("boolean-controls")
	panel.start_preview();await wait_geometry()
	if panel.pending.is_empty():fail("No Boolean preview: "+panel.message.text);return
	await capture("boolean-preview")
	panel.commit();await process_frame
	if w.document.data.parts.size()!=1 or not w.document.data.parts[0].has("cad_model"):fail("Boolean commit failed");return
	w.cad.set_view("Isometric",false);w.fit_model();await capture("boolean-solid-operation-tree")
	var p=w.document.data.parts[0];var low=INF;var high=-INF;var bottom="";var top=""
	for key in p.cad_faces:
		if p.cad_face_descriptors[key].type!="Plane":continue
		var y=float(p.cad_face_centers[key][1])
		if y<low:low=y;bottom=key
		if y>high:high=y;top=key
	w.document.execute("SetAnalysis",{"analysis":{"type":"static_structural","element":"TET4","backend":"calculix"}})
	w.document.execute("ApplySupport",{"index":0,"face":bottom});w.document.execute("ApplyLoad",{"index":0,"face":top,"force":[0,1000,0]})
	w.face.select(p.cad_faces.find(top));w.show_selected_face();await capture("selected-cad-face")
	w.divisions.value=3;w.generate_analysis_mesh();var deadline=Time.get_ticks_msec()+120000
	while w.external_mesh_thread!=null and Time.get_ticks_msec()<deadline:await process_frame
	if w.document.data.mesh.is_empty():fail("Boolean GUI Gmsh failed: "+w.status.text);return
	w.mesh_visible=true;w.render_model();w.fit_model();await capture("boolean-tet4-mesh")
	w.solve();deadline=Time.get_ticks_msec()+150000
	while w.solve_thread!=null and Time.get_ticks_msec()<deadline:await process_frame
	if not w.results_current():fail("GUI CalculiX failed: "+w.status.text);return
	w.deformation_scale=w.automatic_deformation_scale();w.structural_wireframe=true
	w.select_result_field("displacement");await capture("calculix-displacement")
	w.select_result_field("von_mises");await capture("calculix-von-mises")
	var path=preload("res://tests/development_paths.gd").output_file("CAD/cad21/gui.ucae")
	if w.document.save_project(path)!=OK or not w.document.open_project(path).is_empty() or not w.results_current():fail("GUI save/reopen");return
	w.open_cad_boolean(true)
	panel=w.get_children().filter(func(child):return child.get_script()==load("res://ui/cae/cad_boolean_panel.gd"))[-1]
	panel.feature_picker.select(1);panel.load_feature();panel.controls.dimensions[0].value=.05
	panel.start_preview();await wait_geometry()
	if panel.pending.is_empty():fail("Parametric edit preview: "+panel.message.text);return
	await capture("edit-cylinder-feature")
	panel.commit();await process_frame
	if w.results_current() or not w.document.data.parts[0].support.is_empty() or not w.document.data.parts[0].load_face.is_empty():fail("Changed hole failed boundary review");return
	w.document.undo()
	if not w.results_current():fail("GUI undo failed");return
	w.document.redo()
	if w.results_current():fail("GUI redo failed");return
	w.queue_free();await process_frame;print("CAD21_GUI_PASS");quit()
