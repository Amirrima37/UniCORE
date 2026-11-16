extends SceneTree
func _initialize():
	create_timer(30).timeout.connect(func():quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var w=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(w)
	await process_frame
	w.set_active(true)
	w.create_part("Box")
	w.run_command("AssignMaterialById",{"material_id":"Aluminum 6061-T6"})
	w.run_command("ApplySupport",{"face":"X-"})
	w.run_command("ApplyLoad",{"face":"X+","force":[100,0,0]})
	w.divisions.value=1
	w.solve()
	while w.solve_thread!=null:await process_frame
	assert(w.results_current())
	assert(w.automatic_deformation_scale()>1)
	w.select_result_field("displacement")
	w.fit_model()
	w.activate_mesh_pick("element")
	assert(w.show_results and w.deformation_scale==0)
	assert(w.prepare_mesh_inspection())
	var found:=false
	for record in w.mesh_inspection.records:
		var center:=Vector3.ZERO
		for id in record.ids:center+=w.mesh_inspection.point(id)
		center/=record.ids.size()
		var screen: Vector2=w.camera.unproject_position(center)
		var hit: Dictionary=w.mesh_inspection.pick(w.camera,screen,false)
		if not hit.is_empty():
			var probe_start:=Time.get_ticks_usec()
			w.inspect_mesh_click(screen)
			var perf=FileAccess.open("res://docs/workbench-2/stage5-final-probe-interaction.json",FileAccess.WRITE)
			perf.store_string(JSON.stringify({"nodes":w.document.data.results.nodes.size(),"elements":w.document.data.results.elements.size(),"interaction_ms":(Time.get_ticks_usec()-probe_start)/1000.0}))
			perf.close()
			assert(hit.element>=0 and hit.element<w.document.data.results.elements.size())
			found=true;break
	assert(found)
	w.activate_mesh_pick("node")
	assert(w.mesh_pick_mode=="node" and w.results_current())
	print("Result viewport picking / actual solver element IDs / automatic scale / original-coordinate probe mode PASS")
	w.queue_free()
	await process_frame
	quit()
