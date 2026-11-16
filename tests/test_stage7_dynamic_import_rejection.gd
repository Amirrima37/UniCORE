extends SceneTree
func write(path: String,text: String):
	var file=FileAccess.open(path,FileAccess.WRITE);assert(file!=null);file.store_string(text);file.close()
func _initialize():
	var args:=OS.get_cmdline_user_args();assert(args.size()==1)
	var source: String=args[0]
	var jobs=load("res://core/cae/extreme_jobs.gd").new()
	for name in ["cancel-running","nonconvergence"]:
		assert(jobs.load_result(source+"/"+name).is_empty())
		assert(jobs.last_error.contains("not completed"))
	var directory: String="res://.tools/dynamic-import-"+str(Time.get_ticks_usec())
	assert(DirAccess.make_dir_recursive_absolute(directory)==OK)
	var bytes:=FileAccess.get_file_as_bytes(source+"/recovery.ucjob")
	var file=FileAccess.open(directory+"/model.ucjob",FileAccess.WRITE);file.store_buffer(bytes);file.close()
	var snapshot: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/workbench-2/stage6-final/native-jobs/0/project.json"))
	snapshot.extreme_provenance.job_sha256=FileAccess.get_sha256(directory+"/model.ucjob")
	snapshot.extreme_provenance.snapshot_sha256=jobs.snapshot_digest(snapshot)
	write(directory+"/project.json",JSON.stringify(snapshot,"",true,true))
	write(directory+"/status.json",'{"state":"Completed"}')
	var result: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source+"/recovery/results.json"))
	write(directory+"/results.json",JSON.stringify(result,"",true,true))
	assert(jobs.load_result(directory).is_empty())
	assert(jobs.last_error.contains("Invalid result field mapping")) # No transient importer is exposed.
	write(directory+"/results.json",'{"ok":')
	assert(jobs.load_result(directory).is_empty() and jobs.last_error.contains("Malformed"))
	result.frames.pop_back();write(directory+"/results.json",JSON.stringify(result,"",true,true))
	assert(jobs.load_result(directory).is_empty())
	print("Existing Workbench importer rejects native failed/cancelled jobs, unsupported dynamic fields, malformed and incomplete output: 5 rejection paths PASS")
	quit()
