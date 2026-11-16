extends SceneTree
func _initialize():
	var document=load("res://core/cae/cae_document.gd").new()
	document.execute("CreatePart",{"kind":"Box","parameters":{"length":.1,"height":1.0,"width":.1}})
	document.execute("SetAnalysis",{"analysis":{"type":"static_structural","element":"TET10","backend":"calculix"}})
	document.execute("ApplySupport",{"index":0,"face":"Y-"});document.execute("ApplyLoad",{"index":0,"face":"Y+","force":[0,1000,0]})
	document.data.parts[0].material.nu=0
	var settings=load("res://core/cae/mesh_config.gd").defaults(.07);settings.schema=2;settings.order=2
	assert(document.execute("SetMeshSettings",{"index":0,"settings":settings}).is_empty())
	var bridge=load("res://core/cae/calculix_workbench.gd").new()
	document.data.mesh=bridge.generate_mesh(document.data,.07)
	if document.data.mesh.has("error"):push_error(document.data.mesh.error);quit(1);return
	print("CURRENT_DIAG ",load("res://core/cae/mesh_config.gd").validate(document.data.mesh.mesh_settings,[],false)," formulation=",document.data.mesh.formulation," settings=",load("res://core/cae/mesh_config.gd").encode_numbers(settings)==load("res://core/cae/mesh_config.gd").encode_numbers(document.data.mesh.mesh_settings))
	for key in ["id","kind","dimensions","position","rotation","scale","cad_sha256"]:
		if document.data.mesh.geometry_part.get(key)!=document.data.parts[0].get(key):print("GEOMETRY_DIFF ",key)
	var result=bridge.solve_model(document.data)
	if not result.get("ok",false):push_error(result.get("error","failed"));quit(1);return
	print("QUADRATIC_SMOKE ",result.max_displacement," expected=",1000.0/(210e9*.01)," points=",result.stress_integration_points.size())
	if absf(result.max_displacement/(1000.0/(210e9*.01))-1)>1e-5:push_error("C3D10 patch mismatch");quit(1);return
	var w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.queue_free();await process_frame
	print("CAD23_SMOKE_PASS");quit()
