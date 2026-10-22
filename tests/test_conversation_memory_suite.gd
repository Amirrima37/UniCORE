extends SceneTree

# ==============================================================================
# UniCORE Test Suite: Conversation Memory & Context Window
# Tests message additions, roles, schemas, sliding window context,
# summarization of early history, boundary conditions, disk persistence,
# clear(), and active modules context generation.
# ==============================================================================

var passed_count: int = 0
var failed_count: int = 0

func assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		passed_count += 1
	else:
		print("  [FAIL] %s %s" % [test_name, ("- " + error_msg) if not error_msg.is_empty() else ""])
		failed_count += 1

func assert_false(condition: bool, test_name: String, error_msg: String = "") -> void:
	assert_true(not condition, test_name, error_msg)

func assert_eq(val, expected, test_name: String) -> void:
	var matches: bool = (val == expected)
	assert_true(matches, test_name, "Expected '%s', got '%s'" % [str(expected), str(val)])

class MockModule extends Node:
	var mod_id: String = ""
	var mod_name: String = ""

	func _init(p_id: String, p_name: String) -> void:
		mod_id = p_id
		mod_name = p_name

	func get_module_id() -> String:
		return mod_id

	func get_module_name() -> String:
		return mod_name

class MockModuleManager extends RefCounted:
	var modules: Dictionary = {}

	func add_test_module(id: String, name: String) -> MockModule:
		var m = MockModule.new(id, name)
		modules[id] = m
		return m

	func get_active_module_ids() -> Array:
		return modules.keys()

	func get_module(id: String) -> Node:
		return modules.get(id, null)

	func cleanup() -> void:
		for id in modules:
			var m = modules[id]
			if is_instance_valid(m):
				m.free()
		modules.clear()

func _init() -> void:
	print("==================================================")
	print("Starting UniCORE Conversation Memory & Context Window Test Suite")
	print("==================================================")

	var memory_script = load("res://agent/conversation_memory.gd")
	assert_true(memory_script != null, "ConversationMemory script loaded successfully")
	if not memory_script:
		print("FATAL: Cannot load conversation_memory.gd")
		quit(1)
		return

	# --------------------------------------------------------------------------
	# Group 1: Initialization & Baseline Schema
	# --------------------------------------------------------------------------
	print("\n--- Group 1: Initialization & Baseline Schema ---")
	var mem = memory_script.new()
	assert_eq(mem.max_messages, 20, "Default max_messages is 20")
	assert_eq(mem.messages.size(), 0, "Initial messages array is empty")
	assert_true(mem.is_empty(), "is_empty() returns true on empty memory")
	assert_eq(mem.get_message_count(), 0, "get_message_count() returns 0")
	assert_eq(mem.get_context_messages().size(), 0, "get_context_messages() returns empty array when no messages")

	var mem_custom = memory_script.new(15)
	assert_eq(mem_custom.max_messages, 15, "Custom constructor sets max_messages to 15")

	var mem_negative = memory_script.new(-5)
	assert_true(mem_negative.max_messages >= 1, "Negative max_messages clamped to at least 1")

	# --------------------------------------------------------------------------
	# Group 2: Adding Messages & Field Validation (User, Assistant, Error)
	# --------------------------------------------------------------------------
	print("\n--- Group 2: Adding Messages & Field Validation ---")
	# 1-argument call test
	var msg_1arg: Dictionary = mem.add_user_message("Запрос с одним аргументом")
	assert_eq(msg_1arg.get("role"), "user", "1-arg add_user_message sets role 'user'")
	assert_eq(msg_1arg.get("content"), "Запрос с одним аргументом", "1-arg add_user_message sets content")
	assert_true(msg_1arg.get("metadata") is Dictionary, "1-arg add_user_message sets metadata dict")

	var user_msg: Dictionary = mem.add_user_message("Создай генератор красных кубов", {"source": "ui_prompt"})
	assert_eq(user_msg.get("role"), "user", "User message role is 'user'")
	assert_eq(user_msg.get("content"), "Создай генератор красных кубов", "User message content matches")
	assert_true(user_msg.get("timestamp") is float and user_msg.get("timestamp") > 0.0, "Timestamp is positive float")
	assert_true(user_msg.get("metadata") is Dictionary, "Metadata is a Dictionary")
	assert_eq(user_msg.get("metadata").get("source"), "ui_prompt", "Metadata preserved")
	assert_eq(mem.get_last_user_message(), "Создай генератор красных кубов", "get_last_user_message returns prompt")

	# 2-argument call test
	var assistant_code := "extends UniCoreModule\nfunc get_module_id() -> String: return 'red_cube_gen'"
	var assistant_msg: Dictionary = mem.add_assistant_response(assistant_code, "red_cube_gen")
	assert_eq(assistant_msg.get("role"), "assistant", "Assistant message role is 'assistant'")
	assert_eq(assistant_msg.get("content"), assistant_code, "Assistant message content matches code")
	assert_true(assistant_msg.get("timestamp") is float and assistant_msg.get("timestamp") > 0.0, "Timestamp is float")
	assert_true(assistant_msg.get("metadata") is Dictionary, "Metadata is a Dictionary")
	assert_eq(assistant_msg.get("metadata").get("module_id"), "red_cube_gen", "Assistant metadata contains module_id")

	# 2-argument error context call test (default role 'user' for LLM self-repair)
	var err_str := "Parse Error at line 12: unexpected identifier"
	var broken_code := "func foo() var x = 5"
	var error_msg: Dictionary = mem.add_error_context(err_str, broken_code)
	assert_eq(error_msg.get("role"), "user", "Error context defaults to 'user' for multi-turn LLM repair")
	assert_true(error_msg.get("content").contains(err_str), "Error message content contains error string")
	assert_true(error_msg.get("content").contains(broken_code), "Error message content contains broken code")
	assert_true(error_msg.get("timestamp") is float and error_msg.get("timestamp") > 0.0, "Timestamp is float")
	assert_true(error_msg.get("metadata") is Dictionary, "Metadata is Dictionary")
	assert_eq(error_msg.get("metadata").get("error"), err_str, "Metadata has error")
	assert_eq(error_msg.get("metadata").get("failed_code"), broken_code, "Metadata has failed_code")
	assert_eq(error_msg.get("metadata").get("is_error"), true, "Metadata has is_error flag")

	# Test custom role override for error context (e.g. system)
	var sys_error_msg = mem.add_error_context("Timeout", "pass", "system")
	assert_eq(sys_error_msg.get("role"), "system", "Error context supports explicit 'system' role override")

	# Test invalid role fallback to 'user'
	var fallback_error = mem.add_error_context("CustomErr", "pass", "nonexistent_role")
	assert_eq(fallback_error.get("role"), "user", "Invalid role falls back to 'user'")

	# --------------------------------------------------------------------------
	# Group 3: Sliding Context Window (get_context_messages)
	# --------------------------------------------------------------------------
	print("\n--- Group 3: Sliding Context Window ---")
	var mem_window = memory_script.new(5)
	assert_eq(mem_window.max_messages, 5, "Window max_messages set to 5")

	for i in range(3):
		mem_window.add_user_message("Query %d" % i)
	var win_msgs_3 = mem_window.get_context_messages()
	assert_eq(win_msgs_3.size(), 3, "Context returns 3 messages when count < max_messages")
	assert_eq(win_msgs_3[0].get("content"), "Query 0", "First message matches")

	# Deep duplicate immutability check
	win_msgs_3[0]["content"] = "HACKED_CONTENT"
	assert_eq(mem_window.messages[0].get("content"), "Query 0", "Internal memory immune to external mutation")

	# Add messages up to 8 (> max_messages = 5)
	for i in range(3, 8):
		mem_window.add_user_message("Query %d" % i)
	assert_eq(mem_window.messages.size(), 8, "Raw messages count is 8")

	var win_msgs_5 = mem_window.get_context_messages()
	assert_eq(win_msgs_5.size(), 5, "Context window clamps to max_messages (5)")
	assert_eq(win_msgs_5[0].get("content"), "Query 3", "Sliding window begins at Query 3 (oldest 0..2 dropped)")
	assert_eq(win_msgs_5[4].get("content"), "Query 7", "Sliding window ends at Query 7 (latest)")

	# Edge case: max_messages <= 0
	var mem_zero = memory_script.new(0)
	mem_zero.max_messages = 0
	mem_zero.messages.append({"role": "system", "content": "Sys", "timestamp": 1.0, "metadata": {}})
	assert_eq(mem_zero.get_context_messages().size(), 0, "get_context_messages returns empty array when max_messages is 0")

	# Edge case: max_messages = 1
	var mem_one = memory_script.new(1)
	mem_one.add_user_message("Old")
	mem_one.add_user_message("Newest")
	var one_msgs = mem_one.get_context_messages()
	assert_eq(one_msgs.size(), 1, "get_context_messages returns exactly 1 message when max_messages is 1")
	assert_eq(one_msgs[0].get("content"), "Newest", "Returned single message is the newest one")

	# --------------------------------------------------------------------------
	# Group 4: Early Context Summarization (summarize_if_needed)
	# --------------------------------------------------------------------------
	print("\n--- Group 4: Early Context Summarization ---")
	var mem_sum = memory_script.new(20)
	assert_eq(mem_sum.max_messages, 20, "max_messages is 20")

	# Populate with 15 messages (<= max_messages)
	for i in range(14):
		mem_sum.add_user_message("Task #%d" % i)
	# Add an error context in early messages to verify self-repair summarization
	mem_sum.add_error_context("Compiler failure at line 42", "func broken(): return")
	assert_eq(mem_sum.messages.size(), 15, "15 messages added (including 1 error context)")

	# Call summarize_if_needed(): should do nothing because 15 <= 20
	mem_sum.summarize_if_needed()
	assert_eq(mem_sum.messages.size(), 15, "summarize_if_needed does nothing when count <= max_messages")

	# Add 10 more messages -> total 25 messages (> 20)
	for i in range(15, 25):
		if i % 2 == 0:
			mem_sum.add_user_message("User prompt #%d" % i)
		else:
			mem_sum.add_assistant_response("code_%d" % i, "mod_%d" % i)
	assert_eq(mem_sum.messages.size(), 25, "Messages count reached 25")

	# Record expected last 10 messages before summarization
	var expected_recent: Array[Dictionary] = []
	for i in range(15, 25):
		expected_recent.append(mem_sum.messages[i].duplicate(true))

	# Trigger summarize_if_needed()
	mem_sum.summarize_if_needed()
	# Early messages: 25 - 10 = 15 messages compressed into 1 system message.
	# Retained: last 10 messages.
	# Total new size: 1 + 10 = 11.
	assert_eq(mem_sum.messages.size(), 11, "After summarize_if_needed, size is 1 summary + 10 recent = 11")
	var sum_msg: Dictionary = mem_sum.messages[0]
	assert_eq(sum_msg.get("role"), "system", "Summary message has role 'system'")
	assert_true(sum_msg.get("content").begins_with("Сводка раннего контекста диалога:"), "Summary content begins with Russian prefix")
	assert_true(sum_msg.get("timestamp") is float and sum_msg.get("timestamp") > 0.0, "Summary has valid timestamp")
	assert_true(sum_msg.get("metadata") is Dictionary, "Summary has metadata Dictionary")
	assert_eq(sum_msg.get("metadata").get("is_summary"), true, "Summary metadata has is_summary=true")
	assert_eq(sum_msg.get("metadata").get("compressed_count"), 15, "Compressed count is 15")

	# Verify error context in early history was categorized as - Ошибка/Самовосстановление, NOT - Запрос пользователя
	assert_true(sum_msg.get("content").contains("- Ошибка/Самовосстановление: Compiler failure at line 42"), "Summary correctly categorizes error context")
	assert_false(sum_msg.get("content").contains("- Запрос пользователя: Error during module validation"), "Summary does not mislabel error context as user request")

	# Verify recent 10 messages were preserved exactly
	for i in range(10):
		var actual_msg: Dictionary = mem_sum.messages[1 + i]
		var exp_msg: Dictionary = expected_recent[i]
		assert_eq(actual_msg.get("role"), exp_msg.get("role"), "Preserved message %d role matches" % i)
		assert_eq(actual_msg.get("content"), exp_msg.get("content"), "Preserved message %d content matches" % i)

	# Verify get_context_messages() with system summary at index 0
	var context_after_sum = mem_sum.get_context_messages()
	assert_eq(context_after_sum.size(), 11, "get_context_messages returns all 11 messages")
	assert_eq(context_after_sum[0].get("role"), "system", "Context message 0 is the system summary")

	# Test compounding summarization: add 15 more messages (11 + 15 = 26 > 20)
	for i in range(15):
		mem_sum.add_user_message("Extra step %d" % i)
	assert_eq(mem_sum.messages.size(), 26, "Messages count reached 26")
	mem_sum.summarize_if_needed()
	assert_eq(mem_sum.messages.size(), 11, "Compound summarization again produces 11 messages")
	assert_eq(mem_sum.messages[0].get("role"), "system", "First message is still system summary")

	# Boundary test: max_messages = 10 (Critical edge case!)
	var mem_10 = memory_script.new(10)
	for i in range(16):
		mem_10.add_user_message("Step10 #%d" % i)
	assert_eq(mem_10.messages.size(), 16, "Added 16 messages to memory with max_messages=10")
	mem_10.summarize_if_needed()
	assert_true(mem_10.messages.size() <= 10, "max_messages=10 boundary: size after summarize_if_needed is <= 10 (actual: %d)" % mem_10.messages.size())
	assert_eq(mem_10.messages[0].get("role"), "system", "First message is summary")

	# Boundary test: max_messages = 2
	var mem_2 = memory_script.new(2)
	for i in range(6):
		mem_2.add_user_message("Step2 #%d" % i)
	mem_2.summarize_if_needed()
	assert_true(mem_2.messages.size() <= 2, "max_messages=2 boundary: size after summarize_if_needed is <= 2 (actual: %d)" % mem_2.messages.size())

	# Test auto_summarize = true
	var mem_auto = memory_script.new(5)
	mem_auto.auto_summarize = true
	for i in range(12):
		mem_auto.add_user_message("AutoMsg %d" % i)
	assert_true(mem_auto.messages.size() <= 5, "auto_summarize=true automatically keeps size <= max_messages (size: %d)" % mem_auto.messages.size())

	# --------------------------------------------------------------------------
	# Group 5: Serialization & Persistence (save_to_disk, load_from_disk)
	# --------------------------------------------------------------------------
	print("\n--- Group 5: Serialization & Persistence ---")
	var test_path := "user://conversation_history.json"
	var mem_disk = memory_script.new(20)
	mem_disk.add_user_message("User query 1")
	mem_disk.add_assistant_response("var code = 1", "test_mod_1")
	mem_disk.add_error_context("Validation err", "broken_code_test")

	# Save to disk
	var save_ok = mem_disk.save_to_disk(test_path)
	assert_true(save_ok, "save_to_disk returned true")
	assert_true(FileAccess.file_exists(test_path), "File exists on disk at %s" % test_path)

	# Validate raw JSON on disk
	var file := FileAccess.open(test_path, FileAccess.READ)
	assert_true(file != null, "Opened %s for read verification" % test_path)
	var raw_text := file.get_as_text()
	file.close()

	var parsed_raw = JSON.parse_string(raw_text)
	assert_true(parsed_raw is Dictionary, "Disk file is valid JSON Dictionary")
	assert_true(parsed_raw.has("messages"), "JSON has 'messages' key")
	assert_eq(parsed_raw.get("max_messages"), 20, "JSON has 'max_messages' = 20")
	assert_eq(parsed_raw.get("messages").size(), 3, "JSON contains 3 messages")

	# Load into fresh memory instance
	var mem_loaded = memory_script.new()
	var load_ok = mem_loaded.load_from_disk(test_path)
	assert_true(load_ok, "load_from_disk returned true")
	assert_eq(mem_loaded.messages.size(), 3, "Loaded 3 messages")
	assert_eq(mem_loaded.messages[0].get("role"), "user", "Loaded msg 0 role is 'user'")
	assert_eq(mem_loaded.messages[0].get("content"), "User query 1", "Loaded msg 0 content matches")
	assert_eq(mem_loaded.messages[1].get("role"), "assistant", "Loaded msg 1 role is 'assistant'")
	assert_eq(mem_loaded.messages[1].get("metadata").get("module_id"), "test_mod_1", "Loaded msg 1 module_id matches")
	assert_eq(mem_loaded.messages[2].get("metadata").get("error"), "Validation err", "Loaded msg 2 error matches")
	assert_eq(mem_loaded.messages[2].get("metadata").get("failed_code"), "broken_code_test", "Loaded msg 2 failed_code matches")

	# Persistence into deeply nested non-existent directory
	var nested_path := "user://test_mem_sub/nested/deep_history.json"
	var nested_save = mem_disk.save_to_disk(nested_path)
	assert_true(nested_save, "save_to_disk creates parent directories recursively")
	assert_true(FileAccess.file_exists(nested_path), "Nested file created on disk")
	var mem_nested_load = memory_script.new()
	assert_true(mem_nested_load.load_from_disk(nested_path), "load_from_disk loaded nested file")
	assert_eq(mem_nested_load.messages.size(), 3, "Loaded nested messages count matches")
	DirAccess.remove_absolute(nested_path)

	# Edge cases in loading: non-existent file
	var bad_load = mem_loaded.load_from_disk("user://non_existent_memory_file.json")
	assert_false(bad_load, "load_from_disk returns false for non-existent file")

	# Edge case: empty file
	var empty_path := "user://empty_history_test.json"
	var empty_file := FileAccess.open(empty_path, FileAccess.WRITE)
	empty_file.store_string("   ")
	empty_file.close()
	assert_false(mem_loaded.load_from_disk(empty_path), "load_from_disk returns false on empty/whitespace file")
	DirAccess.remove_absolute(empty_path)

	# Edge case: role normalization from foreign/legacy formats
	var norm_path := "user://norm_history_test.json"
	var norm_file := FileAccess.open(norm_path, FileAccess.WRITE)
	var norm_data = [
		{"role": "human", "content": "Human msg"},
		{"role": "bot", "content": "Bot msg"},
		{"role": "ai", "content": "AI msg"},
		{"role": "unrecognized_custom", "content": "Custom msg"}
	]
	norm_file.store_string(JSON.stringify(norm_data))
	norm_file.close()

	var mem_norm = memory_script.new()
	assert_true(mem_norm.load_from_disk(norm_path), "load_from_disk loaded normalization test file")
	assert_eq(mem_norm.messages[0].get("role"), "user", "Role 'human' normalized to 'user'")
	assert_eq(mem_norm.messages[1].get("role"), "assistant", "Role 'bot' normalized to 'assistant'")
	assert_eq(mem_norm.messages[2].get("role"), "assistant", "Role 'ai' normalized to 'assistant'")
	assert_eq(mem_norm.messages[3].get("role"), "user", "Unrecognized role normalized to 'user'")
	DirAccess.remove_absolute(norm_path)

	# Edge case: legacy raw Array JSON format
	var legacy_path := "user://legacy_history_test.json"
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	var legacy_data = [
		{"role": "user", "content": "Legacy query", "timestamp": 12345.0},
		{"role": "assistant", "content": "Legacy code", "module_id": "leg_mod", "timestamp": 12346.0}
	]
	legacy_file.store_string(JSON.stringify(legacy_data))
	legacy_file.close()

	var mem_legacy = memory_script.new()
	var leg_ok = mem_legacy.load_from_disk(legacy_path)
	assert_true(leg_ok, "load_from_disk successfully loaded legacy Array JSON format")
	assert_eq(mem_legacy.messages.size(), 2, "Loaded 2 legacy messages")
	assert_eq(mem_legacy.messages[0].get("role"), "user", "Legacy message role normalized")
	assert_eq(mem_legacy.messages[1].get("metadata").get("module_id"), "leg_mod", "Legacy module_id normalized into metadata")
	DirAccess.remove_absolute(legacy_path)

	# --------------------------------------------------------------------------
	# Group 6: History Cleanup (clear)
	# --------------------------------------------------------------------------
	print("\n--- Group 6: History Cleanup (clear) ---")
	assert_true(FileAccess.file_exists(test_path), "File exists before clear()")
	assert_false(mem_disk.messages.is_empty(), "Messages not empty before clear()")

	# Test clear() with explicit path
	mem_disk.clear(test_path)
	assert_true(mem_disk.messages.is_empty(), "Messages array is cleared by clear(path)")
	assert_eq(mem_disk.messages.size(), 0, "Messages size is 0 after clear(path)")
	assert_false(FileAccess.file_exists(test_path), "File %s deleted by clear(path)" % test_path)

	# Test clear() with NO arguments (default DEFAULT_STORAGE_PATH)
	var mem_default_clear = memory_script.new()
	mem_default_clear.add_user_message("Will be cleared")
	mem_default_clear.save_to_disk() # saves to user://conversation_history.json
	assert_true(FileAccess.file_exists("user://conversation_history.json"), "Default file exists before clear()")
	mem_default_clear.clear() # zero arguments
	assert_true(mem_default_clear.messages.is_empty(), "Messages empty after 0-arg clear()")
	assert_false(FileAccess.file_exists("user://conversation_history.json"), "Default file deleted after 0-arg clear()")

	# Calling clear() again should not crash even if file doesn't exist
	mem_disk.clear(test_path)
	assert_true(mem_disk.messages.is_empty(), "Idempotent clear() works cleanly")

	# --------------------------------------------------------------------------
	# Group 7: Active Modules Context (get_active_modules_context)
	# --------------------------------------------------------------------------
	print("\n--- Group 7: Active Modules Context ---")
	var mem_ctx = memory_script.new()

	# Null module manager
	var null_ctx = mem_ctx.get_active_modules_context(null)
	assert_eq(null_ctx, "Currently Active Modules in Scene: None.", "Null manager returns 'None' context")

	# Non-manager dummy object
	var dummy_ctx = mem_ctx.get_active_modules_context(RefCounted.new())
	assert_eq(dummy_ctx, "Currently Active Modules in Scene: None.", "Object without methods returns 'None' context")

	# Empty modules manager
	var mock_mm = MockModuleManager.new()
	var empty_ctx = mem_ctx.get_active_modules_context(mock_mm)
	assert_eq(empty_ctx, "Currently Active Modules in Scene: None.", "Empty manager returns 'None' context")

	# Populated modules manager
	mock_mm.add_test_module("builtin_ground_plane", "Нулевая плоскость мира")
	mock_mm.add_test_module("avatar_locomotion", "Аватар и полет камеры")
	mock_mm.add_test_module("cube_tool", "Генератор кубов")

	var active_ctx = mem_ctx.get_active_modules_context(mock_mm)
	assert_true(active_ctx.begins_with("Currently Active Modules in Scene:"), "Active context has correct header")
	assert_true(active_ctx.contains("- [builtin_ground_plane] Нулевая плоскость мира"), "Context contains ground plane entry")
	assert_true(active_ctx.contains("- [avatar_locomotion] Аватар и полет камеры"), "Context contains avatar locomotion entry")
	assert_true(active_ctx.contains("- [cube_tool] Генератор кубов"), "Context contains cube tool entry")

	# Dictionary input support
	var dict_input = {
		"mod_custom": MockModule.new("mod_custom", "Кастомный Модуль")
	}
	var dict_ctx = mem_ctx.get_active_modules_context(dict_input)
	assert_true(dict_ctx.contains("- [mod_custom] Кастомный Модуль"), "Dictionary input formatted correctly")
	dict_input["mod_custom"].free()

	# Array input support
	var array_input = ["simple_mod_1", "simple_mod_2"]
	var arr_ctx = mem_ctx.get_active_modules_context(array_input)
	assert_true(arr_ctx.contains("- [simple_mod_1] simple_mod_1"), "Array input formatted correctly")

	mock_mm.cleanup()

	# Real ModuleManager instance test
	var mm_script = load("res://core/module_manager.gd")
	if mm_script:
		var real_mm = mm_script.new()
		var real_ctx = mem_ctx.get_active_modules_context(real_mm)
		assert_eq(real_ctx, "Currently Active Modules in Scene: None.", "Real empty ModuleManager returns 'None' context")
		real_mm.free()

	# --------------------------------------------------------------------------
	# Summary & Exit
	# --------------------------------------------------------------------------
	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print("AUDIT SUCCESS: All ConversationMemory & Context Window tests passed!")
		quit(0)
	else:
		print("AUDIT FAILED: %d tests failed." % failed_count)
		quit(1)
