extends SceneTree
func _initialize():
	create_timer(60).timeout.connect(func():quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w)
	await process_frame
	w.set_active(true)
	w.create_part("Box")
	w.run_command("AssignMaterialById",{"material_id":"Aluminum 6061-T6"})
	w.run_command("ApplySupport",{"face":"X-"})
	w.run_command("ApplyLoad",{"face":"X+","force":[100,0,0]})
	w.divisions.value=2
	w.solve()
	while w.solve_thread!=null: await process_frame
	assert(w.results_current())
	w.deformation_scale=100000
	w.structural_wireframe=true
	for field in ["displacement","von_mises"]:
		w.select_result_field(field)
		w.show_result_inspector()
		for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=resolution
			for i in 8: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/workbench-2/stage51-box-%s-%d.png" % [field,resolution.x])
	w.queue_free()
	await process_frame
	quit()
