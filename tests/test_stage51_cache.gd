extends SceneTree
func _initialize():
	var paths=JSON.parse_string(FileAccess.get_file_as_string("res://.tools/stage51-fixtures.json"))
	var manager=load("res://core/cae/extreme_jobs.gd").new()
	var source: Dictionary=manager.load_result(paths["Cylinder-static_structural"])
	assert(not source.is_empty(),manager.last_error)
	var identity=load("res://core/cae/result_identity.gd").new()
	assert(identity.current(source))
	var generation: int=identity.generation
	assert(identity.current(source) and identity.generation==generation)
	for dependency in ["revision","geometry","material","boundary","analysis","coordinate","ordering","connectivity","region","import"]:
		var changed: Dictionary=source.duplicate(true)
		match dependency:
			"revision":changed.revision+=1
			"geometry":changed.parts[0].position[0]+=0.1
			"material":changed.parts[0].material.E*=2
			"boundary":changed.parts[0].force[1]*=2
			"analysis":changed.analysis.type="steady_thermal"
			"coordinate":changed.mesh.nodes[0][0]+=0.01
			"ordering":changed.mesh.nodes.reverse()
			"connectivity":changed.mesh.elements[0].reverse()
			"region":changed.mesh.material_regions[0]="wrong"
			"import":changed.results.source_mesh_sha256="unrelated"
		assert(not identity.current(changed),dependency)
		assert(identity.generation>generation,dependency)
		assert(identity.current(source))
		generation=identity.generation
	var display=load("res://core/cae/structural_display.gd").new()
	var first=display.build(source.results,"von_mises",1)
	var again=display.build(source.results,"von_mises",1)
	assert(first.mesh==again.mesh and display.timings.get("cache_hit",false))
	var changed: Dictionary=source.duplicate(true)
	changed.results.von_mises[0]+=100
	assert(identity.current(changed) and identity.generation>generation)
	var replaced=display.build(changed.results,"von_mises",1)
	assert(replaced.mesh!=first.mesh)
	assert(display.build(source.results,"von_mises",2).mesh!=first.mesh)
	print("Exact-state cache invalidation / bypassed revisions / field mutation / resource reuse PASS")
	quit()
