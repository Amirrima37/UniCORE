extends SceneTree
var out=OS.get_environment("UNICORE_E_OUT")
func _initialize():call_deferred("run")
func require(ok: bool,text: String):
	if not ok:push_error(text);quit(1);assert(false,text)
func memory() -> Dictionary:
	var output=[]
	OS.execute(OS.get_environment("UNICORE_PYTHON"),PackedStringArray([ProjectSettings.globalize_path("res://tests/cad251_e_resources.py"),str(OS.get_process_id())]),output,true)
	return JSON.parse_string(str(output[0])) if not output.is_empty() else {}
func run():
	var d=preload("res://core/cae/cae_document.gd").new()
	require(d.open_project(OS.get_environment("UNICORE_D_SOURCE")+"/duplicate1.json").is_empty(),"baseline")
	var bridge=preload("res://core/cae/calculix_workbench.gd").new()
	var initial=memory();var rows=[]
	for cycle in 20:
		var order=cycle%2+1;var started=Time.get_ticks_msec()
		if cycle==18:
			var definition=d.data.parts[0].definition_uuid
			require(d.execute("AddInstance",{"definition_uuid":definition}).is_empty(),"third instance")
			require(d.execute("SetPosition",{"index":2,"values":[4,0,0]}).is_empty(),"third placement")
			require(d.execute("ApplySupport",{"index":2,"face":d.data.parts[0].support}).is_empty(),"third support")
			require(d.execute("ApplyLoad",{"index":2,"face":d.data.parts[0].load_face,"force":[0,3000,0]}).is_empty(),"third load")
		for k in d.data.parts.size():
			require(d.execute("AssignMaterial",{"index":k,"material":{"name":"Qualification "+str(k),"E":100e9*(k+1),"nu":0.0,"density":7800.0}}).is_empty(),"material")
			var config=preload("res://core/cae/mesh_config.gd").defaults(.05);config.schema=2;config.order=order
			d.data.parts[k].mesh_settings=config
			require(d.execute("SetVisibility",{"index":k,"visible":cycle%2==0}).is_empty(),"independent visibility")
		d.data.analysis.element="TET10" if order==2 else "TET4"
		var mesh=bridge.generate_mesh(d.data,.05);require(not mesh.has("error"),str(mesh.get("error")))
		d.data.mesh=mesh
		var result=bridge.solve_model(d.data);require(result.get("ok",false),str(result.get("error")))
		var maximum_error=0.0;var maximum_imbalance=0.0
		for p in d.data.parts:
			var force=Vector3(p.force[0],p.force[1],p.force[2]);var direction=force.normalized();var tip=0.0;var reaction=Vector3.ZERO
			for n in mesh.groups[p.id][p.load_face]:
				var u=result.displacement[n];tip+=Vector3(u[0],u[1],u[2]).dot(direction)/mesh.groups[p.id][p.load_face].size()
			for n in range(int(mesh.instances[p.id].node_range[0]),int(mesh.instances[p.id].node_range[1])):
				var r=result.reactions[n];reaction+=Vector3(r[0],r[1],r[2])
			var expected=force.length()*.4/(p.material.E*.01)
			maximum_error=maxf(maximum_error,abs(tip/expected-1));maximum_imbalance=maxf(maximum_imbalance,(reaction+force).length()/maxf(1000,force.length()))
		require(maximum_error<1e-4 and maximum_imbalance<1e-5,"physical response")
		result.model_parts=d.data.parts.duplicate(true);result.model_analysis=d.data.analysis.duplicate(true);d.data.results=result
		require(preload("res://core/cae/result_identity.gd").new().current(d.data),"fresh result")
		if cycle in [0,19]:
			var path=out+"/ready-"+str(order)+".json"
			require(d.save_project(path)==OK,"solved canonical save")
			var reopened=preload("res://core/cae/cae_document.gd").new();require(reopened.open_project(path).is_empty(),"solved canonical reopen")
			require(preload("res://core/cae/result_identity.gd").new().current(reopened.data),"lossless result freshness")
			d=reopened
		rows.append({"cycle":cycle,"order":order,"bodies":d.data.parts.size(),"max_error":maximum_error,"max_imbalance":maximum_imbalance,"duration_ms":Time.get_ticks_msec()-started,"memory":memory(),"job":ProjectSettings.globalize_path(bridge.directory),"completion":result.completion})
		var f=FileAccess.open(out+"/endurance.json",FileAccess.WRITE);f.store_string(JSON.stringify({"initial":initial,"cycles":rows},"  "));f.close()
		d.data.mesh={};d.data.results={}
		require(not preload("res://core/cae/result_identity.gd").new().current(d.data),"cleared result not current")
		print("ENDURANCE_CYCLE_PASS ",cycle)
		await process_frame
	print("ENDURANCE_20_PASS");quit()
