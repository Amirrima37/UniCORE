extends SceneTree
func _initialize():
	create_timer(60).timeout.connect(func():quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var workspace=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace);await process_frame
	workspace.set_active(true);workspace.create_part("Box");workspace.divisions.value=3
	workspace.run_command("AssignMaterialById",{"material_id":"Stainless steel 316"})
	workspace.document.execute("SetAnalysis",{"analysis":{"type":"steady_thermal"}})
	workspace.run_command("ApplyThermalBoundary",{"boundary":{"kind":"temperature","face":"X-","value":600}})
	workspace.run_command("ApplyThermalBoundary",{"boundary":{"kind":"radiation","face":"X+","emissivity":0.8,"surroundings":300}})
	workspace.run_command("ApplyThermalBoundary",{"boundary":{"kind":"convection","face":"X+","h":10,"ambient":300}})
	workspace.solve()
	while workspace.solve_thread!=null:await process_frame
	assert(workspace.results_current())
	workspace.fit_model()
	for name in ["temperature","heat_flux"]:
		workspace.thermal_field=name;workspace.show_flux_arrows=name=="heat_flux";workspace.flux_stride=12
		workspace.redraw_thermal();workspace.show_result_inspector()
		for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=resolution
			for i in 8:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/workbench-2/stage51-box-"+name+"-"+str(resolution.x)+".png")

	var result: Dictionary=workspace.document.data.results
	var file:=FileAccess.open("res://docs/workbench-2/stage51-box-thermal.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"minimum_K":result.min_temperature,"maximum_K":result.max_temperature,"radiation_W":result.radiation_loss_W,"convection_W":result.convection_loss_W,"balance_W":result.energy_balance_W,"relative_balance":result.relative_energy_balance,"newton":result.nonlinear_iterations,"residual":result.relative_residual},"\t"))
	workspace.document.execute("SetAnalysis",{"analysis":{"type":"transient_thermal","time_step":0.1,"steps":5,"initial_temperature":400}})
	workspace.solve()
	while workspace.solve_thread!=null:await process_frame
	assert(workspace.results_current() and workspace.document.data.results.heat_flux_history.size()==workspace.document.data.results.history.size())
	workspace.show_result_inspector();workspace.toggle_thermal_playback()
	await create_timer(0.3).timeout
	assert(workspace.thermal_frame>=0)
	workspace.toggle_thermal_playback()
	workspace.queue_free();await process_frame
	print("Graphical thermal/radiation contours, real flux arrows, nonlinear solve and transient playback PASS")
	quit()
