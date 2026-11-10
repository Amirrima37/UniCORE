extends SceneTree
func _initialize():
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var workspace = load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	var doc = workspace.document
	doc.execute("CreatePart")
	doc.execute("ApplySupport",{"index":0,"face":"X-"})
	doc.execute("ApplyLoad",{"index":0,"face":"X+","force":[0,-1000,0]})
	workspace.selected = 0
	workspace.solve()
	var deadline := Time.get_ticks_msec()+30000
	while workspace.solve_thread != null and Time.get_ticks_msec()<deadline:
		await process_frame
	if workspace.solve_thread != null or not workspace.results_current():
		push_error("Background solve failed: " + workspace.status.text)
		quit(1)
		return
	workspace.inspect()
	workspace.render_model()
	doc.execute("SetDimensions", {"index":0,"values":[2,.2,.2]})
	assert(not workspace.results_current())
	doc.undo()
	assert(workspace.results_current())
	doc.generate_mesh(2)
	assert(not workspace.results_current())
	print("Background solve, result overlay/probes and stale-result checks passed")
	workspace.queue_free()
	await process_frame
	quit()

