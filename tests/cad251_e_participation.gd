extends SceneTree
var out=OS.get_environment("UNICORE_E_OUT")
func _initialize():call_deferred("run")
func require(ok: bool,message: String):
	if not ok:push_error(message);quit(1);assert(false,message)
func run():
	var prior=OS.get_environment("UNICORE_D_SOURCE")
	var rows=[]
	for order in [1,2]:
		var d=preload("res://core/cae/cae_document.gd").new()
		require(d.open_project(prior+"/duplicate"+str(order)+".json").is_empty(),"open D baseline")
		var bridge=preload("res://core/cae/calculix_workbench.gd").new()
		var excluded_uuid=d.data.parts[1].instance_uuid
		require(d.execute("SetAnalysisEnabled",{"index":1,"enabled":false}).is_empty(),"exclude")
		require(d.execute("SetPosition",{"index":1,"values":[0,0,0]}).is_empty(),"disabled overlapping instance")
		d.data.parts[1].boundary_refs.load_face.state="unresolved";d.data.parts[1].boundary_refs.load_face.reason="test stale excluded boundary"
		require(d.execute("SetVisibility",{"index":0,"visible":false}).is_empty(),"hidden active")
		var mesh=bridge.generate_mesh(d.data,.05);require(not mesh.has("error"),str(mesh.get("error")))
		d.data.mesh=mesh
		require(not mesh.groups.has(d.data.parts[1].id),"excluded nodes/surfaces absent")
		var result=bridge.solve_model(d.data);require(result.get("ok",false),str(result))
		require(result.get("instances",{}).size()==1 and not result.get("instances",{}).has(d.data.parts[1].id),"active result ownership")
		result.model_parts=d.data.parts.duplicate(true);result.model_analysis=d.data.analysis.duplicate(true);d.data.results=result
		require(preload("res://core/cae/result_identity.gd").new().current(d.data),"fresh mixed-participation results")
		var p=d.data.parts[0];var tip=0.0;var reaction=Vector3.ZERO
		for n in mesh.groups[p.id][p.load_face]:tip+=result.displacement[n][1]/mesh.groups[p.id][p.load_face].size()
		for r in result.reactions:reaction+=Vector3(r[0],r[1],r[2])
		require(abs(tip/4e-7-1)<1e-4 and (reaction+Vector3(0,1000,0)).length()/1000<1e-5,"physical response")
		rows.append({"order":order,"job":ProjectSettings.globalize_path(bridge.directory),"excluded_uuid":excluded_uuid,"tip":tip,"reaction":[reaction.x,reaction.y,reaction.z],"completion":result.completion})
		require(d.save_project(out+"/participation-"+str(order)+".json")==OK,"save")
		var reopened=preload("res://core/cae/cae_document.gd").new()
		require(reopened.open_project(out+"/participation-"+str(order)+".json").is_empty(),"reopen")
		require(not reopened.data.parts[1].analysis_enabled and reopened.data.parts[1].instance_uuid==excluded_uuid,"persistent participation")
		require(d.execute("SetAnalysisEnabled",{"index":1,"enabled":true}).is_empty(),"reenable")
		require(not preload("res://core/cae/result_identity.gd").new().current(d.data),"participation edit invalidates completed results")
		require(not bridge.solve_model(d.data).get("ok",false),"old mesh cannot authorize changed participation")
		require(bridge.generate_mesh(d.data,.05).has("error"),"re-enabled overlap rejected")
		d.undo();require(not d.data.parts[1].analysis_enabled,"undo participation")
		require(d.execute("SetPosition",{"index":1,"values":[2,0,0]}).is_empty(),"separate excluded stale boundary")
		require(d.execute("SetAnalysisEnabled",{"index":1,"enabled":true}).is_empty(),"reenable stale boundary")
		var stale_mesh=bridge.generate_mesh(d.data,.05)
		if not stale_mesh.has("error"):
			d.data.mesh=stale_mesh
			require(not bridge.solve_model(d.data).get("ok",false),"re-enabled unresolved boundary blocks solve")
		d.undo();require(not d.data.parts[1].analysis_enabled,"restore excluded state")
		require(d.execute("SetAnalysisEnabled",{"index":0,"enabled":false}).is_empty(),"all off")
		require(bridge.generate_mesh(d.data,.05).has("error") and not bridge.solve_model(d.data).get("ok",false),"zero active safely rejected")
		var f=FileAccess.open(out+"/participation.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
		print("PARTICIPATION_SOLVE_PASS ",order)
	print("PARTICIPATION_GATE_PASS");quit()
