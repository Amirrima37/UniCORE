extends SceneTree
func _initialize():
	var workspace=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	var sandbox:=Node3D.new()
	root.add_child(sandbox)
	var modes=load("res://core/workspace_mode_controller.gd").new()
	root.add_child(modes)
	var roots: Array[Node]=[sandbox]
	modes.setup(workspace,roots)
	for i in 5:
		modes.set_mode(1)
		modes.set_mode(0)
	await process_frame
	var nodes_before:=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var memory_before:=Performance.get_monitor(Performance.MEMORY_STATIC)
	var samples: Array[float]=[]
	for i in 100:
		var start:=Time.get_ticks_usec()
		modes.set_mode(1)
		modes.set_mode(0)
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	await process_frame
	samples.sort()
	var result: Dictionary={"empty_mode_roundtrip_p95_ms":samples[94],"empty_mode_roundtrip_max_ms":samples[99],"nodes_before":nodes_before,"nodes_after":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"memory_before_bytes":memory_before,"memory_after_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"idle_workspace_processing":workspace.is_processing(),"hidden_viewport_disabled":workspace.cad.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED}
	print(JSON.stringify(result))
	var file:=FileAccess.open("res://.tools/cae-recovery-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	workspace.queue_free()
	modes.queue_free()
	sandbox.queue_free()
	await process_frame
	quit()
