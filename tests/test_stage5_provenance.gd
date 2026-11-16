extends SceneTree
func _initialize():
	create_timer(45).timeout.connect(func():quit(2))
	var doc=load("res://core/cae/cae_document.gd").new()
	var manager=load("res://core/cae/extreme_jobs.gd").new()
	doc.execute("CreatePart",{"kind":"Cylinder"})
	doc.execute("AssignMaterialById",{"index":0,"material_id":"Aluminum 6061-T6"})
	doc.execute("ApplySupport",{"index":0,"face":"Bottom"})
	doc.execute("ApplyLoad",{"index":0,"face":"Top","force":[0,1,0]})
	doc.generate_mesh(1)
	var directory: String=manager.launch(doc,1,256)
	assert(not directory.is_empty(),manager.last_error)
	while manager.status(directory).get("state")!="Completed":await process_frame
	var loaded: Dictionary=manager.load_result(directory,doc.data)
	assert(not loaded.is_empty(),manager.last_error)
	var snapshot=JSON.parse_string(FileAccess.get_file_as_string(directory+"/project.json"))
	var result=JSON.parse_string(FileAccess.get_file_as_string(directory+"/results.json"))
	for key in ["revision","nodes","elements","regions"]:
		var changed: Dictionary=snapshot.duplicate(true)
		if key=="revision":changed.revision+=1
		elif key=="nodes":changed.extreme_mesh.nodes.reverse()
		elif key=="elements":changed.extreme_mesh.elements[0].reverse()
		else:changed.extreme_mesh.material_regions[0]="wrong"
		assert(not manager.validate_provenance(directory,changed,result).is_empty())
	var current: Dictionary=doc.data.duplicate(true)
	var job_text:=FileAccess.get_file_as_string(directory+"/model.ucjob")
	var job_file:=FileAccess.open(directory+"/model.ucjob",FileAccess.WRITE)
	job_file.store_string(job_text+"\n");job_file.close()
	assert("input changed" in manager.validate_provenance(directory,snapshot,result))
	job_file=FileAccess.open(directory+"/model.ucjob",FileAccess.WRITE)
	job_file.store_string(job_text);job_file.close()
	var invalid: Dictionary=result.duplicate(true)
	invalid.stress[0]=[1,2]
	assert("width" in manager.validate_provenance(directory,snapshot,invalid))
	current.revision+=1
	assert(manager.load_result(directory,current).is_empty())
	result.input_fingerprint="0"
	assert(not manager.validate_provenance(directory,snapshot,result).is_empty())
	result.erase("provenance_version")
	assert("Legacy" in manager.validate_provenance(directory,snapshot,result))
	print("Extreme provenance valid / ordering / connectivity / region / revision / swapped result / legacy rejection PASS")
	quit()
