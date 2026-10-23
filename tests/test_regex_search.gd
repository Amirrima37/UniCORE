extends SceneTree

func _init() -> void:
	print("Testing regex on avatar_locomotion...")
	var f := FileAccess.open("res://modules/builtin/avatar_locomotion.gd", FileAccess.READ)
	var content := f.get_as_text()
	f.close()

	var r1 := RegEx.new()
	r1.compile("func\\s+get_module_id\\s*\\([^)]*\\)[^:]*:[^\"']*[\"']([^\"']+)[\"']")
	print("Searching r1...")
	var m := r1.search(content)
	print("Found r1: ", m.get_string(1) if m else "null")

	var r2 := RegEx.new()
	r2.compile("func\\s+get_module_name\\s*\\([^)]*\\)[^:]*:[^\"']*[\"']([^\"']+)[\"']")
	print("Searching r2...")
	var m2 := r2.search(content)
	print("Found r2: ", m2.get_string(1) if m2 else "null")
	quit(0)
