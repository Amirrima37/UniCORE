extends SceneTree
func _init():
	var out=OS.get_environment("UNICORE_PLACEMENT_OUT")
	var d=preload("res://core/cae/cae_document.gd").new()
	assert(d.open_project(out+"/rotated2.json").is_empty())
	var identity=d.data.parts[0].definition_uuid
	assert(d.execute("RotateInstanceAxis",{"index":0,"axis":[1,2,3],"angle":0.7}).is_empty())
	assert(d.data.parts[0].definition_uuid==identity)
	assert(d.save_project(out+"/final-schema.json")==OK)
	var reopened=preload("res://core/cae/cae_document.gd").new()
	assert(reopened.open_project(out+"/final-schema.json").is_empty())
	assert(reopened.data.parts[0].definition_uuid==identity)
	var f=FileAccess.open(out+"/axis-instance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(reopened.data.parts[0],"",true,true));f.close()
	assert(load("res://ui/cae/cae_workspace.gd")!=null)
	print("FINAL_SCHEMA_AXIS_PASS")
	quit()
