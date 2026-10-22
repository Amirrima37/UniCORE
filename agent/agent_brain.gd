class_name AgentBrain
extends Node

## Мозг Агента (AgentBrain)
## Оркестрирует получение пользовательского запроса, формирование промпта,
## вызов LLM-провайдера, валидацию кода безопасности, цикл самовосстановления (Self-Repair Loop),
## режим редактирования модулей (Edit Mode) и инъекцию модуля в Ядро.

signal request_started(prompt: String)
signal request_completed(module_id: String)
signal request_failed(error_message: String)
signal diagnostic_emitted(diagnostic: Dictionary)

@export var api_key: String = ""

const ModuleRegistryClient = preload("res://core/module_registry_client.gd")
const ConversationMemory = preload("res://agent/conversation_memory.gd")

const MAX_REPAIR_ATTEMPTS: int = 3

var _provider: BaseLLMProvider
var _validator: CodeValidator
var _module_manager: ModuleManager
var _event_bus: EventBus
var _diagnostic_logger: DiagnosticLogger = null

var _memory: ConversationMemory
var _repair_attempts: int = 0
var _last_user_prompt: String = ""
var _last_failed_code: String = ""

# Edit Mode tracking
var _is_editing: bool = false
var _editing_module_id: String = ""
var _module_source_cache: Dictionary = {}

var _regex_edit_ru: RegEx
var _regex_edit_en: RegEx

const SYSTEM_PROMPT: String = """You are the embedded AI Agent for UniCORE (Universal Core).
Your role is to write clean, production-ready, self-contained Godot 4 GDScript modules.

Module Rules & Contract:
1. ALWAYS extend `UniCoreModule` (or `Node3D`/`Node` implementing the contract).
2. Implement:
   - `get_module_id() -> String` (returns a unique, descriptive snake_case ID like 'cube_spawner_tool', 'speed_modifier', 'floating_sphere')
   - `get_module_name() -> String` (human-readable title in Russian/English, e.g. 'Генератор кубов')
   - `initialize(context: Dictionary) -> bool` (context contains 'world_root', 'event_bus', 'module_manager')
   - `cleanup() -> void` (removes all spawned objects, frees resources, and calls queue_free())
3. INTERACTION & SPAWNING:
   - If the user asks for objects (cubes, spheres, terrain, structures), SPAWN THEM IMMEDIATELY in initialize() or on input!
   - For visual meshes in Godot 4:
     var mi = MeshInstance3D.new()
     var box = BoxMesh.new()
     box.size = Vector3(1.5, 1.5, 1.5)
     mi.mesh = box
     var mat = StandardMaterial3D.new()
     mat.albedo_color = Color(1.0, 0.2, 0.2) # color requested
     mi.material_override = mat
     mi.position = Vector3(0, 1.0, -3.0) # In front of camera/origin
     add_child(mi)
   - If creating an interactive tool, listen to input events in `_unhandled_input(event)`:
     For example, left mouse click (MOUSE_BUTTON_LEFT) or key press (e.g. KEY_F, KEY_E, KEY_G) to spawn more objects or toggle behavior.
4. SAFETY: NEVER use OS.execute, OS.kill, OS.crash, or FileAccess writes outside 'user://'.
5. OUTPUT: Output ONLY the raw GDScript code. Do NOT enclose in markdown fences (```gdscript) or conversational text.
"""

func _init() -> void:
	_init_regexes()

func _ready() -> void:
	_init_regexes()
	if not _validator:
		_validator = CodeValidator.new()
	if not _memory:
		_memory = ConversationMemory.new()
		_memory.load_from_disk()

func setup(event_bus: EventBus, module_manager: ModuleManager, llm_provider: BaseLLMProvider, diagnostic_logger: DiagnosticLogger = null) -> void:
	_init_regexes()
	_event_bus = event_bus
	_module_manager = module_manager
	_provider = llm_provider
	_diagnostic_logger = diagnostic_logger
	_validator = CodeValidator.new()

	if not _memory:
		_memory = ConversationMemory.new()
		_memory.load_from_disk()

	if _provider:
		if not _provider.response_received.is_connected(_on_llm_response):
			_provider.response_received.connect(_on_llm_response)
		if not _provider.request_failed.is_connected(_on_llm_failure):
			_provider.request_failed.connect(_on_llm_failure)

func _init_regexes() -> void:
	if not _regex_edit_ru:
		_regex_edit_ru = RegEx.new()
		_regex_edit_ru.compile("(?i)(?:[иИ]змени|[оО]бнови|[мМ]одифицируй|[оО]тредактируй|[пП]еределай|[пП]оправь)\\s+(?:модуль\\s+)?([a-zA-Z0-9_]+|[а-яА-ЯёЁ\\s]+?)(?:\\s*[:,\\-—]\\s*|\\s+чтобы\\s+|\\s+сделай\\s+)(.+)")
	if not _regex_edit_en:
		_regex_edit_en = RegEx.new()
		_regex_edit_en.compile("(?i)(?:edit|update|modify|change|patch)\\s+(?:module\\s+)?([a-zA-Z0-9_]+)(?:\\s*[:,\\-]\\s*|\\s+to\\s+)(.+)")

func register_module_source(mod_id: String, source_code: String) -> void:
	_module_source_cache[mod_id] = source_code

func get_memory() -> ConversationMemory:
	return _memory

func get_repair_attempts() -> int:
	return _repair_attempts

func is_editing() -> bool:
	return _is_editing

func get_diagnostic_logger() -> DiagnosticLogger:
	return _diagnostic_logger

func set_diagnostic_logger(logger: DiagnosticLogger) -> void:
	_diagnostic_logger = logger

## Формирует системный промпт, обогащенный контекстом активных модулей из ConversationMemory
func _get_enriched_system_prompt() -> String:
	var enriched := SYSTEM_PROMPT
	if _memory and _module_manager:
		var mod_context := _memory.get_active_modules_context(_module_manager)
		if not mod_context.is_empty():
			enriched += "\n\n" + mod_context
	return enriched

## Главная точка входа запроса от пользователя
func process_user_prompt(user_text: String) -> void:
	var trimmed = user_text.strip_edges()
	if trimmed.is_empty():
		return

	_repair_attempts = 0
	_last_failed_code = ""
	_last_user_prompt = trimmed
	_is_editing = false
	_editing_module_id = ""

	if _memory:
		_memory.add_user_message(trimmed)

	print("[UniCORE Agent] Processing prompt: '%s'" % trimmed)
	var start_diag := AgentDiagnostic.from_request(trimmed)
	_log_and_emit_diagnostic(start_diag)
	request_started.emit(trimmed)

	# 1. Распознавание команд режима редактирования (Edit Mode)
	var edit_cmd := _check_edit_command(trimmed)
	if edit_cmd["is_edit"]:
		var target_spec: String = edit_cmd["target"]
		var instruction: String = edit_cmd["instruction"]
		var target_mod_id := _find_module_id(target_spec)
		if target_mod_id.is_empty():
			_fail_with_error("Модуль '%s' для редактирования не найден среди активных модулей." % target_spec)
			return

		var current_source := _get_module_source(target_mod_id)
		if current_source.is_empty():
			_fail_with_error("Исходный код модуля '%s' недоступен для редактирования." % target_mod_id)
			return

		_is_editing = true
		_editing_module_id = target_mod_id
		print("[UniCORE Agent] Edit Mode activated for module '%s'" % target_mod_id)

		if not _provider:
			_fail_with_error("LLM Provider is not configured")
			return

		if not _prepare_api_key():
			return

		var edit_prompt := """Режим редактирования модуля UniCORE.
ID модуля: %s
Текущий исходный код модуля:
%s

Инструкция пользователя по изменению:
%s

Требования:
1. Сохраняй контракт UniCoreModule (get_module_id, get_module_name, initialize, cleanup).
2. Метод get_module_id() должен возвращать '%s'.
3. Примени все изменения согласно инструкции пользователя.
4. Выдай ТОЛЬКО чистый исправленный GDScript код без пояснений и без markdown-разметки.
""" % [target_mod_id, current_source, instruction, target_mod_id]

		var sys_prompt := _get_enriched_system_prompt()
		_provider.send_prompt(sys_prompt, edit_prompt, api_key)
		return

	# 2. Быстрый поиск в реестре готовых проверенных модулей и библиотек (Registry Cache)
	var template = ModuleRegistryClient.fuzzy_search(trimmed, 0.6)
	if not template.is_empty():
		var cached_code: String = ModuleRegistryClient.get_module_source(template)
		if not cached_code.is_empty():
			print("[UniCORE Agent] Matched pre-verified module '%s' from ModuleRegistry. Loading instantly..." % template["id"])
			_on_llm_response(cached_code)
			return

	if not _provider:
		_fail_with_error("LLM Provider is not configured")
		return

	if not _prepare_api_key():
		return

	print("[UniCORE Agent] Sending prompt to LLM provider...")
	var enriched_sys_prompt := _get_enriched_system_prompt()
	_provider.send_prompt(enriched_sys_prompt, trimmed, api_key)

func _prepare_api_key() -> bool:
	if api_key.is_empty():
		var candidates = ["OPENROUTER_API_KEY", "OPENAI_API_KEY", "DEEPSEEK_API_KEY", "GEMINI_API_KEY"]
		for env_var in candidates:
			var val = OS.get_environment(env_var)
			if not val.is_empty():
				api_key = val
				print("[UniCORE Agent] Using API key from $%s" % env_var)
				break

		if api_key.is_empty():
			var p_path := ""
			if _provider and _provider.get_script():
				p_path = _provider.get_script().resource_path.to_lower()
			if not "mock" in p_path:
				_fail_with_error("API Key is missing. Set OPENROUTER_API_KEY, OPENAI_API_KEY, or GEMINI_API_KEY.")
				return false
	return true

func _check_edit_command(prompt: String) -> Dictionary:
	_init_regexes()
	var m_ru = _regex_edit_ru.search(prompt)
	if m_ru:
		return {
			"is_edit": true,
			"target": m_ru.get_string(1).strip_edges(),
			"instruction": m_ru.get_string(2).strip_edges()
		}

	var m_en = _regex_edit_en.search(prompt)
	if m_en:
		return {
			"is_edit": true,
			"target": m_en.get_string(1).strip_edges(),
			"instruction": m_en.get_string(2).strip_edges()
		}

	return {"is_edit": false}

func _find_module_id(target: String) -> String:
	if not _module_manager:
		return ""

	var active_ids := _module_manager.get_active_module_ids()

	# 1. Точное совпадение по ID
	for id in active_ids:
		if str(id) == target:
			return str(id)

	# 2. Регистронезависимое совпадение по ID
	for id in active_ids:
		if str(id).to_lower() == target.to_lower():
			return str(id)

	# 3. Совпадение по имени модуля get_module_name()
	for id in active_ids:
		var inst = _module_manager.get_module(id)
		if inst and is_instance_valid(inst) and inst.has_method("get_module_name"):
			var mod_name := str(inst.get_module_name()).strip_edges()
			if mod_name.to_lower() == target.to_lower():
				return str(id)

	# 4. Частичное совпадение по имени модуля
	for id in active_ids:
		var inst = _module_manager.get_module(id)
		if inst and is_instance_valid(inst) and inst.has_method("get_module_name"):
			var mod_name := str(inst.get_module_name()).strip_edges()
			if target.to_lower() in mod_name.to_lower() or mod_name.to_lower() in target.to_lower():
				return str(id)

	# 5. Частичное совпадение по ID
	for id in active_ids:
		if target.to_lower() in str(id).to_lower() or str(id).to_lower() in target.to_lower():
			return str(id)

	# 6. Проверка наличия файла на диске
	if FileAccess.file_exists("res://modules/%s.gd" % target):
		return target

	return ""

func _get_module_source(mod_id: String) -> String:
	# 1. Из кэша исходного кода
	if _module_source_cache.has(mod_id) and not _module_source_cache[mod_id].is_empty():
		return _module_source_cache[mod_id]

	# 2. Из загруженного скрипта активного модуля
	if _module_manager:
		var inst = _module_manager.get_module(mod_id)
		if inst and is_instance_valid(inst):
			var scr = inst.get_script()
			if scr is Script and not scr.source_code.is_empty():
				return scr.source_code

	# 3. Из res://modules/{id}.gd
	var path_res := "res://modules/%s.gd" % mod_id
	if FileAccess.file_exists(path_res):
		var f := FileAccess.open(path_res, FileAccess.READ)
		if f:
			var code := f.get_as_text()
			f.close()
			if not code.is_empty():
				return code

	# 4. Из res://modules/builtin/{id}.gd
	var clean_id := mod_id.trim_prefix("builtin_")
	var path_builtin := "res://modules/builtin/%s.gd" % clean_id
	if FileAccess.file_exists(path_builtin):
		var fb := FileAccess.open(path_builtin, FileAccess.READ)
		if fb:
			var code := fb.get_as_text()
			fb.close()
			if not code.is_empty():
				return code

	# 5. Из шаблонов реестра
	var template = ModuleRegistryClient.search_template(mod_id)
	if not template.is_empty():
		var reg_code := ModuleRegistryClient.get_module_source(template)
		if not reg_code.is_empty():
			return reg_code

	return ""

func _on_llm_response(generated_code: String) -> void:
	print("[UniCORE Agent] Received response from LLM (%d chars). Validating..." % generated_code.length())

	# 1. Валидация безопасности и синтаксиса
	var validation = _validator.validate_module_code(generated_code)
	if not validation["is_valid"]:
		var err_msg = "Security/Syntax validation failed: %s" % validation["error"]
		_handle_repair_or_fail(err_msg, generated_code)
		return

	# 2. Определение ID модуля (из кода, режима редактирования или временной отметки)
	var module_id := "user_module_%d" % Time.get_unix_time_from_system()

	# Проверяем, есть ли в коде get_module_id() -> String
	var id_regex := RegEx.new()
	id_regex.compile("func\\s+get_module_id\\s*\\(\\s*\\)[^:]*:\\s*(?:return\\s+)?[\"']([a-zA-Z0-9_]+)[\"']")
	var id_match := id_regex.search(generated_code)
	if id_match and not id_match.get_string(1).is_empty() and id_match.get_string(1) != "base_module":
		module_id = id_match.get_string(1)

	# Надежное определение get_module_id через инстанциацию проверенного скрипта
	var temp_script := GDScript.new()
	temp_script.source_code = generated_code
	if temp_script.reload() == OK:
		var temp_inst = temp_script.new()
		if temp_inst and temp_inst.has_method("get_module_id"):
			var real_id = temp_inst.get_module_id()
			if real_id is String and not real_id.is_empty() and real_id != "base_module":
				module_id = real_id
		if temp_inst and not (temp_inst is RefCounted):
			temp_inst.free()

	var target_unload_id := ""
	if _is_editing and not _editing_module_id.is_empty():
		target_unload_id = _editing_module_id
		if module_id.begins_with("user_module_"):
			module_id = _editing_module_id

	# Горячая замена: выгружаем старую версию модуля перед загрузкой новой
	if not target_unload_id.is_empty() and _module_manager:
		print("[UniCORE Agent] Hot-replacement: Unloading existing module '%s'..." % target_unload_id)
		_module_manager.unload_module(target_unload_id)

	# 3. Инъекция в рантайм через ModuleManager
	print("[UniCORE Agent] Injecting module '%s' into ModuleManager..." % module_id)
	var instance = _module_manager.load_module_from_source(module_id, generated_code)
	if not instance:
		var err_msg := "ModuleManager failed to compile or instantiate module '%s'" % module_id
		_handle_repair_or_fail(err_msg, generated_code)
		return

	if instance.has_method("get_module_id"):
		var real_id = instance.get_module_id()
		if real_id is String and not real_id.is_empty() and real_id != "base_module":
			module_id = real_id

	print("[UniCORE Agent] Module '%s' successfully loaded and mounted!" % module_id)

	# 4. Сохраняем модуль на диск и в кэш
	_module_source_cache[module_id] = generated_code
	_save_module_to_disk(module_id, generated_code)

	# 5. Обновляем память диалога
	if _memory:
		_memory.add_assistant_response(generated_code, module_id)
		_memory.save_to_disk()

	# 6. Сброс состояния восстановления и редактирования
	_repair_attempts = 0
	_is_editing = false
	_editing_module_id = ""

	var success_diag := AgentDiagnostic.from_success(module_id)
	_log_and_emit_diagnostic(success_diag)
	request_completed.emit(module_id)

## Обработка сбоя валидации или компиляции с запуском цикла Self-Repair
func _handle_repair_or_fail(err_msg: String, failed_code: String) -> void:
	# Если провайдер настроен на игнорирование отправки (например в юнит-тестах логгера), немедленно завершаем
	if _provider and _provider.get("ignore_send") == true:
		_fail_with_error(err_msg)
		return

	if _repair_attempts < MAX_REPAIR_ATTEMPTS:
		_repair_attempts += 1
		_last_failed_code = failed_code
		if _memory:
			_memory.add_error_context(err_msg, _last_failed_code)

		var logger := _diagnostic_logger if _diagnostic_logger else DiagnosticLogger.get_instance()
		if logger:
			logger.log_agent("WARN", "[Self-Repair] Попытка %d/%d" % [_repair_attempts, MAX_REPAIR_ATTEMPTS], "Исправление ошибки: %s" % err_msg)

		var repair_diag := {
			"category": "AGENT",
			"level": "WARN",
			"title": "[Self-Repair] Попытка %d/%d" % [_repair_attempts, MAX_REPAIR_ATTEMPTS],
			"message": "Исправление ошибки: %s" % err_msg,
			"details": failed_code,
			"timestamp": Time.get_unix_time_from_system()
		}
		diagnostic_emitted.emit(repair_diag)

		print("[UniCORE Agent] Self-Repair attempt %d/%d triggered for error: %s" % [_repair_attempts, MAX_REPAIR_ATTEMPTS, err_msg])
		var repair_prompt := "Предыдущий сгенерированный код вызвал ошибку: %s.\n\nИсходный код с ошибкой:\n%s\n\nИсправь код полностью. Соблюдай контракт UniCoreModule (get_module_id, get_module_name, initialize, cleanup). Выдай ТОЛЬКО чистый исправленный GDScript код." % [err_msg, _last_failed_code]

		var sys_prompt := _get_enriched_system_prompt()
		if _provider:
			_provider.send_prompt(sys_prompt, repair_prompt, api_key)
		else:
			_fail_with_error("LLM Provider is not configured")
	else:
		_repair_attempts = 0
		_fail_with_error(err_msg)

func _on_llm_failure(error_message: String) -> void:
	_fail_with_error(error_message)

func _fail_with_error(error_message: String) -> void:
	_repair_attempts = 0
	_is_editing = false
	_editing_module_id = ""
	push_error("[UniCORE Agent] %s" % error_message)
	var diag := AgentDiagnostic.from_error(error_message)
	_log_and_emit_diagnostic(diag)
	request_failed.emit(error_message)

func _log_and_emit_diagnostic(diag: Dictionary) -> void:
	if _diagnostic_logger:
		_diagnostic_logger.log_diagnostic(diag)
	else:
		var global_logger := DiagnosticLogger.get_instance()
		if global_logger:
			global_logger.log_diagnostic(diag)
	diagnostic_emitted.emit(diag)

## Сохраняет исходный код модуля на диск в папку modules/
func _save_module_to_disk(module_id: String, source_code: String) -> void:
	# 1. Попытка сохранить в проектную папку res://modules
	var saved_res := false
	var project_path := ProjectSettings.globalize_path("res://modules")
	var dir_res := DirAccess.open("res://")
	if dir_res:
		if not dir_res.dir_exists("modules"):
			dir_res.make_dir("modules")
		var file_path_res := "res://modules/%s.gd" % module_id
		var file := FileAccess.open(file_path_res, FileAccess.WRITE)
		if file:
			file.store_string(source_code)
			file.close()
			saved_res = true
			print("[UniCORE Agent] Module successfully saved to disk: %s (Path: %s/%s.gd)" % [file_path_res, project_path, module_id])
		else:
			print("[UniCORE Agent] Notice: res:// write error: %d, falling back to OS path" % FileAccess.get_open_error())

	# 2. Если res:// недоступен на запись в скомпилированном бинарнике, сохраняем в абсолютный путь папки проекта или user://
	if not saved_res:
		var os_dir := DirAccess.open(project_path)
		if not os_dir:
			DirAccess.make_dir_absolute(project_path)
		var abs_file_path := "%s/%s.gd" % [project_path, module_id]
		var file_abs := FileAccess.open(abs_file_path, FileAccess.WRITE)
		if file_abs:
			file_abs.store_string(source_code)
			file_abs.close()
			print("[UniCORE Agent] Module saved to disk at: %s" % abs_file_path)
		else:
			push_warning("[UniCORE Agent] Could not save module to %s (error: %d)" % [abs_file_path, FileAccess.get_open_error()])
