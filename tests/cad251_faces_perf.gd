extends SceneTree
func _init():
	var out=OS.get_environment("UNICORE_FACE_OUT")
	var d=preload("res://core/cae/cae_document.gd").new()
	assert(d.open_project(out+"/reassigned2.json").is_empty())
	var id=d.data.parts[0].instance_uuid;var face_id=d.data.parts[0].load_face
	var times=[]
	for i in 20:
		var start=Time.get_ticks_usec()
		assert(d.execute("ApplyLoad",{"index":0,"face":face_id,"force":[0,500 if i%2 else 1000,0]}).is_empty())
		times.append(Time.get_ticks_usec()-start)
	assert(d.data.parts[0].instance_uuid==id and d.data.parts[0].boundary_refs.load_face.state=="resolved")
	var f=FileAccess.open(out+"/reassignment-performance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"iterations":times.size(),"document_mutation_microseconds":times,"native_recomputation":false},"  "));f.close()
	print("FACE_PERFORMANCE_PASS");quit()
