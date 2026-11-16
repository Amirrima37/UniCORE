extends SceneTree
var source=OS.get_environment("UNICORE_E_OUT")
var out=OS.get_environment("UNICORE_E_LIFECYCLE_OUT")
var mode=OS.get_environment("UNICORE_E_LIFECYCLE")
var w
var geometry_result={}
var native_request={}
func completed(result: Dictionary):geometry_result=result
func _initialize():call_deferred("run")
func native_running(path: String, action: String) -> Dictionary:
	if path.is_empty():return {}
	var file=path+"/running.json"
	if FileAccess.file_exists(file):
		var info=JSON.parse_string(FileAccess.get_file_as_string(file))
		if info is Dictionary and info.get("action")==action:return info
	for child in DirAccess.get_directories_at(path):
		var result=native_running(path+"/"+child,action)
		if not result.is_empty():return result
	return {}
func run():
	w=load("res://ui/cae/cae_workspace.gd").new();root.add_child(w);w.set_active(true)
	assert(w.document.open_project(source+"/ready-1.json").is_empty())
	w.document.data.results={}
	assert(w.document.save_project(out+"/interrupted.json")==OK)
	var geometry=mode in ["cancel-native","crash-native","timeout-native"]
	if geometry:
		if mode=="timeout-native":OS.set_environment("UNICORE_OCCT_TIMEOUT_S","0")
		native_request={"model":{"schema":1,"units":"m","root":"cut","nodes":[{"id":"base","type":"Box","dimensions":[.1,.2,.1]},{"id":"tool","type":"Cylinder","dimensions":[.04,.3,.04]},{"id":"cut","type":"Cut","base":"base","tool":"tool"}]},"quality":20}
		assert(w.start_cad_geometry(native_request,self))
	elif "solve" in mode or mode=="fail-calculix":w.solve()
	else:
		OS.set_environment("UNICORE_INTERFERENCE_CACHE_ROOT",out+"/lifecycle-cache-"+mode+"-"+str(Time.get_ticks_usec()))
		w.generate_analysis_mesh()
	var deadline=Time.get_ticks_msec()+60000;var observed={};var directory="";var heartbeat=0
	while Time.get_ticks_msec()<deadline:
		heartbeat+=1
		var engine=w.cad_geometry_job if geometry else w.native_solver
		if engine!=null:
			directory=ProjectSettings.globalize_path(engine.directory)
			if not directory.is_empty() and not FileAccess.file_exists(out+"/monitor-request.json"):
				var signal_file=FileAccess.open(out+"/monitor-request.json",FileAccess.WRITE)
				signal_file.store_string(JSON.stringify({"directory":directory,"mode":mode}));signal_file.close()
			if FileAccess.file_exists(out+"/monitor-result.json"):
				observed=JSON.parse_string(FileAccess.get_file_as_string(out+"/monitor-result.json"));break
		if geometry and w.cad_geometry_thread==null:break
		if not geometry and w.external_mesh_thread==null and w.solve_thread==null:break
		await process_frame
	# Godot only tracks processes launched by its own process APIs on Windows.
	# Grandchildren require a native process handle, not OS.is_process_running.
	var alive_at_action=observed.get("alive_at_action",false)
	if mode.begins_with("close"):
		w.queue_free();await process_frame
	elif mode in ["crash-native","fail-gmsh","fail-calculix"]:
		if alive_at_action:OS.kill(int(observed.pid))
	elif mode!="timeout-native":
		if geometry:w.cancel_cad_geometry()
		elif w.native_solver!=null:w.native_solver.cancel()
	if is_instance_valid(w):
		while w.cad_geometry_thread!=null or w.external_mesh_thread!=null or w.solve_thread!=null:
			heartbeat+=1;await process_frame
	OS.unset_environment("UNICORE_OCCT_TIMEOUT_S")
	for i in 10:await process_frame
	var alive_after=process_alive(observed)
	var receipt={}
	if FileAccess.file_exists(directory+"/receipt.json"):receipt=JSON.parse_string(FileAccess.get_file_as_string(directory+"/receipt.json"))
	var failed_safely=not receipt.is_empty() and (receipt.get("state")!="completed" or (geometry and not geometry_result.get("ok",true) and not geometry_result.get("error","").is_empty()))
	var interrupted_error=geometry_result.get("error","")
	if is_instance_valid(w):w.queue_free();await process_frame
	# A fresh real Workbench opens the interruption snapshot and retries normally.
	w=load("res://ui/cae/cae_workspace.gd").new();root.add_child(w);w.set_active(true)
	var reopened=w.document.open_project(out+"/interrupted.json").is_empty()
	var no_stale_result=w.document.data.results.is_empty()
	var retried=false
	if geometry:
		geometry_result={};w.start_cad_geometry(native_request,self)
		while w.cad_geometry_thread!=null:await process_frame
		retried=geometry_result.get("ok",false)
	else:
		if not "solve" in mode and mode!="fail-calculix":
			w.generate_analysis_mesh()
			while w.external_mesh_thread!=null:await process_frame
		w.solve()
		while w.solve_thread!=null:await process_frame
		retried=w.document.data.results.get("ok",false) and w.results_current()
	var result={"mode":mode,"observed":observed,"alive_at_action":alive_at_action,"alive_after":alive_after,"job":directory,"receipt":receipt,"heartbeat":heartbeat,"failed_safely":failed_safely,"geometry_error":interrupted_error,"reopened":reopened,"no_stale_result":no_stale_result,"retry_succeeded":retried}
	var f=FileAccess.open(out+"/lifecycle-"+mode+".json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	if is_instance_valid(w):w.queue_free();await process_frame
	print("LIFECYCLE_RESULT ",mode," ",not alive_after and failed_safely," observed=",alive_at_action)
	quit(0 if not alive_after and failed_safely and reopened and no_stale_result and retried and (alive_at_action or mode=="timeout-native") else 1)

func process_alive(info: Dictionary) -> bool:
	if info.is_empty():return false
	var output=[]
	OS.execute(OS.get_environment("UNICORE_PYTHON"),[ProjectSettings.globalize_path("res://tests/cad251_e_process_alive.py"),str(int(info.pid))],output,true)
	return "true" in "".join(output).to_lower()
