extends SceneTree
var out=preload("res://tests/development_paths.gd").output("CAD/cad251")
func _initialize():call_deferred("run")
func run():
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child(w);w.set_active(true)
	var error=w.document.open_project(out+"/solved-2.json")
	if not error.is_empty():push_error(error);quit(1);return
	w.selected=0;w.select_body(0);w.fit_model()
	for field in ["displacement","von_mises"]:
		w.select_result_field(field)
		for width in [1280,1920]:
			root.size=Vector2i(width,720 if width==1280 else 1080)
			for i in 8:await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(out+"/%s-%d.png" % [field,width])
	w.queue_free();await process_frame
	print("CAD251_GUI_CAPTURED");quit()
