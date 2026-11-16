extends SceneTree
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w)
	await process_frame
	w.set_active(true)
	w.create_part("Box")
	w.run_command("SetParameters",{"parameters":{"length":0.3,"width":0.1,"height":0.1}})
	w.run_command("ApplySupport",{"face":"X-"})
	w.run_command("ApplyPressure",{"face":"X+","value":20000})
	w.divisions.value=4
	w.generate_analysis_mesh()
	w.fit_model()
	w.active_ribbon="Loads & Constraints"
	w.populate_ribbon()
	w.inspect_condition({"body":0,"key":"pressure"})
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/workbench-2/stage3-conditions-%d.png" % resolution.x)
	w.active_ribbon="Mesh"
	w.populate_ribbon()
	w.set_inspection_mode("combined")
	w.open_mesh_workspace()
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/workbench-2/stage3-mesh.png")
	w.queue_free()
	await process_frame
	quit()
