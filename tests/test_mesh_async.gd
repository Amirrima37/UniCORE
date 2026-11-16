extends SceneTree
func _initialize():
	create_timer(30).timeout.connect(func():quit(2))
	var workspace=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace);await process_frame
	workspace.set_active(true);workspace.create_part("Box")
	workspace.document.generate_mesh(8);workspace.set_inspection_mode("combined")
	assert(not workspace.preparation_jobs.is_empty())
	var frames:=0
	while not workspace.preparation_jobs.is_empty():await process_frame;frames+=1
	assert(frames>0 and workspace.mesh_inspection.metrics.size()==512)
	workspace.section_fraction=0.5;workspace.overlay_key=[];workspace.render_model()
	while not workspace.preparation_jobs.is_empty():await process_frame
	assert(workspace.mesh_inspection.timings.get("reused_quality",false))
	workspace.document.generate_mesh(10);workspace.set_inspection_mode("quality")
	workspace.document.generate_mesh(2)
	while not workspace.preparation_jobs.is_empty():await process_frame
	workspace.prepare_mesh_inspection()
	assert(workspace.mesh_inspection.metrics.size()==8)
	workspace.queue_free();await process_frame
	print("Async snapshot, frame heartbeat, obsolete generation cancellation PASS")
	quit()
