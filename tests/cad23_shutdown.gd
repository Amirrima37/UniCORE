extends SceneTree
func _initialize():
	var w=load("res://ui/cae/cae_workspace.gd").new();root.add_child.call_deferred(w);await process_frame;w.set_active(true)
	var error=w.document.open_project("res://docs/architecture/evidence/cad23/tet10-axial-bar.ucae")
	if not error.is_empty():push_error(error);quit(1);return
	w.selected=0
	var mode=OS.get_environment("CAD23_SHUTDOWN_MODE")
	if mode=="mesh":w.generate_analysis_mesh()
	else:w.solve()
	var deadline=Time.get_ticks_msec()+30000;var observed=false;var path=""
	while Time.get_ticks_msec()<deadline:
		var engine=w.native_solver
		if engine!=null:
			path=engine.directory
			if not path.is_empty() and FileAccess.file_exists(path+"/running.json"):
				var running=JSON.parse_string(FileAccess.get_file_as_string(path+"/running.json"))
				if running is Dictionary and (mode=="mesh" or str(running.get("executable","")).ends_with("ccx.exe")):
					var output=[];var code=OS.execute(OS.get_environment("UNICORE_PYTHON"),PackedStringArray([ProjectSettings.globalize_path("res://tests/cad22_pid_probe.py"),str(int(running.pid))]),output,true)
					if code==0:observed=true;break
		await process_frame
	var f=FileAccess.open(preload("res://tests/development_paths.gd").output_file("CAD/cad23/shutdown-")+mode+".json",FileAccess.WRITE);f.store_string(JSON.stringify({"observed":observed,"directory":ProjectSettings.globalize_path(path)}));f.close()
	# Actual SceneTree teardown invokes Workbench owned-job shutdown.
	quit(0 if observed else 1)
