extends SceneTree
func _initialize():
	var original:=GDScript.new()
	original.source_code=FileAccess.get_file_as_string("res://.tools/stage51-baseline/structural_display.gd")
	assert(original.reload()==OK)
	var manager=load("res://core/cae/extreme_jobs.gd").new()
	var paths=JSON.parse_string(FileAccess.get_file_as_string("res://.tools/stage51-fixtures.json"))
	for name in ["Box-static_structural","Cylinder-static_structural"]:
		var data: Dictionary=manager.load_result(paths[name])
		var optimized=load("res://core/cae/structural_display.gd").new()
		for scale in [0.0,1.0,100.0]:
			for field in ["displacement","von_mises"]:
				var baseline: Dictionary=original.new().build(data.results,field,scale)
				var actual: Dictionary=optimized.build(data.results,field,scale)
				assert(baseline.mesh.surface_get_arrays(0)==actual.mesh.surface_get_arrays(0),name+field)
				assert(baseline.low==actual.low and baseline.high==actual.high)
				assert(optimized.build(data.results,field,scale).mesh==actual.mesh)
	print("Pre-optimization / optimized structural vertex-color-scalar buffers EXACT: HEX8/TET4, both fields, scales 0/1/100 PASS")
	quit()
