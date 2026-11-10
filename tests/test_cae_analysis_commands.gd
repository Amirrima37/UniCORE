extends SceneTree
var failures:=0
func check(ok: bool,message: String):
	if not ok: failures+=1; push_error(message)
func _initialize():
	create_timer(30).timeout.connect(func(): quit(2))
	GDExtensionManager.load_extension("res://bin/unicore_native.gdextension")
	var workspace=load("res://ui/cae/cae_workspace.gd").new()
	root.add_child.call_deferred(workspace)
	await process_frame
	workspace.set_active(true)
	workspace.create_part("Box")
	var signature: String=workspace.engineering_context().signature
	var response={"commands":[{"command":"AssignMaterialById","args":{"material_id":"Stainless steel 316"}},{"command":"SetAnalysis","args":{"analysis":{"type":"steady_thermal","element":"TET4"}}},{"command":"ApplyThermalBoundary","args":{"boundary":{"face":"X-","kind":"temperature","value":300}}},{"command":"ApplyThermalBoundary","args":{"boundary":{"face":"X+","kind":"temperature","value":400}}},{"command":"GenerateMesh","args":{"target_size":.025}},{"command":"SolveAnalysis","args":{}},{"command":"CreateResultView","args":{"field":"temperature"}}]}
	var error: String=workspace.apply_engineering_response(response,signature)
	check(error.is_empty(),"Validated AI physics batch: "+error)
	while workspace.solve_thread!=null: await process_frame
	check(workspace.results_current() and workspace.document.data.results.has("temperature"),"AI thermal solve uses worker backend")
	check(abs(workspace.document.data.results.max_temperature-400)<1e-7,"AI thermal actual results")
	check(workspace.document.data.mesh.divisions==4,"AI target size mapped to native grid")
	var data: Dictionary=workspace.document.data.duplicate(true)
	error=workspace.apply_engineering_response({"commands":[{"command":"SetAnalysis","args":{"analysis":{"type":"fluid_flow"}}}]},workspace.engineering_context().signature)
	check(not error.is_empty() and workspace.document.data==data,"Unavailable physics rejected atomically")
	print("Validated engineering-analysis AI operations: ",failures," failures")
	workspace.queue_free()
	await process_frame
	quit(1 if failures else 0)
