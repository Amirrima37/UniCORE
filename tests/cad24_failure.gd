extends SceneTree
func fail(message: String):push_error(message);quit(1)
func _initialize():
	var job=preload("res://core/cae/cad_geometry_job.gd").new()
	var model={"schema":1,"units":"m","root":"cut","nodes":[{"id":"base","type":"Box","dimensions":[.1,.2,.1]},{"id":"tool","type":"Cylinder","dimensions":[.04,.3,.04]},{"id":"cut","type":"Cut","base":"base","tool":"tool"}]}
	var mode=OS.get_environment("UNICORE_CAD24_FAULT_MODE")
	if mode=="cancel-step":
		var raw=FileAccess.get_file_as_bytes("res://tests/fixtures/step/bar.step")
		model={"schema":1,"units":"m","root":"step","nodes":[{"id":"step","type":"STEP","source_base64":Marshalls.raw_to_base64(raw),"source_sha256":preload("res://core/cae/cae_document.gd").cad_sha256(raw)}]}
	if mode=="timeout":OS.set_environment("UNICORE_OCCT_TIMEOUT_S","0")
	var request={"model":model,"quality":20};var worker=Thread.new();worker.start(func():return job.evaluate(request))
	while job.directory.is_empty():await process_frame
	var f=FileAccess.open(preload("res://tests/development_paths.gd").output_file("CAD/cad24-completion/fault-owner.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"job":ProjectSettings.globalize_path(job.directory),"godot_pid":OS.get_process_id()}));f.close()
	var heartbeat=0
	while worker.is_alive():heartbeat+=1;await process_frame
	var failed=worker.wait_to_finish()
	if failed.get("ok",false):fail("Expected externally terminated native worker");return
	print("CAD24_EXPECTED_ERROR ",failed.get("error"))
	OS.unset_environment("UNICORE_OCCT_TIMEOUT_S")
	job=preload("res://core/cae/cad_geometry_job.gd").new();worker=Thread.new();worker.start(func():return job.evaluate(request))
	while worker.is_alive():heartbeat+=1;await process_frame
	var recovered=worker.wait_to_finish()
	if not recovered.get("ok",false):fail("Native recovery: "+str(recovered));return
	print("CAD24_FAILURE_RECOVERY_PASS heartbeat=",heartbeat);quit()
