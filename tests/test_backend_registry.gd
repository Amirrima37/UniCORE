extends SceneTree
func _initialize():
	var entries = preload("res://core/cae/backend_registry.gd").new().discover()
	assert(entries.size() == 1)
	assert(entries[0].id == "extreme_cpu")
	assert(entries[0].status != "numerically_validated")
	var adapter = preload("res://core/cae/solver_backend.gd").new()
	assert(not adapter.validate_model({}).is_empty())
	assert(adapter.execute_job({}).has("error"))
	print("BACKEND_REGISTRY_PASS")
	quit()
