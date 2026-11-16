extends SceneTree
func _initialize():
	print("WB2 start")
	var workspace = load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	workspace.set_active(true)
	assert(workspace.tool_registry.tools.size() >= 38)
	print("WB2 workspace ready")
	workspace.open_tool_browser()
	assert(workspace.tool_browser.list.item_count >= 38)
	workspace.tool_browser.roadmap = true
	workspace.tool_browser.rebuild()
	assert(workspace.tool_browser.list.item_count == 50)
	assert(workspace.tool_browser.get_ok_button().disabled)
	print("WB2 browser complete")
	workspace.tool_browser.hide()
	assert(workspace.tool_registry.execute("geometry.box") == "")
	assert(workspace.document.data.parts.size() == 1)
	assert(workspace.tool_registry.execute("edit.undo") == "")
	assert(workspace.document.data.parts.is_empty())
	assert(workspace.tool_registry.execute("edit.redo") == "")
	assert(workspace.document.data.parts.size() == 1)
	print("WB2 commands complete")
	workspace.queue_free()
	await process_frame
	print("Workbench registry, capability guards, roadmap, geometry and undo/redo passed")
	quit()
