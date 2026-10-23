extends SceneTree

# Automated Test Suite for DiagnosticLogger and AgentDiagnostic (UniCORE)

const DiagnosticLogger = preload("res://core/diagnostic_logger.gd")
const AgentDiagnostic = preload("res://core/agent_diagnostic.gd")

var passed_count: int = 0
var failed_count: int = 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	if actual == expected:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s - Expected '%s', got '%s'" % [test_name, str(expected), str(actual)])
		failed_count += 1

class MockLLMProvider extends BaseLLMProvider:
	var next_response: String = ""
	var next_error: String = ""
	var ignore_send: bool = false

	func send_prompt(_system_prompt: String, _user_prompt: String, _api_key: String) -> void:
		if ignore_send:
			return
		if not next_error.is_empty():
			var err = next_error
			next_error = ""
			request_failed.emit(err)
		elif not next_response.is_empty():
			var resp = next_response
			next_response = ""
			response_received.emit(resp)

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE DiagnosticLogger & Diagnostic Suite")
	print("==================================================")

	_test_diagnostic_logger_basics()
	_test_static_logging_methods()
	_test_ring_buffer_overflow()
	_test_category_filtering()
	_test_entry_lookup_and_clipboard()
	_test_disk_persistence_and_export()
	_test_agent_diagnostic_parsing()
	_test_agent_brain_integration()

	print("==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		quit(0)
	else:
		quit(1)

func _test_diagnostic_logger_basics() -> void:
	print("\n--- Testing DiagnosticLogger Basics & Signals ---")
	var logger = DiagnosticLogger.new()
	logger.clear()

	assert_eq(logger.get_recent_entries().size(), 0, "Initial entries buffer is empty")

	var signal_captured: Array = []
	logger.entry_added.connect(func(entry: Dictionary):
		signal_captured.append(entry)
	)

	# 1. log_agent
	var entry1: Dictionary = logger.log_agent("INFO", "Agent Ready", "Agent initialized", "Extra details", {"version": "1.0"})
	assert_eq(entry1.get("id"), 1, "First entry has id 1")
	assert_eq(entry1.get("category"), "AGENT", "Category is AGENT")
	assert_eq(entry1.get("level"), "INFO", "Level is INFO")
	assert_eq(entry1.get("title"), "Agent Ready", "Title matches")
	assert_eq(entry1.get("message"), "Agent initialized", "Message matches")
	assert_eq(entry1.get("details"), "Extra details", "Details match")
	assert_true(entry1.get("timestamp") > 0, "Timestamp is positive float")
	assert_false(str(entry1.get("time_str")).is_empty(), "time_str is non-empty")

	assert_eq(signal_captured.size(), 1, "entry_added signal fired once")
	assert_eq(signal_captured[0].get("id"), 1, "Signal payload matches entry")

	# 2. log_system
	var entry2: Dictionary = logger.log_system("WARN", "Memory Alert", "Approaching limit")
	assert_eq(entry2.get("id"), 2, "Second entry has id 2")
	assert_eq(entry2.get("category"), "SYSTEM", "Category is SYSTEM")
	assert_eq(entry2.get("level"), "WARN", "Level is WARN")
	assert_eq(entry2.get("title"), "Memory Alert", "Title matches")
	assert_eq(entry2.get("message"), "Approaching limit", "Message matches")
	assert_eq(signal_captured.size(), 2, "entry_added signal fired twice")

	# 3. log_diagnostic dictionary helper
	var diag_input: Dictionary = {
		"category": "NET",
		"level": "ERROR",
		"title": "Network Lost",
		"user_message": "Connection closed",
		"details": "Socket timeout",
		"raw_data": {"port": 443}
	}
	var entry3: Dictionary = logger.log_diagnostic(diag_input)
	assert_eq(entry3.get("id"), 3, "Third entry has id 3")
	assert_eq(entry3.get("category"), "NET", "Category is NET")
	assert_eq(entry3.get("level"), "ERROR", "Level is ERROR")
	assert_eq(entry3.get("message"), "Connection closed", "Message mapped from user_message")
	assert_eq(entry3.get("details"), "Socket timeout", "Details mapped")

	assert_eq(logger.get_recent_entries().size(), 3, "Total entries count is 3")

	# 4. Verify clear resets next_id to 1
	logger.clear()
	assert_eq(logger.get_recent_entries().size(), 0, "clear() emptied in-memory buffer")
	var entry_after_clear = logger.log_system("INFO", "Fresh Start", "Post-clear entry")
	assert_eq(entry_after_clear.get("id"), 1, "Entry after clear() has id 1")

	logger.free()

func _test_static_logging_methods() -> void:
	print("\n--- Testing DiagnosticLogger Static Logging Methods ---")
	var logger = DiagnosticLogger.new()
	logger.clear()

	# Static logging calls (used by SpaceViewport and UI)
	var s_info := DiagnosticLogger.log_info("Static info message", "AgentBrain")
	assert_eq(s_info.get("level"), "INFO", "Static log_info produces level INFO")
	assert_eq(s_info.get("category"), "AGENT", "Category inferred as AGENT from AgentBrain")
	assert_eq(s_info.get("message"), "Static info message", "Static info message matches")

	var s_err := DiagnosticLogger.log_error("Static error message", "API")
	assert_eq(s_err.get("level"), "ERROR", "Static log_error produces level ERROR")
	assert_eq(s_err.get("category"), "NET", "Category inferred as NET from API")

	var s_warn := DiagnosticLogger.log_warn("Static warning message", "SECURITY")
	assert_eq(s_warn.get("level"), "WARN", "Static log_warn produces level WARN")
	assert_eq(s_warn.get("category"), "SECURITY", "Category is SECURITY")

	var s_succ := DiagnosticLogger.log_success("Static success message", "ModuleManager")
	assert_eq(s_succ.get("level"), "SUCCESS", "Static log_success produces level SUCCESS")

	# get_formatted_logs_text static helper
	var formatted := DiagnosticLogger.get_formatted_logs_text()
	assert_true("Static info message" in formatted, "Formatted logs text contains static info")
	assert_true("Static error message" in formatted, "Formatted logs text contains static error")

	logger.free()

func _test_ring_buffer_overflow() -> void:
	print("\n--- Testing Ring Buffer Overflow (200 records limit) ---")
	var logger = DiagnosticLogger.new()
	logger.clear()

	# Add 250 records to trigger overflow beyond MAX_ENTRIES (200)
	for i in range(1, 251):
		logger.log_system("INFO", "Ping %d" % i, "Message %d" % i)

	var all_entries = logger.get_recent_entries(300)
	assert_eq(all_entries.size(), 200, "Buffer contains exactly 200 records after adding 250")

	# The first entry remaining in buffer should be #51, last should be #250
	var first_entry: Dictionary = all_entries[0]
	var last_entry: Dictionary = all_entries[all_entries.size() - 1]
	assert_eq(first_entry.get("id"), 51, "Oldest remaining entry has id 51 (1..50 dropped)")
	assert_eq(last_entry.get("id"), 250, "Newest entry has id 250")
	assert_eq(first_entry.get("title"), "Ping 51", "Oldest title matches Ping 51")
	assert_eq(last_entry.get("title"), "Ping 250", "Newest title matches Ping 250")

	logger.free()

func _test_category_filtering() -> void:
	print("\n--- Testing Category Filtering & Recent Limits ---")
	var logger = DiagnosticLogger.new()
	logger.clear()

	# Log various categories
	logger.log_agent("INFO", "Agent 1", "m1")
	logger.log_agent("INFO", "Agent 2", "m2")
	logger.log_agent("INFO", "Agent 3", "m3")
	logger.log_system("INFO", "Sys 1", "s1")
	logger.log_system("WARN", "Sys 2", "s2")
	logger.log_entry("SECURITY", "ERROR", "Sec 1", "sec1")
	logger.log_entry("SECURITY", "ERROR", "Sec 2", "sec2")
	logger.log_entry("COMPILE", "ERROR", "Comp 1", "c1")
	logger.log_entry("NET", "ERROR", "Net 1", "n1")

	var agent_entries = logger.get_recent_entries(10, "AGENT")
	assert_eq(agent_entries.size(), 3, "Filtered 3 AGENT entries")
	for e in agent_entries:
		assert_eq(e.get("category"), "AGENT", "Entry category is AGENT")

	var sys_entries = logger.get_recent_entries(10, "SYSTEM")
	assert_eq(sys_entries.size(), 2, "Filtered 2 SYSTEM entries")

	var sec_entries = logger.get_recent_entries(10, "SECURITY")
	assert_eq(sec_entries.size(), 2, "Filtered 2 SECURITY entries")

	var comp_entries = logger.get_recent_entries(10, "COMPILE")
	assert_eq(comp_entries.size(), 1, "Filtered 1 COMPILE entry")

	var net_entries = logger.get_recent_entries(10, "NET")
	assert_eq(net_entries.size(), 1, "Filtered 1 NET entry")

	# Limit test: requested 2 out of 3 AGENT entries
	var limited_agent = logger.get_recent_entries(2, "AGENT")
	assert_eq(limited_agent.size(), 2, "Limited to 2 AGENT entries")
	assert_eq(limited_agent[0].get("title"), "Agent 2", "Chronological slice has Agent 2")
	assert_eq(limited_agent[1].get("title"), "Agent 3", "Chronological slice has Agent 3")

	logger.free()

func _test_entry_lookup_and_clipboard() -> void:
	print("\n--- Testing Entry Lookup & Clipboard Export ---")
	var logger = DiagnosticLogger.new()
	logger.clear()

	var e1: Dictionary = logger.log_agent("INFO", "Target Title", "Target Message", "Some details")
	var target_id: int = e1.get("id")

	var found: Dictionary = logger.get_entry_by_id(target_id)
	assert_eq(found.get("title"), "Target Title", "Found entry by id")

	var not_found: Dictionary = logger.get_entry_by_id(99999)
	assert_true(not_found.is_empty(), "Non-existent id returns empty dictionary")

	# Clipboard copy by dictionary
	var copied_text_dict: String = logger.copy_entry_to_clipboard(e1)
	assert_true("Target Title" in copied_text_dict, "Clipboard text contains title")
	assert_true("Target Message" in copied_text_dict, "Clipboard text contains message")
	assert_true("Some details" in copied_text_dict, "Clipboard text contains details")

	# Clipboard copy by id
	var copied_text_id: String = logger.copy_entry_to_clipboard(target_id)
	assert_eq(copied_text_id, copied_text_dict, "Clipboard text by id matches text by dict")

	# Clipboard copy by string id
	var copied_text_str_id: String = logger.copy_entry_to_clipboard(str(target_id))
	assert_eq(copied_text_str_id, copied_text_dict, "Clipboard text by string id matches text by dict")

	# Clipboard copy non-existent id
	var invalid_copied: String = logger.copy_entry_to_clipboard(88888)
	assert_eq(invalid_copied, "", "Invalid id returns empty string for clipboard")

	logger.free()

func _test_disk_persistence_and_export() -> void:
	print("\n--- Testing Disk Persistence (user://logs/session.log) ---")
	var logger = DiagnosticLogger.new()

	# Create a unique marker for disk verification
	var unique_marker := "SESSION_LOG_TEST_MARKER_%d" % Time.get_unix_time_from_system()
	logger.log_system("INFO", "Disk Test", unique_marker, "Details for disk")

	# Verify file exists on disk
	var log_path: String = "user://logs/session.log"
	assert_true(FileAccess.file_exists(log_path), "user://logs/session.log exists on disk")

	# Read directly from disk
	var file := FileAccess.open(log_path, FileAccess.READ)
	assert_true(file != null, "Opened user://logs/session.log for reading")
	if file:
		var disk_text := file.get_as_text()
		file.close()
		assert_true(unique_marker in disk_text, "Unique marker found in session.log on disk")
		assert_true("Disk Test" in disk_text, "Title found in session.log on disk")

	# Verify export_session_log
	var exported: String = logger.export_session_log()
	assert_true(unique_marker in exported, "export_session_log contains unique marker")

	var exported_from_disk: String = logger.export_session_log(true)
	assert_true(unique_marker in exported_from_disk, "export_session_log(true) contains unique marker")

	# Verify clear()
	logger.clear()
	assert_eq(logger.get_recent_entries().size(), 0, "clear() emptied in-memory buffer")

	logger.free()

func _test_agent_diagnostic_parsing() -> void:
	print("\n--- Testing AgentDiagnostic Parsing ---")

	# 1. API Region Error (English)
	var err_region := "403 Forbidden: User location is not supported for the API use."
	var diag_reg: Dictionary = AgentDiagnostic.from_error(err_region)
	assert_eq(diag_reg.get("category"), "NET", "Region error category is NET")
	assert_eq(diag_reg.get("level"), "ERROR", "Region error level is ERROR")
	assert_eq(diag_reg.get("title"), "Ошибка региона API", "Region error title matches")
	assert_true("OpenRouter" in diag_reg.get("user_message"), "User message recommends OpenRouter")
	assert_eq(diag_reg.get("suggested_action"), "open_settings_api", "Suggested action is open_settings_api")

	# 2. API Region Error (Russian)
	var err_region_ru := "Сбой API: сервис недоступен из вашего региона."
	var diag_reg_ru: Dictionary = AgentDiagnostic.from_error(err_region_ru)
	assert_eq(diag_reg_ru.get("category"), "NET", "Russian region error category is NET")
	assert_eq(diag_reg_ru.get("title"), "Ошибка региона API", "Russian region error title matches")

	# 3. AST Security Violation (OS.execute)
	var err_sec1 := "Security violation: forbidden call to OS.execute detected"
	var diag_sec1: Dictionary = AgentDiagnostic.from_error(err_sec1)
	assert_eq(diag_sec1.get("category"), "SECURITY", "OS.execute error category is SECURITY")
	assert_eq(diag_sec1.get("title"), "Заблокировано политикой безопасности", "Security error title matches")
	assert_true("FileAccess/OS" in diag_sec1.get("user_message"), "User message mentions FileAccess/OS")

	# 4. AST Security Violation via DirAccess / Sandbox
	var err_sec2 := "Security/Syntax validation failed: Security violation: forbidden call to DirAccess.remove_absolute detected"
	var diag_sec2: Dictionary = AgentDiagnostic.from_error(err_sec2)
	assert_eq(diag_sec2.get("category"), "SECURITY", "DirAccess violation prioritized as SECURITY")

	# 5. Russian Security Violations (Nominative & Genitive)
	var err_sec_ru1 := "Политика безопасности: недопустимый вызов FileAccess"
	var diag_sec_ru1: Dictionary = AgentDiagnostic.from_error(err_sec_ru1)
	assert_eq(diag_sec_ru1.get("category"), "SECURITY", "Russian security error with nominative case is SECURITY")

	var err_sec_ru2 := "Нарушение политики безопасности: обнаружен вызов OS.kill"
	var diag_sec_ru2: Dictionary = AgentDiagnostic.from_error(err_sec_ru2)
	assert_eq(diag_sec_ru2.get("category"), "SECURITY", "Russian security error with genitive case is SECURITY")

	var err_sec_ru3 := "AST нарушение безопасности: попытка доступа за пределы песочницы"
	var diag_sec_ru3: Dictionary = AgentDiagnostic.from_error(err_sec_ru3)
	assert_eq(diag_sec_ru3.get("category"), "SECURITY", "Russian AST security error is SECURITY")

	# 6. GDScript Syntax / Compilation error with line number
	var err_comp1 := "GDScript syntax error at line 42: Unexpected identifier 'foo'"
	var diag_comp1: Dictionary = AgentDiagnostic.from_error(err_comp1)
	assert_eq(diag_comp1.get("category"), "COMPILE", "Compilation error category is COMPILE")
	assert_eq(diag_comp1.get("title"), "Ошибка синтаксиса GDScript", "Syntax error title matches")
	assert_eq(diag_comp1.get("line_number"), 42, "Extracted line number 42")
	assert_eq(diag_comp1.get("user_message"), "Сгенерированный код не прошел компиляцию", "User message matches")

	# 7. GDScript Parse Error with file:line pattern
	var err_comp2 := "Parse Error: Expected ':' at res://modules/cube_tool.gd:15"
	var diag_comp2: Dictionary = AgentDiagnostic.from_error(err_comp2)
	assert_eq(diag_comp2.get("category"), "COMPILE", "Parse Error category is COMPILE")
	assert_eq(diag_comp2.get("line_number"), 15, "Extracted line number 15")

	# 8. Complex path with numbers and line extraction (mod_12/item_34.gd:56)
	var err_comp_complex := "Parse Error at res://modules/mod_12/item_34.gd:56:10: Unexpected token"
	var diag_comp_complex: Dictionary = AgentDiagnostic.from_error(err_comp_complex)
	assert_eq(diag_comp_complex.get("category"), "COMPILE", "Complex path error categorized as COMPILE")
	assert_eq(diag_comp_complex.get("line_number"), 56, "Extracted line number 56 correctly despite path numbers")

	# 9. Parentheses line format (.gd(88))
	var err_comp_paren := "SCRIPT ERROR: reload failed for res://modules/test.gd(88): Parse Error"
	var diag_comp_paren: Dictionary = AgentDiagnostic.from_error(err_comp_paren)
	assert_eq(diag_comp_paren.get("line_number"), 88, "Extracted line number 88 from .gd(88)")

	# 10. Russian Compilation Error with line number
	var err_comp_ru := "Ошибка компиляции на строке 77: пропущено двоеточие"
	var diag_comp_ru: Dictionary = AgentDiagnostic.from_error(err_comp_ru)
	assert_eq(diag_comp_ru.get("category"), "COMPILE", "Russian compilation error is COMPILE")
	assert_eq(diag_comp_ru.get("line_number"), 77, "Extracted line number 77 from Russian text")

	# 11. Russian Syntax Error without line
	var err_comp_ru2 := "Ошибка синтаксиса GDScript: несоответствие отступов"
	var diag_comp_ru2: Dictionary = AgentDiagnostic.from_error(err_comp_ru2)
	assert_eq(diag_comp_ru2.get("category"), "COMPILE", "Russian syntax error is COMPILE")
	assert_eq(diag_comp_ru2.get("line_number"), -1, "Line number is -1 when omitted in Russian")

	# 12. GDScript Syntax error wrapped in validator prefix
	var err_comp3 := "Security/Syntax validation failed: GDScript syntax/compilation error (code 1)"
	var diag_comp3: Dictionary = AgentDiagnostic.from_error(err_comp3)
	assert_eq(diag_comp3.get("category"), "COMPILE", "Validator syntax error classified as COMPILE, not SECURITY")
	assert_eq(diag_comp3.get("line_number"), -1, "Line number is -1 when not specified")

	# 13. Success event
	var diag_suc: Dictionary = AgentDiagnostic.from_success("super_cube_tool")
	assert_eq(diag_suc.get("category"), "AGENT", "Success category is AGENT")
	assert_eq(diag_suc.get("level"), "SUCCESS", "Success level is SUCCESS")
	assert_eq(diag_suc.get("title"), "Модуль смонтирован", "Success title matches")
	assert_true("super_cube_tool" in diag_suc.get("user_message"), "Success message contains module ID")

	# 14. Request started event
	var diag_req: Dictionary = AgentDiagnostic.from_request("Сгенерируй синий шар")
	assert_eq(diag_req.get("category"), "AGENT", "Request category is AGENT")
	assert_eq(diag_req.get("level"), "INFO", "Request level is INFO")
	assert_true("Сгенерируй синий шар" in diag_req.get("user_message"), "Request message contains prompt")

func _test_agent_brain_integration() -> void:
	print("\n--- Testing AgentBrain Integration with DiagnosticLogger ---")

	var event_bus := EventBus.new()
	var world_root := Node3D.new()
	var module_manager := ModuleManager.new()
	module_manager.setup(event_bus, world_root)

	var mock_provider := MockLLMProvider.new()
	var logger = DiagnosticLogger.new()
	logger.clear()

	var agent_brain := AgentBrain.new()
	agent_brain.api_key = "dummy_test_key"
	agent_brain.setup(event_bus, module_manager, mock_provider, logger)

	# Test calling setup() again to confirm idempotency (no double-connection errors)
	agent_brain.setup(event_bus, module_manager, mock_provider, logger)
	assert_true(true, "AgentBrain.setup() can be called repeatedly without signal connection errors")

	var emitted_diagnostics: Array[Dictionary] = []
	agent_brain.diagnostic_emitted.connect(func(diag: Dictionary):
		emitted_diagnostics.append(diag)
	)

	var failed_errors: Array[String] = []
	agent_brain.request_failed.connect(func(err: String):
		failed_errors.append(err)
	)

	var completed_modules: Array[String] = []
	agent_brain.request_completed.connect(func(mod_id: String):
		completed_modules.append(mod_id)
	)

	# 1. Test Prompt submission: triggers diagnostic_emitted (INFO) and logs to logger
	agent_brain.process_user_prompt("Создай уникальный модуль для теста 98765")
	assert_true(emitted_diagnostics.size() >= 1, "diagnostic_emitted fired on prompt start")
	var start_diag: Dictionary = emitted_diagnostics[0]
	assert_eq(start_diag.get("category"), "AGENT", "Start diagnostic category is AGENT")
	assert_eq(start_diag.get("level"), "INFO", "Start diagnostic level is INFO")
	assert_true(logger.get_recent_entries(1, "AGENT").size() > 0, "DiagnosticLogger received AGENT record")

	# 2. Test Error emission & backward compatibility (LLM Region Error)
	mock_provider.request_failed.emit("User location is not supported for the API use.")
	assert_eq(failed_errors.size(), 1, "request_failed signal fired for backward compatibility")
	assert_true(emitted_diagnostics.size() >= 2, "diagnostic_emitted fired for error")
	var err_diag: Dictionary = emitted_diagnostics[emitted_diagnostics.size() - 1]
	assert_eq(err_diag.get("category"), "NET", "AgentBrain correctly classified error as NET")
	assert_eq(err_diag.get("title"), "Ошибка региона API", "AgentBrain title is API region error")
	assert_eq(err_diag.get("suggested_action"), "open_settings_api", "Suggested action forwarded")

	# 3. Test Security Validation Error via LLM response
	mock_provider.ignore_send = true
	var dangerous_code := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	OS.execute("cmd.exe", [])
	return true
"""
	agent_brain._on_llm_response(dangerous_code)
	assert_eq(failed_errors.size(), 2, "request_failed fired for security violation")
	var sec_diag: Dictionary = emitted_diagnostics[emitted_diagnostics.size() - 1]
	assert_eq(sec_diag.get("category"), "SECURITY", "Security violation categorized as SECURITY")
	assert_eq(sec_diag.get("title"), "Заблокировано политикой безопасности", "Security violation title correct")

	# 4. Test Syntax Validation Error via LLM response
	var broken_code := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	var x = (((broken_syntax
	return true
"""
	agent_brain._on_llm_response(broken_code)
	assert_eq(failed_errors.size(), 3, "request_failed fired for syntax error")
	var comp_diag: Dictionary = emitted_diagnostics[emitted_diagnostics.size() - 1]
	assert_eq(comp_diag.get("category"), "COMPILE", "Syntax error categorized as COMPILE")
	assert_eq(comp_diag.get("title"), "Ошибка синтаксиса GDScript", "Compile error title correct")

	# 5. Test Successful Module Injection
	var valid_code := """extends UniCoreModule

func get_module_id() -> String:
	return "test_success_diagnostic_mod"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	return true

func cleanup() -> void:
	super.cleanup()
"""
	agent_brain._on_llm_response(valid_code)
	assert_eq(completed_modules.size(), 1, "request_completed fired for successful module")
	assert_eq(completed_modules[0], "test_success_diagnostic_mod", "Completed module ID matches")
	var suc_diag: Dictionary = emitted_diagnostics[emitted_diagnostics.size() - 1]
	assert_eq(suc_diag.get("category"), "AGENT", "Success diagnostic category is AGENT")
	assert_eq(suc_diag.get("level"), "SUCCESS", "Success diagnostic level is SUCCESS")
	assert_eq(suc_diag.get("title"), "Модуль смонтирован", "Success diagnostic title correct")

	# Cleanup test nodes and disk artifacts
	agent_brain.free()
	logger.free()
	mock_provider.free()
	module_manager.unload_module("test_success_diagnostic_mod")
	module_manager.free()
	world_root.free()
	event_bus.free()

	# Remove any disk artifact saved by _save_module_to_disk
	var test_mod_path := "res://modules/test_success_diagnostic_mod.gd"
	if FileAccess.file_exists(test_mod_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_mod_path))
