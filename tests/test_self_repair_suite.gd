extends SceneTree

# ==============================================================================
# UniCORE Test Suite: Self-Repair Loop & Module Edit Mode (Phase 2.5a)
# Tests ConversationMemory, Self-Repair loop on syntax/compile errors,
# MAX_REPAIR_ATTEMPTS threshold, Russian/English Edit Mode regex parsing,
# hot-replacement in ModuleManager, and context-enriched SYSTEM_PROMPT.
# ==============================================================================

const AgentBrainScript = preload("res://agent/agent_brain.gd")
const ConversationMemoryScript = preload("res://agent/conversation_memory.gd")
const EventBusScript = preload("res://core/event_bus.gd")
const ModuleManagerScript = preload("res://core/module_manager.gd")
const DiagnosticLoggerScript = preload("res://core/diagnostic_logger.gd")
const BaseLLMProviderScript = preload("res://agent/providers/base_llm_provider.gd")

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

class MockLLMProvider extends BaseLLMProvider:
	var response_queue: Array[String] = []
	var history: Array[Dictionary] = []
	var call_count: int = 0

	func send_prompt(system_prompt: String, user_prompt: String, api_key: String) -> void:
		call_count += 1
		history.append({
			"system": system_prompt,
			"user": user_prompt,
			"key": api_key
		})

		if not response_queue.is_empty():
			var resp: String = response_queue.pop_front()
			response_received.emit(resp)
		else:
			request_failed.emit("MockLLMProvider: response_queue is empty")

func _init() -> void:
	print("==================================================")
	print("UniCORE: Self-Repair Loop & Edit Mode Test Suite")
	print("==================================================")

	var event_bus: EventBus = EventBusScript.new()
	var world_root: Node3D = Node3D.new()
	var module_manager: ModuleManager = ModuleManagerScript.new()
	module_manager.setup(event_bus, world_root)

	var logger: DiagnosticLogger = DiagnosticLoggerScript.new()
	logger.clear()

	var mock_provider: MockLLMProvider = MockLLMProvider.new()
	var agent_brain: AgentBrain = AgentBrainScript.new()
	agent_brain.api_key = "mock_test_key"
	agent_brain.setup(event_bus, module_manager, mock_provider, logger)

	var completed_modules: Array[String] = []
	var failed_errors: Array[String] = []
	var started_prompts: Array[String] = []

	agent_brain.request_started.connect(func(p: String): started_prompts.append(p))
	agent_brain.request_completed.connect(func(id: String): completed_modules.append(id))
	agent_brain.request_failed.connect(func(err: String): failed_errors.append(err))

	# --------------------------------------------------------------------------
	# Group 0: ConversationMemory Unit Tests
	# --------------------------------------------------------------------------
	print("\n--- Group 0: ConversationMemory Unit Tests ---")
	var mem = ConversationMemoryScript.new()
	mem.clear()
	assert_eq(mem.get_messages().size(), 0, "Memory starts empty after clear")

	mem.add_user_message("Hello Agent")
	mem.add_assistant_response("var code = 1", "test_mod")
	mem.add_error_context("Parse error", "var broken = ((")

	assert_eq(mem.get_messages().size(), 3, "Memory has 3 recorded events")
	assert_eq(mem.get_last_user_message(), "Hello Agent", "get_last_user_message returns correct prompt")

	var save_path := "user://test_memory_save.json"
	var save_ok = mem.save_to_disk(save_path)
	assert_true(save_ok, "Memory saved to disk successfully")

	var mem_loader = ConversationMemoryScript.new()
	var load_ok = mem_loader.load_from_disk(save_path)
	assert_true(load_ok, "Memory loaded from disk successfully")
	assert_eq(mem_loader.get_messages().size(), 3, "Loaded memory retains all 3 messages")

	# Clean up test save file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	# --------------------------------------------------------------------------
	# Group 1: Self-Repair Loop Success on 2nd Attempt
	# --------------------------------------------------------------------------
	print("\n--- Group 1: Self-Repair Loop (Succeeds on Attempt 2) ---")
	completed_modules.clear()
	failed_errors.clear()
	mock_provider.history.clear()
	mock_provider.call_count = 0

	var broken_syntax_code := """extends UniCoreModule
func initialize(context: Dictionary) -> bool:
	var x = (((unclosed_syntax_bracket
	return true
func cleanup() -> void:
	pass
"""

	var valid_repair_code := """extends UniCoreModule

func get_module_id() -> String:
	return "repaired_alpha_tool"

func get_module_name() -> String:
	return "Восстановленный Инструмент Альфа"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	return true

func cleanup() -> void:
	super.cleanup()
"""

	mock_provider.response_queue = [broken_syntax_code, valid_repair_code]
	# Use prompt that does not match any pre-verified static template in ModuleRegistry
	agent_brain.process_user_prompt("Сгенерируй тестовый компонент alpha")

	assert_eq(mock_provider.call_count, 2, "LLM provider called exactly twice (1 initial + 1 repair)")
	assert_eq(completed_modules.size(), 1, "request_completed emitted exactly once")
	assert_eq(completed_modules[0], "repaired_alpha_tool", "Completed module ID is 'repaired_alpha_tool'")
	assert_eq(failed_errors.size(), 0, "request_failed was NOT emitted on successful repair")
	assert_true(module_manager.get_module("repaired_alpha_tool") != null, "Module is loaded in ModuleManager")
	assert_eq(agent_brain.get_repair_attempts(), 0, "Repair attempts reset to 0 after success")

	# Verify repair prompt content
	assert_true(mock_provider.history.size() >= 2, "Two prompts recorded in mock provider history")
	if mock_provider.history.size() >= 2:
		var repair_prompt_sent: String = mock_provider.history[1]["user"]
		assert_true(repair_prompt_sent.contains("Предыдущий сгенерированный код вызвал ошибку"), "Repair prompt mentions previous error")
		assert_true(repair_prompt_sent.contains("unclosed_syntax_bracket"), "Repair prompt includes the failed code")
		assert_true(repair_prompt_sent.contains("UniCoreModule"), "Repair prompt reminds contract rules")

	# Verify memory was enriched
	var brain_mem = agent_brain.get_memory()
	assert_true(brain_mem != null, "AgentBrain has ConversationMemory")
	var mem_msgs = brain_mem.get_messages()
	assert_true(mem_msgs.size() >= 3, "Memory recorded user prompt, error, and assistant success")

	# --------------------------------------------------------------------------
	# Group 2: Self-Repair Loop Max Attempts Failure
	# --------------------------------------------------------------------------
	print("\n--- Group 2: Self-Repair Loop (Fails after MAX_REPAIR_ATTEMPTS) ---")
	completed_modules.clear()
	failed_errors.clear()
	mock_provider.history.clear()
	mock_provider.call_count = 0

	# 4 consecutive broken responses: 1 initial + 3 repair attempts (MAX_REPAIR_ATTEMPTS = 3)
	mock_provider.response_queue = [
		broken_syntax_code,
		broken_syntax_code,
		broken_syntax_code,
		broken_syntax_code
	]

	agent_brain.process_user_prompt("Сгенерируй тестовый компонент beta")

	assert_eq(mock_provider.call_count, 4, "LLM called 4 times (1 initial + 3 repair attempts)")
	assert_eq(completed_modules.size(), 0, "request_completed was NOT emitted")
	assert_eq(failed_errors.size(), 1, "request_failed emitted exactly once after max attempts reached")
	assert_true(failed_errors[0].contains("validation failed"), "Error message describes validation failure")
	assert_eq(agent_brain.get_repair_attempts(), 0, "Repair attempts reset to 0 after failure")

	# --------------------------------------------------------------------------
	# Group 3: RegEx Recognition for Russian & English Edit Commands
	# --------------------------------------------------------------------------
	print("\n--- Group 3: RegEx Recognition for Edit Mode Commands ---")

	var ru_test_cases := [
		{"input": "измени модуль cube_tool: сделай кубы зелеными", "expected_target": "cube_tool", "expected_inst": "сделай кубы зелеными"},
		{"input": "обнови cube_tool чтобы цвет стал синим", "expected_target": "cube_tool", "expected_inst": "цвет стал синим"},
		{"input": "поправь генератор кубов сделай кубы больше", "expected_target": "генератор кубов", "expected_inst": "кубы больше"},
		{"input": "модифицируй модуль light_rig - уменьши яркость света", "expected_target": "light_rig", "expected_inst": "уменьши яркость света"},
		{"input": "переделай avatar_cam: добавь вид от третьего лица", "expected_target": "avatar_cam", "expected_inst": "добавь вид от третьего лица"},
		{"input": "отредактируй spawner_3d сделай спавн при нажатии F", "expected_target": "spawner_3d", "expected_inst": "спавн при нажатии F"}
	]

	for tc in ru_test_cases:
		var cmd := agent_brain._check_edit_command(tc["input"])
		assert_true(cmd["is_edit"], "RU edit command recognized: '%s'" % tc["input"])
		assert_eq(cmd["target"], tc["expected_target"], "Target matched for '%s'" % tc["input"])
		assert_eq(cmd["instruction"], tc["expected_inst"], "Instruction matched for '%s'" % tc["input"])

	var en_test_cases := [
		{"input": "edit module cube_tool: make cubes blue", "expected_target": "cube_tool", "expected_inst": "make cubes blue"},
		{"input": "update cube_tool to spawn spheres instead", "expected_target": "cube_tool", "expected_inst": "spawn spheres instead"},
		{"input": "modify lighting_rig - change light color to neon pink", "expected_target": "lighting_rig", "expected_inst": "change light color to neon pink"},
		{"input": "change camera_tool: invert y axis", "expected_target": "camera_tool", "expected_inst": "invert y axis"},
		{"input": "patch module physics_box to add bouncy collision", "expected_target": "physics_box", "expected_inst": "add bouncy collision"}
	]

	for tc in en_test_cases:
		var cmd := agent_brain._check_edit_command(tc["input"])
		assert_true(cmd["is_edit"], "EN edit command recognized: '%s'" % tc["input"])
		assert_eq(cmd["target"], tc["expected_target"], "Target matched for '%s'" % tc["input"])
		assert_eq(cmd["instruction"], tc["expected_inst"], "Instruction matched for '%s'" % tc["input"])

	var non_edit_prompt := "создай красивую зеленую поляну с деревьями"
	var non_cmd := agent_brain._check_edit_command(non_edit_prompt)
	assert_false(non_cmd["is_edit"], "Normal creation prompt is not flagged as edit mode")

	# --------------------------------------------------------------------------
	# Group 4: Full Module Edit Mode & Hot-Reload Execution
	# --------------------------------------------------------------------------
	print("\n--- Group 4: Module Edit Mode & Hot Reloading ---")
	completed_modules.clear()
	failed_errors.clear()
	mock_provider.history.clear()
	mock_provider.call_count = 0

	# 1. Mount initial module into ModuleManager and register source
	var original_module_code := """extends UniCoreModule

func get_module_id() -> String:
	return "custom_spawner_tool"

func get_module_name() -> String:
	return "Кастомный Спавнер"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	return true

func cleanup() -> void:
	super.cleanup()
"""
	var original_instance = module_manager.load_module_from_source("custom_spawner_tool", original_module_code)
	assert_true(original_instance != null, "Original module loaded into ModuleManager")
	assert_eq(original_instance.get_module_name(), "Кастомный Спавнер", "Original module name verified")
	agent_brain.register_module_source("custom_spawner_tool", original_module_code)
	agent_brain._save_module_to_disk("custom_spawner_tool", original_module_code)

	# 2. Prepare edited module code
	var updated_module_code := """extends UniCoreModule

func get_module_id() -> String:
	return "custom_spawner_tool"

func get_module_name() -> String:
	return "Кастомный Спавнер (Модифицированный)"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	return true

func cleanup() -> void:
	super.cleanup()
"""
	mock_provider.response_queue = [updated_module_code]

	# 3. Trigger Russian edit command
	agent_brain.process_user_prompt("измени модуль custom_spawner_tool: сделай кубы зелеными")

	assert_eq(mock_provider.call_count, 1, "Provider called once for edit request")
	assert_eq(completed_modules.size(), 1, "request_completed emitted once for edited module")
	assert_eq(completed_modules[0], "custom_spawner_tool", "Module ID preserved across hot-reload")
	assert_eq(failed_errors.size(), 0, "No errors emitted during edit")

	# 4. Verify prompt sent to LLM contained original source code and instruction
	if mock_provider.history.size() > 0:
		var edit_history_item = mock_provider.history[mock_provider.history.size() - 1]
		var sent_user_prompt: String = edit_history_item["user"]
		assert_true(sent_user_prompt.contains("Режим редактирования модуля UniCORE"), "Edit mode preamble included")
		assert_true(sent_user_prompt.contains("custom_spawner_tool"), "Target module ID included")
		assert_true(sent_user_prompt.contains("Кастомный Спавнер"), "Original source code included in prompt")
		assert_true(sent_user_prompt.contains("сделай кубы зелеными"), "User instructions included in prompt")

	# 5. Verify hot swapped instance in ModuleManager
	var new_instance = module_manager.get_module("custom_spawner_tool")
	assert_true(new_instance != null, "Updated module exists in ModuleManager")
	assert_eq(new_instance.get_module_name(), "Кастомный Спавнер (Модифицированный)", "Updated module has new implementation")

	# 6. Test English edit command
	completed_modules.clear()
	mock_provider.response_queue = [updated_module_code]
	agent_brain.process_user_prompt("update custom_spawner_tool to spawn blue cubes")
	assert_eq(completed_modules.size(), 1, "English update command successfully executed")

	# 7. Test editing module by human-readable name
	completed_modules.clear()
	mock_provider.response_queue = [updated_module_code]
	agent_brain.process_user_prompt("поправь Кастомный Спавнер сделай больше объектов")
	assert_eq(completed_modules.size(), 1, "Editing by human-readable name matched active module successfully")

	# 8. Test edit request for non-existent module fails cleanly
	failed_errors.clear()
	agent_brain.process_user_prompt("измени модуль non_existent_thing: сделай что-нибудь")
	assert_eq(failed_errors.size(), 1, "Editing non-existent module failed gracefully")
	assert_true(failed_errors[0].contains("не найден"), "Error mentions module not found")

	# --------------------------------------------------------------------------
	# Group 5: SYSTEM_PROMPT Context Enrichment from Active Modules
	# --------------------------------------------------------------------------
	print("\n--- Group 5: Active Modules Context Enrichment ---")
	var active_context: String = brain_mem.get_active_modules_context(module_manager)
	assert_true(active_context.contains("Currently Active Modules in Scene:"), "Context header present")
	assert_true(active_context.contains("custom_spawner_tool"), "Active custom_spawner_tool listed in context")

	# --------------------------------------------------------------------------
	# Group 6: Robust Module ID Extraction & ModuleManager Runtime Recovery
	# --------------------------------------------------------------------------
	print("\n--- Group 6: Robust Module ID Extraction & ModuleManager Runtime Recovery ---")
	completed_modules.clear()
	failed_errors.clear()

	# Module code where get_module_id has comments and multiline body
	var formatted_id_code := """extends UniCoreModule

func get_module_id() -> String:
	# Unique tool identifier
	var computed_id := "commented_format_tool"
	return computed_id

func get_module_name() -> String:
	return "Инструмент с комментариями в ID"

func initialize(context: Dictionary) -> bool:
	super.initialize(context)
	return true

func cleanup() -> void:
	super.cleanup()
"""
	mock_provider.response_queue = [formatted_id_code]
	agent_brain.process_user_prompt("Создай пользовательский компонент gamma")
	assert_eq(completed_modules.size(), 1, "Completed successfully with formatted get_module_id")
	assert_eq(completed_modules[0], "commented_format_tool", "Module ID accurately extracted from runtime instance")
	assert_true(module_manager.get_module("commented_format_tool") != null, "Module registered in ModuleManager under exact ID")

	print("\n==================================================")
	print("Test Results: %d Passed, %d Failed" % [passed_count, failed_count])
	print("==================================================")

	# Clean up allocated test nodes and unregister modules
	agent_brain.free()
	module_manager.unload_all_modules()
	module_manager.free()
	world_root.free()
	logger.free()
	mock_provider.free()
	event_bus.free()

	# Clean up test artifacts written to disk
	var test_disk_artifacts := [
		"res://modules/repaired_alpha_tool.gd",
		"res://modules/custom_spawner_tool.gd",
		"res://modules/commented_format_tool.gd"
	]
	for artifact_path in test_disk_artifacts:
		if FileAccess.file_exists(artifact_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(artifact_path))

	if failed_count == 0:
		print("AUDIT SUCCESS: All Self-Repair & Edit Mode tests passed with 100% success.")
		quit(0)
	else:
		push_error("AUDIT FAILURE: %d tests failed." % failed_count)
		quit(1)
