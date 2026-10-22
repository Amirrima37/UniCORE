class_name CodeValidator
extends RefCounted

## GDScript Security and Safety Validator for UniCORE
## Inspects generated GDScript code for dangerous operations, syntax flaws,
## and verifies UniCoreModule interface compliance before runtime injection.

# --- Regular Expressions for Security Checks ---
var _regex_dangerous_os: RegEx
var _regex_dangerous_dir_access: RegEx
var _regex_path_traversal: RegEx
var _regex_system_drive: RegEx
var _regex_unix_system_dir: RegEx
var _regex_res_write: RegEx
var _regex_non_user_write: RegEx
var _regex_dir_access_unsafe: RegEx
var _regex_dangerous_reflection: RegEx
var _regex_project_settings_save: RegEx

func _init() -> void:
	_init_security_regexes()

## Static convenience entry point for validating script source code
static func validate_script_source(code: String) -> Dictionary:
	var validator := CodeValidator.new()
	var res := validator.validate_module_code(code)
	var err := str(res.get("error", ""))
	return {
		"is_valid": res.get("is_valid", false),
		"error": err,
		"error_message": err
	}

## Main entry point to validate module source code
func validate_module_code(source_code: String) -> Dictionary:
	# 1. Basic emptiness check
	if source_code.strip_edges().is_empty():
		return {
			"is_valid": false,
			"error": "Module validation failed: source code is empty"
		}

	# 2. Security static analysis (prior to compilation & instantiation)
	var security_result := _perform_security_checks(source_code)
	if not security_result["is_valid"]:
		return security_result

	# 3. Syntax and compilation test using transient GDScript
	var script := GDScript.new()
	script.source_code = source_code
	var compile_err := script.reload()
	if compile_err != OK:
		return {
			"is_valid": false,
			"error": "GDScript syntax/compilation error (code %d)" % compile_err
		}

	# 4. Interface compliance and lifecycle checks
	var interface_result := _perform_interface_checks(script)
	if not interface_result["is_valid"]:
		return interface_result

	return {
		"is_valid": true,
		"error": ""
	}

# ==============================================================================
# Security Inspection
# ==============================================================================

func _init_security_regexes() -> void:
	# OS dangerous calls: execute, kill, crash, create_process, shell_open, set_environment
	_regex_dangerous_os = RegEx.new()
	_regex_dangerous_os.compile("\\b(?:OS|Engine\\.get_singleton\\s*\\(\\s*[\"']OS[\"']\\s*\\))\\s*\\.\\s*(execute|kill|crash|create_process|shell_open|set_environment)\\b")

	# DirAccess dangerous static / absolute calls
	_regex_dangerous_dir_access = RegEx.new()
	_regex_dangerous_dir_access.compile("\\bDirAccess\\s*\\.\\s*(remove_absolute|erase_contents_recursive|make_dir_absolute|make_dir_recursive_absolute|copy_absolute|rename_absolute)\\b")

	# Path traversal sequences like ../ or ..\
	_regex_path_traversal = RegEx.new()
	_regex_path_traversal.compile("[\"'][^\"']*\\.\\.[\\\\/][^\"']*[\"']")

	# Windows drive roots: e.g. "C:/...", 'D:\...'
	_regex_system_drive = RegEx.new()
	_regex_system_drive.compile("[\"'][a-zA-Z]:[\\\\/][^\"']*[\"']")

	# Unix system directories: e.g. /etc/, /bin/, /usr/, /tmp/, /var/
	_regex_unix_system_dir = RegEx.new()
	_regex_unix_system_dir.compile("[\"']/(?:etc|bin|usr|var|tmp|root|home|proc|sys|dev)/[^\"']*[\"']")

	# Modifying res:// via FileAccess (tampering with Core or project assets)
	_regex_res_write = RegEx.new()
	_regex_res_write.compile("\\bFileAccess\\s*\\.\\s*open(?:_compressed|_encrypted|_encrypted_with_pass)?\\s*\\(\\s*[\"']res:\\/\\/[^\"']*[\"']\\s*,\\s*(?:FileAccess\\s*\\.\\s*(?:WRITE|WRITE_READ|READ_WRITE)|[237])\\b")

	# File write operations outside user:// boundary
	_regex_non_user_write = RegEx.new()
	_regex_non_user_write.compile("\\bFileAccess\\s*\\.\\s*open(?:_compressed|_encrypted|_encrypted_with_pass)?\\s*\\(\\s*[\"'](?!user:\\/\\/)[^\"']+[\"']\\s*,\\s*(?:FileAccess\\s*\\.\\s*(?:WRITE|WRITE_READ|READ_WRITE)|[237])\\b")

	# Unsafe DirAccess operations (remove or open outside user://)
	_regex_dir_access_unsafe = RegEx.new()
	_regex_dir_access_unsafe.compile("\\bDirAccess\\s*\\.\\s*(?:remove|open)\\s*\\(\\s*[\"'](?!user:\\/\\/)[^\"']+[\"']\\s*\\)")

	# Dynamic / reflection bypass to dangerous functions
	_regex_dangerous_reflection = RegEx.new()
	_regex_dangerous_reflection.compile("\\.(?:call|call_deferred|callv)\\s*\\(\\s*[\"'](execute|kill|crash|create_process|shell_open|remove_absolute|erase_contents_recursive)[\"']")

	# Tampering with project settings file
	_regex_project_settings_save = RegEx.new()
	_regex_project_settings_save.compile("\\bProjectSettings\\s*\\.\\s*(?:save|save_custom)\\b")

func _perform_security_checks(source_code: String) -> Dictionary:
	# Strip line comments while respecting strings so comments don't produce false alarms
	var cleaned_code := _strip_comments(source_code)

	# 1. Dangerous OS calls
	var os_match := _regex_dangerous_os.search(cleaned_code)
	if os_match:
		return {
			"is_valid": false,
			"error": "Security violation: forbidden call to OS.%s detected" % os_match.get_string(1)
		}

	# 2. Dangerous DirAccess absolute operations
	var dir_match := _regex_dangerous_dir_access.search(cleaned_code)
	if dir_match:
		return {
			"is_valid": false,
			"error": "Security violation: forbidden call to DirAccess.%s detected" % dir_match.get_string(1)
		}

	# 3. Direct system drive access
	var drive_match := _regex_system_drive.search(cleaned_code)
	if drive_match:
		return {
			"is_valid": false,
			"error": "Security violation: direct system path detected outside safe sandbox (%s)" % drive_match.get_string()
		}

	# 4. Unix system directory access
	var unix_match := _regex_unix_system_dir.search(cleaned_code)
	if unix_match:
		return {
			"is_valid": false,
			"error": "Security violation: Unix system path detected outside safe sandbox (%s)" % unix_match.get_string()
		}

	# 5. Path traversal attempts
	var traversal_match := _regex_path_traversal.search(cleaned_code)
	if traversal_match:
		return {
			"is_valid": false,
			"error": "Security violation: path traversal sequence detected (%s)" % traversal_match.get_string()
		}

	# 6. Tampering with project res:// files
	var res_write_match := _regex_res_write.search(cleaned_code)
	if res_write_match:
		return {
			"is_valid": false,
			"error": "Security violation: modifying 'res://' files is forbidden"
		}

	# 7. File write operations outside user://
	var non_user_write_match := _regex_non_user_write.search(cleaned_code)
	if non_user_write_match:
		return {
			"is_valid": false,
			"error": "Security violation: direct system file tampering detected; file modifications outside 'user://' are forbidden"
		}

	# 8. Unsafe DirAccess manipulation outside user://
	var dir_unsafe_match := _regex_dir_access_unsafe.search(cleaned_code)
	if dir_unsafe_match:
		return {
			"is_valid": false,
			"error": "Security violation: directory manipulation outside 'user://' boundary is forbidden"
		}

	# 9. Reflection bypass attempts
	var reflection_match := _regex_dangerous_reflection.search(cleaned_code)
	if reflection_match:
		return {
			"is_valid": false,
			"error": "Security violation: forbidden reflection invocation of '%s'" % reflection_match.get_string(1)
		}

	# 10. ProjectSettings save tampering
	var settings_match := _regex_project_settings_save.search(cleaned_code)
	if settings_match:
		return {
			"is_valid": false,
			"error": "Security violation: modifying and saving ProjectSettings is forbidden"
		}

	return {
		"is_valid": true,
		"error": ""
	}

# ==============================================================================
# Interface Compliance & Lifecycle Checks
# ==============================================================================

func _perform_interface_checks(script: GDScript) -> Dictionary:
	if not script.can_instantiate():
		return {
			"is_valid": false,
			"error": "Interface compliance error: script cannot be instantiated"
		}

	# Verify constructor (_init) does not require arguments
	var init_method := _find_method_info(script, "_init")
	if not init_method.is_empty():
		var total_init_args: int = init_method.get("args", []).size()
		var default_init_args: int = init_method.get("default_args", []).size()
		var required_init_args: int = total_init_args - default_init_args
		if required_init_args > 0:
			return {
				"is_valid": false,
				"error": "Interface compliance error: '_init' requires %d arguments, but modules must be instantiable without arguments" % required_init_args
			}

	# Instantiate transient instance for runtime contract validation
	var instance = script.new()
	if not instance:
		return {
			"is_valid": false,
			"error": "Interface compliance error: failed to instantiate module script"
		}

	# Ensure instance extends Node (UniCoreModule inherits from Node)
	if not (instance is Node):
		var actual_type: String = instance.get_class()
		if not (instance is RefCounted):
			instance.free()
		return {
			"is_valid": false,
			"error": "Interface compliance error: module must extend Node or UniCoreModule (found %s)" % actual_type
		}

	var is_unicore_module: bool = (instance is UniCoreModule)

	# Essential lifecycle methods
	var required_lifecycle_methods := ["initialize", "cleanup", "get_module_id"]
	for method_name in required_lifecycle_methods:
		if not instance.has_method(method_name):
			instance.free()
			return {
				"is_valid": false,
				"error": "Interface compliance error: missing essential lifecycle method '%s' (modules must inherit UniCoreModule or implement the lifecycle contract)" % method_name
			}

	# Verify 'initialize' signature
	var initialize_method := _find_method_info(script, "initialize")
	if not initialize_method.is_empty():
		var total_args: int = initialize_method.get("args", []).size()
		var default_args: int = initialize_method.get("default_args", []).size()
		var required_args: int = total_args - default_args
		if total_args < 1 or required_args > 1:
			instance.free()
			return {
				"is_valid": false,
				"error": "Interface compliance error: 'initialize' method must accept a context argument (e.g. initialize(context: Dictionary))"
			}

	# Verify 'cleanup' signature (must be callable with 0 arguments)
	var cleanup_method := _find_method_info(script, "cleanup")
	if not cleanup_method.is_empty():
		var total_args: int = cleanup_method.get("args", []).size()
		var default_args: int = cleanup_method.get("default_args", []).size()
		var required_args: int = total_args - default_args
		if required_args > 0:
			instance.free()
			return {
				"is_valid": false,
				"error": "Interface compliance error: 'cleanup' method must not require arguments"
			}

	# Verify 'get_module_id' signature (must be callable with 0 arguments)
	var get_id_method := _find_method_info(script, "get_module_id")
	if not get_id_method.is_empty():
		var total_args: int = get_id_method.get("args", []).size()
		var default_args: int = get_id_method.get("default_args", []).size()
		var required_args: int = total_args - default_args
		if required_args > 0:
			instance.free()
			return {
				"is_valid": false,
				"error": "Interface compliance error: 'get_module_id' method must not require arguments"
			}

	# Transient instance passed all checks; safely clean it up
	instance.free()

	return {
		"is_valid": true,
		"error": ""
	}

# ==============================================================================
# Helper Utilities
# ==============================================================================

## Removes line comments (# ...) while preserving quotes and newlines
static func _strip_comments(code: String) -> String:
	var result := ""
	var i := 0
	var length := code.length()
	var in_single_quote := false
	var in_double_quote := false
	var in_multiline_single := false
	var in_multiline_double := false

	while i < length:
		var c := code[i]
		var next_three := code.substr(i, 3)
		var is_escaped := _is_char_escaped(code, i)

		# Multiline string boundaries
		if not in_single_quote and not in_double_quote:
			if not in_multiline_single and not in_multiline_double:
				if next_three == '"""':
					in_multiline_double = true
					result += '"""'
					i += 3
					continue
				elif next_three == "'''":
					in_multiline_single = true
					result += "'''"
					i += 3
					continue
			elif in_multiline_double and next_three == '"""' and not is_escaped:
				in_multiline_double = false
				result += '"""'
				i += 3
				continue
			elif in_multiline_single and next_three == "'''" and not is_escaped:
				in_multiline_single = false
				result += "'''"
				i += 3
				continue

		# Inside multiline string literal
		if in_multiline_double or in_multiline_single:
			result += c
			i += 1
			continue

		# Single-line string boundaries
		if c == '"' and not in_single_quote and not is_escaped:
			in_double_quote = not in_double_quote
			result += c
			i += 1
			continue
		elif c == "'" and not in_double_quote and not is_escaped:
			in_single_quote = not in_single_quote
			result += c
			i += 1
			continue

		# Inside normal code: strip comments
		if not in_double_quote and not in_single_quote:
			if c == '#':
				while i < length and code[i] != '\n':
					result += " "
					i += 1
				if i < length and code[i] == '\n':
					result += '\n'
					i += 1
				continue

		result += c
		i += 1

	return result

## Checks if the character at index is escaped by an odd number of preceding backslashes
static func _is_char_escaped(text: String, index: int) -> bool:
	var backslash_count := 0
	var j := index - 1
	while j >= 0 and text[j] == "\\":
		backslash_count += 1
		j -= 1
	return (backslash_count % 2) == 1

## Resolves method info dictionary from the script or any base script
static func _find_method_info(script: GDScript, method_name: String) -> Dictionary:
	var current: GDScript = script
	while current:
		for method in current.get_script_method_list():
			if method.get("name", "") == method_name:
				return method
		current = current.get_base_script()
	return {}
