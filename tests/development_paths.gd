extends RefCounted
static func godot_environment(relative: String = "") -> String:
	var root=OS.get_environment("UNICORE_GODOT_ENV_ROOT")
	if root.is_empty(): root="D:/PROJECT/GODOT/TEST_ENVIRONMENTS/godot472-migration"
	return root.path_join(relative)
static func output(relative: String) -> String:
	var root=OS.get_environment("UNICORE_TEST_OUTPUT_ROOT")
	if root.is_empty(): root="D:/PROJECT/TEST_OUTPUTS"
	var path=root.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path)
	return path
static func output_file(relative: String) -> String:
	return output(relative.get_base_dir()).path_join(relative.get_file())
