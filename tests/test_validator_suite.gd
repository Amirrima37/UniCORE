extends SceneTree

# Automated Test Suite for CodeValidator

var passed_count := 0
var failed_count := 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func _init() -> void:
	print("==================================================")
	print("Starting CodeValidator Test Suite")
	print("==================================================")
	
	var validator := CodeValidator.new()
	
	# Test 1: Empty source code
	var res := validator.validate_module_code("")
	assert_false(res["is_valid"], "Empty source rejected", res["error"])
	res = validator.validate_module_code("   \n\t  ")
	assert_false(res["is_valid"], "Whitespace-only source rejected", res["error"])
	
	# Test 2: Valid UniCoreModule
	var valid_unicore := """extends UniCoreModule

func get_module_id() -> String:
	return "test_valid_module"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	return true

func cleanup() -> void:
	super.cleanup()
"""
	res = validator.validate_module_code(valid_unicore)
	assert_true(res["is_valid"], "Valid UniCoreModule passes", res["error"])
	
	# Test 3: Valid Standalone Node module (duck-typing interface contract)
	var valid_node := """extends Node3D

func get_module_id() -> String:
	return "custom_node_module"

func initialize(context: Dictionary) -> bool:
	return true

func cleanup() -> void:
	queue_free()
"""
	res = validator.validate_module_code(valid_node)
	assert_true(res["is_valid"], "Valid Standalone Node3D module passes", res["error"])
	
	# Test 4: Existing builtin modules pass validation
	var ground_plane_file := FileAccess.open("res://modules/builtin/ground_plane.gd", FileAccess.READ)
	if ground_plane_file:
		var code := ground_plane_file.get_as_text()
		ground_plane_file.close()
		res = validator.validate_module_code(code)
		assert_true(res["is_valid"], "Built-in ground_plane.gd passes validation", res["error"])
	else:
		assert_true(false, "Built-in ground_plane.gd found", "Could not open file")
		
	var avatar_file := FileAccess.open("res://modules/builtin/avatar_locomotion.gd", FileAccess.READ)
	if avatar_file:
		var code := avatar_file.get_as_text()
		avatar_file.close()
		res = validator.validate_module_code(code)
		assert_true(res["is_valid"], "Built-in avatar_locomotion.gd passes validation", res["error"])
	else:
		assert_true(false, "Built-in avatar_locomotion.gd found", "Could not open file")

	# Test 5: Security - OS.execute
	var code_os_exec := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	OS.execute("calc.exe", [])
	return true
"""
	res = validator.validate_module_code(code_os_exec)
	assert_false(res["is_valid"], "OS.execute rejected", res["error"])
	assert_true("OS.execute" in res["error"], "Error mentions OS.execute")

	# Test 6: Security - OS.kill
	var code_os_kill := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	OS.kill(9999)
	return true
"""
	res = validator.validate_module_code(code_os_kill)
	assert_false(res["is_valid"], "OS.kill rejected", res["error"])
	assert_true("OS.kill" in res["error"], "Error mentions OS.kill")

	# Test 7: Security - OS.crash
	var code_os_crash := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	OS.crash("Forced crash")
	return true
"""
	res = validator.validate_module_code(code_os_crash)
	assert_false(res["is_valid"], "OS.crash rejected", res["error"])
	assert_true("OS.crash" in res["error"], "Error mentions OS.crash")

	# Test 8: Security - OS.create_process
	var code_os_proc := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	OS.create_process("bash", [])
	return true
"""
	res = validator.validate_module_code(code_os_proc)
	assert_false(res["is_valid"], "OS.create_process rejected", res["error"])

	# Test 9: Security - DirAccess.remove_absolute
	var code_dir_rm := """extends UniCoreModule
func cleanup() -> void:
	DirAccess.remove_absolute("user://temp.txt")
"""
	res = validator.validate_module_code(code_dir_rm)
	assert_false(res["is_valid"], "DirAccess.remove_absolute rejected", res["error"])
	assert_true("DirAccess.remove_absolute" in res["error"], "Error mentions DirAccess.remove_absolute")

	# Test 10: Security - File tampering: absolute system drive path
	var code_sys_drive := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	var f = FileAccess.open("C:/evil.bat", FileAccess.WRITE)
	return true
"""
	res = validator.validate_module_code(code_sys_drive)
	assert_false(res["is_valid"], "System drive C:/ path rejected", res["error"])

	# Test 11: Security - File tampering: Unix root system path
	var code_unix_root := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	var f = FileAccess.open("/etc/passwd", FileAccess.WRITE)
	return true
"""
	res = validator.validate_module_code(code_unix_root)
	assert_false(res["is_valid"], "Unix /etc path rejected", res["error"])

	# Test 12: Security - File tampering: Path traversal
	var code_traversal := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	var f = FileAccess.open("user://../escape.txt", FileAccess.WRITE)
	return true
"""
	res = validator.validate_module_code(code_traversal)
	assert_false(res["is_valid"], "Path traversal .. rejected", res["error"])

	# Test 13: Security - File tampering: writing to res://
	var code_res_write := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	var f = FileAccess.open("res://core/base_module.gd", FileAccess.WRITE)
	return true
"""
	res = validator.validate_module_code(code_res_write)
	assert_false(res["is_valid"], "Modifying res:// rejected", res["error"])

	# Test 14: Security - Reflection evasion
	var code_reflect := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	self.call("execute", "notepad.exe")
	return true
"""
	res = validator.validate_module_code(code_reflect)
	assert_false(res["is_valid"], "Reflection call('execute') rejected", res["error"])

	# Test 15: Safe comments containing forbidden words should NOT be rejected
	var code_safe_comment := """extends UniCoreModule
# Note: we do not use OS.execute, OS.kill, or DirAccess.remove_absolute here.
# Nor do we write to C:/ or res://.
func get_module_id() -> String:
	return "module_with_comments"
"""
	res = validator.validate_module_code(code_safe_comment)
	assert_true(res["is_valid"], "Harmless comments mentioning keywords pass", res["error"])

	# Test 16: Safe user:// file operations should PASS
	var code_safe_user_file := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	var f = FileAccess.open("user://module_data.json", FileAccess.WRITE)
	if f:
		f.store_string("{}")
		f.close()
	return true
"""
	res = validator.validate_module_code(code_safe_user_file)
	assert_true(res["is_valid"], "Safe write to user:// passes", res["error"])

	# Test 17: Syntax error
	var code_syntax_err := """extends UniCoreModule
func broken syntax (())(()
"""
	res = validator.validate_module_code(code_syntax_err)
	assert_false(res["is_valid"], "Syntax error rejected", res["error"])
	assert_true("syntax/compilation error" in res["error"], "Error reports syntax/compilation error")

	# Test 18: Interface compliance - Not extending Node (e.g. RefCounted)
	var code_refcounted := """extends RefCounted
func get_module_id() -> String:
	return "bad"
"""
	res = validator.validate_module_code(code_refcounted)
	assert_false(res["is_valid"], "Extending RefCounted rejected", res["error"])
	assert_true("must extend Node or UniCoreModule" in res["error"], "Error specifies must extend Node")

	# Test 19: Interface compliance - Node missing lifecycle methods
	var code_missing_lifecycle := """extends Node
var some_var = 1
"""
	res = validator.validate_module_code(code_missing_lifecycle)
	assert_false(res["is_valid"], "Missing lifecycle methods rejected", res["error"])
	assert_true("lifecycle" in res["error"], "Error mentions lifecycle")

	# Test 20: Interface compliance - Invalid initialize signature (missing context arg)
	var code_bad_init_sig := """extends Node
func get_module_id() -> String:
	return "test"
func initialize() -> bool:
	return true
func cleanup() -> void:
	pass
"""
	res = validator.validate_module_code(code_bad_init_sig)
	assert_false(res["is_valid"], "initialize() without context arg rejected", res["error"])
	assert_true("context" in res["error"], "Error mentions context argument")

	# Test 21: Interface compliance - Required constructor arguments in _init
	var code_bad_ctor := """extends UniCoreModule
func _init(mandatory_arg: int):
	pass
"""
	res = validator.validate_module_code(code_bad_ctor)
	assert_false(res["is_valid"], "_init with mandatory args rejected", res["error"])

	# Test 22: Security - OS.shell_open
	var code_shell := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	OS.shell_open("https://malicious.site")
	return true
"""
	res = validator.validate_module_code(code_shell)
	assert_false(res["is_valid"], "OS.shell_open rejected", res["error"])
	assert_true("OS.shell_open" in res["error"], "Error mentions OS.shell_open")

	# Test 23: Security - OS.set_environment
	var code_setenv := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	OS.set_environment("EVIL", "1")
	return true
"""
	res = validator.validate_module_code(code_setenv)
	assert_false(res["is_valid"], "OS.set_environment rejected", res["error"])
	assert_true("OS.set_environment" in res["error"], "Error mentions OS.set_environment")

	# Test 24: Security - DirAccess.erase_contents_recursive
	var code_erase := """extends UniCoreModule
func cleanup() -> void:
	DirAccess.erase_contents_recursive("user://")
"""
	res = validator.validate_module_code(code_erase)
	assert_false(res["is_valid"], "DirAccess.erase_contents_recursive rejected", res["error"])

	# Test 25: Security - DirAccess.make_dir_absolute
	var code_mkdir := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	DirAccess.make_dir_absolute("C:/malicious")
	return true
"""
	res = validator.validate_module_code(code_mkdir)
	assert_false(res["is_valid"], "DirAccess.make_dir_absolute rejected", res["error"])

	# Test 26: Security - ProjectSettings.save
	var code_settings := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	ProjectSettings.save()
	return true
"""
	res = validator.validate_module_code(code_settings)
	assert_false(res["is_valid"], "ProjectSettings.save rejected", res["error"])

	# Test 27: Security - Reflection via call_deferred
	var code_reflect_deferred := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	self.call_deferred("execute", "notepad.exe")
	return true
"""
	res = validator.validate_module_code(code_reflect_deferred)
	assert_false(res["is_valid"], "Reflection call_deferred('execute') rejected", res["error"])

	# Test 28: Security - Engine.get_singleton("OS")
	var code_engine_os := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	Engine.get_singleton("OS").execute("calc.exe", [])
	return true
"""
	res = validator.validate_module_code(code_engine_os)
	assert_false(res["is_valid"], "Engine.get_singleton('OS').execute rejected", res["error"])

	# Test 29: Interface compliance - Missing get_module_id
	var code_no_id := """extends Node
func initialize(context: Dictionary) -> bool:
	return true
func cleanup() -> void:
	pass
"""
	res = validator.validate_module_code(code_no_id)
	assert_false(res["is_valid"], "Missing get_module_id rejected", res["error"])
	assert_true("get_module_id" in res["error"], "Error mentions get_module_id")

	# Test 30: Interface compliance - cleanup requiring arguments
	var code_cleanup_args := """extends Node
func get_module_id() -> String:
	return "test"
func initialize(context: Dictionary) -> bool:
	return true
func cleanup(forced: bool) -> void:
	pass
"""
	res = validator.validate_module_code(code_cleanup_args)
	assert_false(res["is_valid"], "cleanup with mandatory args rejected", res["error"])

	print("==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")
	
	if failed_count == 0:
		quit(0)
	else:
		quit(1)
