extends SceneTree
func _initialize():
	var backend=preload("res://core/cae/calculix_backend.gd").new()
	var model={"schema":1,"units":"SI","analysis":"static_structural","nodes":[[0,0,0],[1,0,0],[0,1,0],[0,0,1]],"elements":[[0,1,2,3]],"material":{"E":1000.0,"nu":0.25},"constraints":[[0,0,0],[0,1,0],[0,2,0],[2,0,0],[2,2,0],[3,0,0]],"loads":[[1,0,1.0]]}
	var deck=backend.input_deck(model)
	if deck.has("error"): push_error(deck.error); quit(1); return
	DirAccess.make_dir_recursive_absolute("res://.tools/engines/ccx-test")
	var file=FileAccess.open("res://.tools/engines/ccx-test/model.inp",FileAccess.WRITE)
	file.store_string(deck.text); file.close()
	assert("C3D4" in deck.text)
	model.elements=[[0,2,1,3]]
	assert(not backend.validate_model(model).is_empty())
	print("CALCULIX_EXPORT_PASS")
	quit()
