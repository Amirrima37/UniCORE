extends SceneTree

func _init() -> void:
	var r1 := RegEx.new()
	r1.compile("func\\s+get_module_id\\s*\\([^)]*\\)[^:]*:[^\"']*[\"']([^\"']+)[\"']")

	for path in ["res://modules/cube_spawner_tool.gd", "res://modules/builtin/ground_plane.gd"]:
		print("Checking: ", path)
		var f := FileAccess.open(path, FileAccess.READ)
		var content := f.get_as_text()
		f.close()
		var m := r1.search(content)
		print("Result: ", m.get_string(1) if m else "null")
	quit(0)
