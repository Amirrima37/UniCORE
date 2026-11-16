extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/cad24-completion/screenshots")
var w
func fail(message: String):push_error(message);quit(1)
func capture(name: String):
	for width in [1280,1920]:
		root.size=Vector2i(width,720 if width==1280 else 1080)
		for i in 8:await process_frame
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png(OUT+"/%s-%d.png" % [name,width])
func _initialize():
	DirAccess.make_dir_recursive_absolute(OUT)
	w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	var created=w.document.execute("CreatePart",{"kind":"Box"})
	if not created.is_empty():fail(created);return
	w.selected=0;w.select_body(0)
	var primitive_validation=load("res://ui/cae/cad_validation_panel.gd").new();w.add_child(primitive_validation);primitive_validation.configure(w,w.document.data.parts[0]);primitive_validation.popup_centered()
	while w.cad_geometry_thread!=null:await process_frame
	if not "VALID" in primitive_validation.status.text:fail(primitive_validation.status.text);return
	await capture("native-primitive-validation");primitive_validation.queue_free();await process_frame
	var error=w.document.open_project("res://docs/architecture/evidence/cad24-completion/step-scaled-tet2.ucae")
	if not error.is_empty():fail(error);return
	w.selected=0;w.select_body(0);w.cad.set_view("Isometric",false);w.fit_model()
	await capture("native-transformed-step-history")
	var validation=load("res://ui/cae/cad_validation_panel.gd").new();w.add_child(validation);validation.configure(w,w.document.data.parts[0]);validation.popup_centered()
	while w.cad_geometry_thread!=null:await process_frame
	if not "VALID" in validation.status.text:fail("Native validation GUI: "+validation.status.text);return
	await capture("native-validation");validation.queue_free();await process_frame
	w.open_cad_boolean(true);await process_frame
	var panels=w.get_children().filter(func(child):return child.get_script()==load("res://ui/cae/cad_boolean_panel.gd"))
	var panel=panels[-1];panel.controls.scale[0].value=3;panel.controls.scale[1].value=2;panel.controls.scale[2].value=2
	panel.quality.value=8;panel.start_preview()
	while w.cad_geometry_thread!=null:await process_frame
	if panel.pending.is_empty():fail("Native transform preview: "+panel.message.text);return
	await capture("native-transform-preview");panel.commit();await process_frame
	var p=w.document.data.parts[0]
	if p.cad_boundary_archive.size()<2 or p.cad_pending_boundaries.is_empty():fail("Unsafe boundary retention");return
	w.select_body(0);await capture("archived-boundaries-needs-review")
	var low=INF;var high=-INF;var support="";var load_face=""
	for face in p.cad_faces:
		var y=float(p.cad_face_centers[face][1])
		if y<low:low=y;support=face
		if y>high:high=y;load_face=face
	for command in ["ApplySupport","ApplyLoad"]:
		error=w.document.execute(command,{"index":0,"face":support if command=="ApplySupport" else load_face,"force":[0,1000,0]})
		if not error.is_empty():fail(error);return
	if not w.document.data.parts[0].cad_pending_boundaries.is_empty():fail("Reassignment unresolved");return
	w.selected=0;w.select_body(0);w.generate_analysis_mesh()
	while w.external_mesh_thread!=null:await process_frame
	if not preload("res://core/cae/mesh_config.gd").current(w.document.data):fail("Transformed GUI remesh failed: "+w.status.text);return
	w.solve()
	while w.solve_thread!=null:await process_frame
	if not w.results_current():fail("Transformed GUI solve failed: "+w.status.text);return
	w.fit_model();w.select_result_field("displacement");await capture("native-transformed-calculix-displacement")
	w.select_result_field("von_mises");await capture("native-transformed-calculix-stress")
	var saved=preload("res://tests/development_paths.gd").output_file("CAD/cad24-completion/gui-final.ucae")
	if w.document.save_project(saved)!=OK or not w.document.open_project(saved).is_empty() or not w.results_current():fail("New GUI save/reopen freshness");return
	await capture("native-save-reopen-current")
	w.queue_free();await process_frame;print("CAD24_GUI_PASS");quit()
