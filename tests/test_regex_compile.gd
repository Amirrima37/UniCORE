extends SceneTree

func _init() -> void:
	print("Compiling regex 1")
	var r1 := RegEx.new()
	r1.compile("func get_module_id\\(\\)[^:]*:[^\"']*[\"']([^\"']+)[\"']")
	print("Compiled regex 1")

	print("Compiling regex 2")
	var r2 := RegEx.new()
	r2.compile("func get_module_name\\(\\)[^:]*:[^\"']*[\"']([^\"']+)[\"']")
	print("Compiled regex 2")

	print("Compiling regex 3")
	var r3 := RegEx.new()
	r3.compile("(func\\s+get_module_id\\s*\\([^)]*\\)[^:]*:[^\"'\\r\\n]*(?:\\r?\\n[ \\t]*return[ \\t]+|[ \\t]*return[ \\t]+)?)[ \"']([^\"']+)[ \"']")
	print("Compiled regex 3")
	quit(0)
