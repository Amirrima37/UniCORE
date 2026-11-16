extends SceneTree
var OUT=preload("res://tests/development_paths.gd").output("CAD/cad23")
var w
func capture(name: String):
	for width in [1280,1920]:
		root.size=Vector2i(width,720 if width==1280 else 1080)
		for i in 6:await process_frame
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png(OUT+"/screenshots/%s-%d.png" % [name,width])
func fail(message: String):push_error(message);quit(1)
func _initialize():
	w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	if not w.document.open_project(OUT+"/gui-quadratic.ucae").is_empty() or not w.results_current():fail("GUI inspector reopen");return
	w.selected=0;w.select_body(0);w.cad.set_view("Isometric",false);w.select_result_field("von_mises");w.fit_model();await capture("corrected-stress-association")
	w.activate_mesh_pick("element");w.prepare_mesh_inspection();var deadline=Time.get_ticks_msec()+60000
	while not w.preparation_jobs.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	if not w.prepare_mesh_inspection():fail("GUI inspector preparation");return
	var screen=Vector2.ZERO;var hit={}
	for record in w.mesh_inspection.records.slice(0,1000):
		var center=Vector3.ZERO
		for id in record.ids:center+=w.mesh_inspection.point(int(id))/record.ids.size()
		screen=w.camera.unproject_position(center);hit=w.mesh_inspection.pick(w.camera,screen,false)
		if not hit.is_empty():break
	if hit.is_empty():fail("Genuine element ray picking");return
	w.inspect_mesh_click(screen);await capture("selected-c3d10-integration-points")
	w.activate_mesh_pick("node");screen=w.camera.unproject_position(w.mesh_inspection.point(int(hit.node)))
	var node_hit=w.mesh_inspection.pick(w.camera,screen,true)
	if node_hit.is_empty() or not node_hit.has("node"):fail("Genuine node ray picking");return
	w.inspect_mesh_click(screen);await capture("selected-quadratic-node")
	w.inspect_worst_mesh_element();await capture("worst-element-integration-jacobians")
	var f=FileAccess.open(OUT+"/gui-inspect-details.json",FileAccess.WRITE);f.store_string(JSON.stringify({"outcome":"PASS","element":hit.element,"node":node_hit.node,"current":w.results_current(),"actual_ray_picking":true}));f.close()
	if not w.document.open_project(OUT+"/tet10-bending.ucae").is_empty() or not w.results_current():fail("Quadratic bending GUI reopen");return
	w.selected=0;w.select_body(0);w.inspection_mode="";w.quality_metric="";w.deformation_scale=w.automatic_deformation_scale()
	w.select_result_field("displacement");w.fit_model();await capture("quadratic-bending-displacement")
	w.select_result_field("von_mises");await capture("quadratic-bending-von-mises")
	w.queue_free();await process_frame;print("CAD23_GUI_INSPECT_PASS");quit()
