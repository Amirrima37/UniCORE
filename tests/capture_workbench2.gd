extends SceneTree
func _initialize():
	var workspace = load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	workspace.set_active(true)
	workspace.create_part("Box")
	workspace.create_part("Cylinder")
	workspace.run_command("SetPosition",{"values":[0.18,0,0]})
	workspace.fit_model()
	workspace.active_ribbon="Geometry"
	workspace.populate_ribbon()
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/workbench-2/stage2-%d.png" % resolution.x)
	print("TOOLS ",workspace.tool_registry.tools.size())
	workspace.open_tool_browser()
	print("MATCHES ",workspace.tool_browser.list.item_count)
	workspace.tool_browser.roadmap=true
	workspace.tool_browser.rebuild()
	print("ROADMAP ",workspace.tool_browser.list.item_count)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/workbench-2/stage2-roadmap.png")
	workspace.queue_free()
	await process_frame
	quit()
