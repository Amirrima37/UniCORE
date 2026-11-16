extends SceneTree
var source=OS.get_environment("UNICORE_E_OUT")
var out=OS.get_environment("UNICORE_E_ENDURANCE_OUT")
var w
var heartbeat=0
func _initialize():call_deferred("run")
func resources(paths: Array=[]) -> Dictionary:
	var output=[];var arguments=[ProjectSettings.globalize_path("res://tests/cad251_e_resources.py"),str(OS.get_process_id())]
	arguments.append_array(paths)
	OS.execute(OS.get_environment("UNICORE_PYTHON"),arguments,output,true)
	return JSON.parse_string("".join(output))
func wait_jobs():
	while w.external_mesh_thread!=null or w.solve_thread!=null or w.cad_preview_thread!=null:
		heartbeat+=1;await process_frame
func run():
	w=load("res://ui/cae/cae_workspace.gd").new();root.add_child(w);w.set_active(true)
	assert(w.document.open_project(source+"/ready-1.json").is_empty());w.render_model()
	var initial=resources();var rows=[]
	for cycle in 20:
		var order=cycle%2+1;var start=Time.get_ticks_msec();var ticks=heartbeat
		w.show_results=false
		for index in w.document.data.parts.size():
			var settings=preload("res://core/cae/mesh_config.gd").defaults(.05);settings.schema=2;settings.order=order
			assert(w.document.execute("SetMeshSettings",{"index":index,"settings":settings}).is_empty())
		w.generate_analysis_mesh();await wait_jobs();assert(not w.document.data.mesh.is_empty())
		var mesh_job=ProjectSettings.globalize_path(w.native_solver.directory)
		w.solve();await wait_jobs();assert(w.document.data.results.get("ok",false) and w.results_current())
		var solve_job=ProjectSettings.globalize_path(w.native_solver.directory)
		var mesh=w.document.data.mesh;var result=w.document.data.results
		var error=0.0;var imbalance=0.0
		for p in w.document.data.parts:
			var force=Vector3(p.force[0],p.force[1],p.force[2]);var tip=0.0;var reaction=Vector3.ZERO
			for n in mesh.groups[p.id][p.load_face]:
				var u=result.displacement[n];tip+=Vector3(u[0],u[1],u[2]).dot(force.normalized())/mesh.groups[p.id][p.load_face].size()
			for n in range(int(mesh.instances[p.id].node_range[0]),int(mesh.instances[p.id].node_range[1])):
				var r=result.reactions[n];reaction+=Vector3(r[0],r[1],r[2])
			error=maxf(error,abs(tip/(force.length()*.4/(p.material.E*.01))-1))
			imbalance=maxf(imbalance,(reaction+force).length()/force.length())
		assert(error<1e-4 and imbalance<1e-5 and heartbeat>ticks)
		w.document.data.mesh={};w.document.data.results={};w.document.changed.emit()
		assert(not w.results_current());await wait_jobs()
		var sample=resources([mesh_job,solve_job]);assert(sample.owned_descendants.is_empty(),"Owned workers must have exited after a cycle")
		var console_characters=w.console_log.get_total_character_count();var console_paragraphs=w.console_log.get_paragraph_count()
		assert(console_characters<=w.CONSOLE_CHARACTERS and console_paragraphs<=w.CONSOLE_PARAGRAPHS)
		rows.append({"cycle":cycle,"order":order,"duration_ms":Time.get_ticks_msec()-start,"heartbeat_frames":heartbeat-ticks,"resources":sample,"static_memory":OS.get_static_memory_usage(),"orphan_nodes":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"console_characters":console_characters,"console_paragraphs":console_paragraphs,"undo_depth":w.document.undo_stack.size(),"mesh_job":mesh_job,"solver_job":solve_job,"max_error":error,"max_imbalance":imbalance,"completion":result.completion,"results_cleared":true})
		var f=FileAccess.open(out+"/workbench-endurance.json",FileAccess.WRITE);f.store_string(JSON.stringify({"initial":initial,"cycles":rows},"  "));f.close()
		print("WORKBENCH_ENDURANCE_CYCLE ",cycle)
	var before_history_clear={"resources":resources(),"static_memory":OS.get_static_memory_usage(),"undo_depth":w.document.undo_stack.size()}
	w.document.undo_stack.clear();w.document.redo_stack.clear()
	for i in 20:await process_frame
	var after_history_clear={"resources":resources(),"static_memory":OS.get_static_memory_usage(),"undo_depth":w.document.undo_stack.size()}
	var investigation=FileAccess.open(out+"/history-memory.json",FileAccess.WRITE);investigation.store_string(JSON.stringify({"before":before_history_clear,"after":after_history_clear},"  "));investigation.close()
	w.queue_free();w=null
	for i in 10:await process_frame
	var teardown=FileAccess.open(out+"/teardown.json",FileAccess.WRITE);teardown.store_string(JSON.stringify({"resources":resources(),"static_memory":OS.get_static_memory_usage(),"orphan_nodes":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)},"  "));teardown.close()
	print("WORKBENCH_ENDURANCE_20_PASS");quit()
