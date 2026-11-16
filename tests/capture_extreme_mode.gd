extends SceneTree
func _initialize():
	var workspace=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(workspace);await process_frame
	workspace.set_active(true);workspace.open_extreme_mode()
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/extreme-mode/configuration.png")
	workspace.queue_free();await process_frame;quit()
