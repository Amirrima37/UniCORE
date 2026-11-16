extends SceneTree
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w)
	await process_frame
	w.set_active(true)
	w.create_part("Cylinder")
	w.run_command("SetParameters",{"parameters":{"length":0.4,"diameter":0.2}})
	w.run_command("ApplySupport",{"face":"Bottom"})
	w.run_command("ApplyPressure",{"face":"Top","value":20000})
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
		root.get_texture().get_image().save_png("res://docs/workbench-2/stage4-cylinder-%d.png" % resolution.x)
	w.active_ribbon="Mesh"
	w.populate_ribbon()
	w.set_inspection_mode("combined")
	w.open_mesh_workspace()
	var deadline=Time.get_ticks_msec()+10000
	while not w.preparation_jobs.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/workbench-2/stage4-cylinder-mesh.png")
	w.queue_free()
	await process_frame
	quit()
