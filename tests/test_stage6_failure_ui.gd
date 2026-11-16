extends SceneTree
func all(node: Node) -> Array:
	var out: Array=[]
	for child in node.get_children():out.append(child);out.append_array(all(child))
	return out
func press(w,text: String,path: String=""):
	for item in all(w.properties):
		if item is Button and item.text==text and (path.is_empty() or item.get_meta("job_directory","")==path):item.pressed.emit();return
	push_error("Missing button "+text);quit(1)
func write(path: String,value: String):
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(value);file.close()
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	w.create_part("Pipe");w.run_command("SetParameters",{"parameters":{"outer_radius":0.1,"inner_radius":0.05,"length":0.1}})
	w.run_command("AssignMaterial",{"material":{"name":"Cancel fixture","E":1000.0,"nu":0.0,"density":1000.0,"k":10.0,"cp":1000.0}})
	w.document.execute("SetAnalysis",{"analysis":{"type":"transient_thermal","element":"TET4","time_step":0.01,"steps":200,"initial_temperature":400.0}})
	w.run_command("ApplyThermalBoundary",{"boundary":{"face":"InnerWall","kind":"temperature","value":300.0}})
	w.divisions.value=6;w.generate_analysis_mesh()
	var jobs=load("res://core/cae/extreme_jobs.gd").new()
	var missing=load("res://core/cae/extreme_jobs.gd").new();missing.solver_executable="res://.tools/absent-solver.exe"
	assert(missing.launch(w.document,1,256).is_empty() and missing.last_error.contains("missing"))
	w.open_extreme_mode()
	var spins: Array=[]
	for item in all(w.properties):
		if item is SpinBox:spins.append(item)
	spins[0].value=1;spins[1].value=256
	press(w,"Start independent job")
	var path: String=w.last_extreme_directory;assert(not path.is_empty())
	var deadline:=Time.get_ticks_msec()+15000
	while jobs.status(path).get("state") in ["Queued","Validating"] and Time.get_ticks_msec()<deadline:await process_frame
	print("Cancellation observation: ",jobs.status(path))
	assert(jobs.status(path).get("state")=="Running")
	var before: Dictionary=w.document.data.duplicate(true)
	press(w,"Cancel job",path)
	deadline=Time.get_ticks_msec()+15000
	while jobs.status(path).get("state")!="Cancelled" and Time.get_ticks_msec()<deadline:await process_frame
	assert(jobs.status(path).get("state")=="Cancelled")
	var process_info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/process.json"))
	deadline=Time.get_ticks_msec()+5000
	while OS.is_process_running(int(process_info.pid)) and Time.get_ticks_msec()<deadline:await process_frame
	assert(not OS.is_process_running(int(process_info.pid)))
	w.open_extreme_mode();press(w,"Open completed results",path)
	assert(w.document.data==before and w.status.text.contains("Cancelled"))
	# Recover with a valid, small steady job through the same UI.
	w.document.execute("SetAnalysis",{"analysis":{"type":"steady_thermal","element":"TET4"}})
	w.divisions.value=1;w.generate_analysis_mesh();w.open_extreme_mode();press(w,"Start independent job")
	path=w.last_extreme_directory;deadline=Time.get_ticks_msec()+15000
	while jobs.status(path).get("state")!="Completed" and Time.get_ticks_msec()<deadline:await process_frame
	w.open_extreme_mode();press(w,"Open completed results",path);assert(w.results_current())
	var valid: Dictionary=w.document.data.duplicate(true)
	var fixture: String="user://extreme_jobs/ui_failure_"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(fixture)
	for name in ["project.json","model.ucjob"]:write(fixture+"/"+name,FileAccess.get_file_as_string(path+"/"+name))
	write(fixture+"/status.json",'{"state":"Completed"}');write(fixture+"/results.json","{malformed")
	w.open_extreme_mode();press(w,"Open completed results",fixture);assert(w.document.data==valid and w.status.text.contains("Malformed"))
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/results.json"));raw.temperature[0]=NAN
	var snapshot: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/project.json"))
	assert(jobs.validate_provenance(path,snapshot,raw).contains("Invalid numerical"))
	raw.temperature[0]=null
	write(fixture+"/results.json",JSON.stringify(raw));w.open_extreme_mode();press(w,"Open completed results",fixture);assert(w.document.data==valid and w.status.text.contains("Invalid numerical"))
	write(fixture+"/model.ucjob","INVALID_JOB")
	var exit_code:=OS.execute(ProjectSettings.globalize_path("res://bin/unicore_solver.exe"),PackedStringArray(["--job",ProjectSettings.globalize_path(fixture+"/model.ucjob"),"--output",ProjectSettings.globalize_path(fixture)]))
	assert(exit_code!=0);w.open_extreme_mode();press(w,"Open completed results",fixture);assert(w.document.data==valid and w.status.text.contains("Failed"))
	w.open_extreme_mode();press(w,"Start independent job");path=w.last_extreme_directory
	deadline=Time.get_ticks_msec()+15000
	while jobs.status(path).get("state")!="Completed" and Time.get_ticks_msec()<deadline:await process_frame
	w.open_extreme_mode();press(w,"Open completed results",path);assert(w.results_current())
	write("res://docs/workbench-2/stage6-ui-failure-results.json",JSON.stringify({"cancel_state":"Cancelled","cancel_pid_stopped":true,"nonzero_native_exit":exit_code,"recovery":true,"malformed_and_nonfinite_rejected":true}))
	w.queue_free();await process_frame;print("UI cancellation/failure/recovery PASS");quit()
