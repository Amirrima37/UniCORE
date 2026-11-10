extends SceneTree
func _initialize():
	create_timer(40).timeout.connect(func(): quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var workspace=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	workspace.set_active(true)
	workspace.create_part("Box")
	workspace.run_command("AssignMaterialById",{"material_id":"Stainless steel 316"})
	workspace.document.execute("SetAnalysis",{"analysis":{"type":"steady_thermal"}})
	workspace.run_command("ApplyThermalBoundary",{"boundary":{"kind":"temperature","face":"X-","value":300}})
	workspace.run_command("ApplyThermalBoundary",{"boundary":{"kind":"temperature","face":"X+","value":400}})
	workspace.solve()
	while workspace.solve_thread!=null: await process_frame
	workspace.show_result_inspector()
	workspace.cad.invalidate()
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/thermal-results.png")
	workspace.open_material_library()
	workspace.material_editor.list.select(2)
	workspace.material_editor.list.item_selected.emit(2)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/engineering-materials.png")
	quit()
