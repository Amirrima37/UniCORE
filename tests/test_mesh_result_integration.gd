extends SceneTree
func _initialize():
	create_timer(60).timeout.connect(func(): quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var workspace=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	workspace.set_active(true)
	workspace.divisions.value=2
	workspace.create_part("Box")
	workspace.run_command("AssignMaterialById",{"material_id":"Aluminum 6061-T6"})
	workspace.run_command("ApplySupport",{"face":"X-"})
	workspace.run_command("ApplyLoad",{"face":"X+","force":[100,0,0]})
	for study in ["static_structural","steady_thermal","transient_thermal"]:
		assert(workspace.document.execute("SetAnalysis",{"analysis":{"type":study,"element":"TET4" if study!="static_structural" else "HEX8","time_step":0.1,"steps":3,"initial_temperature":300}})=="")
		if study!="static_structural":
			workspace.run_command("AssignMaterialById",{"material_id":"Stainless steel 316"})
			workspace.run_command("ApplyThermalBoundary",{"boundary":{"face":"X-","kind":"temperature","value":300}})
			workspace.run_command("ApplyThermalBoundary",{"boundary":{"face":"X+","kind":"temperature","value":400}})
		workspace.solve()
		while workspace.solve_thread!=null: await process_frame
		print(study,": ",workspace.status.text)
		if not workspace.results_current(): quit(1); return
		var snapshot:=JSON.stringify(workspace.document.data.results)
		workspace.set_inspection_mode("quality")
		workspace.set_mesh_display("volume")
		if study!="static_structural": assert(workspace.mesh_inspection.data.elements[0].size()==4)
		workspace.mesh_inspection.section(0.5)
		workspace.select_result_field("temperature" if study!="static_structural" else "displacement")
		assert(workspace.inspection_mode.is_empty())
		assert(JSON.stringify(workspace.document.data.results)==snapshot)
		assert(workspace.cad.overlay_root.get_child_count()>0)
	workspace.queue_free()
	await process_frame
	print("Mesh inspection structural/steady/transient result switching PASS")
	quit()
