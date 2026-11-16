extends SceneTree
var out=OS.get_environment("UNICORE_PLACEMENT_OUT")
func _initialize():call_deferred("run")
func run():
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child(w);w.set_active(true)
	var error=w.document.open_project(out+"/rotated2.json")
	if not error.is_empty():push_error(error);quit(1);return
	w.selected=1;w.select_body(1);w.fit_model()
	var bridge=preload("res://core/cae/calculix_workbench.gd").new()
	var stale=w.document.data.duplicate(true);stale.parts[0].position[0]+=0.01
	assert(not bridge.solve_model(stale).get("ok",false))
	stale=w.document.data.duplicate(true);stale.parts[0].cad_pending_boundaries={"support":true}
	assert(not bridge.solve_model(stale).get("ok",false))
	w.solve()
	while w.solve_thread!=null:await process_frame
	assert(w.document.data.results.get("ok",false))
	w.select_result_field("displacement")
	for width in [1280,1920]:
		root.size=Vector2i(width,720 if width==1280 else 1080)
		for i in 12:await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(out+"/workbench-"+str(width)+".png")
	w.show_results=false
	w.run_command("SetPosition",{"values":[2.2,0,0]})
	assert(w.document.data.mesh.is_empty())
	while w.cad_preview_thread!=null:await process_frame
	assert(w.cad_preview.get("surface_regions",{}).size()==2)
	w.run_command("SetRotation",{"values":[0,0,PI/2]})
	while w.cad_preview_thread!=null:await process_frame
	w.queue_free();await process_frame
	print("PLACEMENT_GUI_PASS stale_geometry=true pending_boundary=true placement_preview=true")
	quit()
