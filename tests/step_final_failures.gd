extends SceneTree
var failures=0
func check(ok: bool, name: String):
	if not ok:failures+=1;push_error(name)
func _initialize():
	var backend=load("res://core/cae/calculix_backend.gd").new()
	var model={"schema":1,"units":"SI","analysis":"static_structural","nodes":[[0,0,0],[1,0,0],[0,1,0],[0,0,1]],"elements":[[0,1,2,3]],"material":{"E":1000.0,"nu":0.25},"constraints":[],"loads":[]}
	for text in ["", "displacements\n1 NaN 0 0\n", "displacements\n1 0 0\n", "stresses\n1 2 0 0 0 0 0 0\n"]:
		check(backend.parse_dat(text,model).has("error"),"Malformed/truncated result accepted")
	model.elements=[[0,1,2,99]]
	check(backend.input_deck(model).has("error"),"Invalid connectivity accepted")
	model.elements=[[0,1,2,3]]
	var dir="res://docs/architecture/evidence/step-final/oversize-"+str(Time.get_ticks_usec())
	var job=backend.prepare_job(model,dir)
	var file=FileAccess.open(dir+"/model.dat",FileAccess.WRITE);file.seek(32*1024*1024);file.store_8(0);file.close()
	check(backend.import_results(job).get("error","").contains("32 MiB"),"Oversized output accepted")
	DirAccess.remove_absolute(dir+"/model.dat")
	var document=load("res://core/cae/cae_document.gd").new()
	check(not document.execute("ImportSTEP",{"cad_base64":"AA==","cad_sha256":"invalid","name":"bad.step"}).is_empty(),"Corrupt STEP accepted")
	print("STEP_FINAL_FAILURES_", "PASS" if failures==0 else "FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)
