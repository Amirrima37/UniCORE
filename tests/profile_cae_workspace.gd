extends SceneTree
func _initialize():
	var workspace = load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	var start := Time.get_ticks_usec()
	for i in 12: workspace.document.execute("CreatePart")
	var create_ms := (Time.get_ticks_usec()-start)/1000.0
	await process_frame
	var ids := []
	for m in workspace.meshes: ids.append(m.get_instance_id())
	start = Time.get_ticks_usec()
	for i in 30:
		workspace.selected = i%12
		workspace.render_model()
	var selection_ms := (Time.get_ticks_usec()-start)/1000.0
	var changed := 0
	for i in mini(ids.size(),workspace.meshes.size()):
		if ids[i] != workspace.meshes[i].get_instance_id(): changed += 1
	print(JSON.stringify({"create_12_ms":create_ms,"select_30_ms":selection_ms,"replaced_bodies":changed,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"process_seconds":Performance.get_monitor(Performance.TIME_PROCESS)}))
	workspace.queue_free()
	await process_frame
	quit()
