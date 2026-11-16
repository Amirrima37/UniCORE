extends SceneTree
var out=preload("res://tests/development_paths.gd").output("CAD/cad251")
func _initialize():
	call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute(out)
	var rows=[]
	var part_count=int(OS.get_environment("UNICORE_CAD251_PART_COUNT")) if not OS.get_environment("UNICORE_CAD251_PART_COUNT").is_empty() else 2
	if part_count not in [2,3]:push_error("Qualification supports two or three parts");quit(1);return
	for order in [1,2]:
		var d=preload("res://core/cae/cae_document.gd").new()
		for k in part_count:
			assert(d.execute("CreatePart",{"kind":"Box"}).is_empty())
			var p=d.data.parts[k]
			p.dimensions=[0.1,0.4,0.1];p.position=[k*0.1,0,0]
			p.material={"name":"Material "+str(k),"E":100e9*(k+1),"nu":0.0,"density":7800.0}
			p.support="Y-";p.load_face="Y+";p.force=[0,1000,0]
			p.mesh_settings=preload("res://core/cae/mesh_config.gd").defaults(0.05)
			p.mesh_settings.schema=2;p.mesh_settings.order=order
		d.data.analysis={"type":"static_structural","backend":"calculix","element":"TET10" if order==2 else "TET4"}
		var bridge=preload("res://core/cae/calculix_workbench.gd").new()
		var mesh=bridge.generate_mesh(d.data,0.05)
		if mesh.has("error"):push_error(str(mesh));quit(1);return
		d.data.mesh=mesh
		if not preload("res://core/cae/mesh_config.gd").current(d.data):push_error("Assembly mesh freshness failed");quit(1);return
		var stale=d.data.duplicate(true)
		stale.parts[0].position[0]+=0.01
		if bridge.solve_model(stale).get("ok",false):push_error("Stale instance geometry accepted");quit(1);return
		stale=d.data.duplicate(true);stale.parts[0].cad_pending_boundaries={"support":true}
		if bridge.solve_model(stale).get("ok",false):push_error("Unreviewed boundary accepted");quit(1);return
		var result=bridge.solve_model(d.data)
		if not result.get("ok",false):push_error(str(result));quit(1);return
		for k in part_count:
			var p=d.data.parts[k];var tip=0.0;var reaction=Vector3.ZERO
			var ids=mesh.groups[p.id][p.load_face]
			for node in ids:tip+=result.displacement[node][1]/ids.size()
			for node in range(int(mesh.instances[p.id].node_range[0]),int(mesh.instances[p.id].node_range[1])):
				var rf=result.reactions[node];reaction+=Vector3(rf[0],rf[1],rf[2])
			var expected=1000*0.4/(p.material.E*0.01)
			var error=absf(tip/expected-1);var imbalance=(reaction+Vector3(0,1000,0)).length()/1000
			if error>0.0001 or imbalance>0.00001:push_error("Analytical/equilibrium failure "+str([error,imbalance]));quit(1);return
			rows.append({"order":order,"instance":p.id,"E_Pa":p.material.E,"displacement_m":tip,"reference_m":expected,"relative_error":error,"reaction_N":[reaction.x,reaction.y,reaction.z],"equilibrium_error":imbalance,"job":bridge.directory,"nodes":mesh.nodes.size(),"elements":mesh.elements.size(),"completion":result.completion})
		d.data.results=result
		d.data.results.model_parts=d.data.parts.duplicate(true)
		d.data.results.model_analysis=d.data.analysis.duplicate(true)
		var path=out+"/solved-"+str(order)+".json"
		assert(d.save_project(path)==OK)
		var reopened=preload("res://core/cae/cae_document.gd").new()
		var error=reopened.open_project(path)
		if not error.is_empty():push_error(error);quit(1);return
		assert(reopened.data.mesh.nodes==d.data.mesh.nodes)
		if not preload("res://core/cae/result_identity.gd").new().current(reopened.data):push_error("Solved result not current after reopen");quit(1);return
	var f=FileAccess.open(out+"/numerical.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
	print("CAD251_NUMERICAL_PASS ",rows)
	quit()
