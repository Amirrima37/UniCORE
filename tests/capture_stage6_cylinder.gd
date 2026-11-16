extends SceneTree
func _initialize():
	var workspace=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	workspace.set_active(true)
	workspace.create_part("Cylinder")
	workspace.run_command("SetParameters",{"parameters":{"length":0.4,"diameter":0.2}})
	assert(workspace.document.generate_mesh(4).is_empty())
	workspace.quality_metric="mean_ratio"
	workspace.set_inspection_mode("quality")
	var deadline:=Time.get_ticks_msec()+30000
	while workspace.inspection_mesh_key.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	assert(not workspace.inspection_mesh_key.is_empty())
	workspace.fit_model()
	workspace.cad.distance*=0.6
	workspace.cad.update_camera()
	for width in [1280,1920]:
		root.size=Vector2i(width,720 if width==1280 else 1080)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/workbench-2/stage6-cylinder-quality-%d.png"%width)
	workspace.queue_free()
	await process_frame
	quit()
