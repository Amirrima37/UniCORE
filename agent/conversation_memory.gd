class_name ConversationMemory
extends RefCounted

## Контекстная Память Диалога и Скользящее Окно (Conversation Memory & Context Window)
## Хранит историю сообщений, управляет скользящим окном контекста (max_messages),
## сжимает ранний контекст диалога в сводное системное сообщение, сериализует историю
## на диск (user://conversation_history.json) и формирует контекст активных модулей.

const DEFAULT_STORAGE_PATH: String = "user://conversation_history.json"
const DEFAULT_MAX_MESSAGES: int = 20

var max_messages: int = DEFAULT_MAX_MESSAGES
var auto_summarize: bool = false
var messages: Array[Dictionary] = []

func _init(p_max_messages: int = DEFAULT_MAX_MESSAGES) -> void:
	max_messages = maxi(1, p_max_messages)
	messages = []

## Добавление сообщения пользователя
## Возвращает созданный словарь сообщения {"role": "user", "content": ..., "timestamp": ..., "metadata": ...}
func add_user_message(text: String, metadata: Dictionary = {}) -> Dictionary:
	var msg: Dictionary = {
		"role": "user",
		"content": text,
		"timestamp": Time.get_unix_time_from_system(),
		"metadata": metadata.duplicate(true)
	}
	messages.append(msg)
	if auto_summarize:
		summarize_if_needed()
	return msg

## Добавление ответа ассистента со сгенерированным кодом и ID модуля
## Возвращает созданный словарь сообщения {"role": "assistant", "content": ..., "timestamp": ..., "metadata": ...}
func add_assistant_response(code: String, module_id: String = "", metadata: Dictionary = {}) -> Dictionary:
	var meta := metadata.duplicate(true)
	if not module_id.is_empty() or not meta.has("module_id"):
		meta["module_id"] = module_id
	var msg: Dictionary = {
		"role": "assistant",
		"content": code,
		"timestamp": Time.get_unix_time_from_system(),
		"metadata": meta
	}
	messages.append(msg)
	if auto_summarize:
		summarize_if_needed()
	return msg

## Добавление контекста ошибки при неудачной валидации или компиляции (для self-repair)
## Возвращает созданный словарь сообщения
func add_error_context(error: String, failed_code: String, role: String = "user", metadata: Dictionary = {}) -> Dictionary:
	var valid_role := role.to_lower()
	if not (valid_role in ["user", "assistant", "system"]):
		valid_role = "user"

	var meta := metadata.duplicate(true)
	meta["error"] = error
	meta["failed_code"] = failed_code
	meta["is_error"] = true
	var content_str: String = "Error during module validation/execution:\n%s\n\nFailed code:\n%s" % [error, failed_code]
	var msg: Dictionary = {
		"role": valid_role,
		"content": content_str,
		"timestamp": Time.get_unix_time_from_system(),
		"metadata": meta
	}
	messages.append(msg)
	if auto_summarize:
		summarize_if_needed()
	return msg

## Получение массива сообщений скользящего окна для отправки LLM
## Длина массива не превышает max_messages. Если в начале присутствует системная сводка,
## она сохраняется на первой позиции, а остальные элементы берутся из самых свежих сообщений.
func get_context_messages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if max_messages <= 0 or messages.is_empty():
		return result

	if messages.size() <= max_messages:
		for msg in messages:
			result.append(msg.duplicate(true))
		return result

	# Если первое сообщение — системная сводка раннего контекста, обязательно сохраняем его на позиции 0
	if messages[0].get("role") == "system":
		result.append(messages[0].duplicate(true))
		var recent_count := max_messages - 1
		var start_idx := messages.size() - recent_count
		for i in range(start_idx, messages.size()):
			result.append(messages[i].duplicate(true))
	else:
		var start_idx := messages.size() - max_messages
		for i in range(start_idx, messages.size()):
			result.append(messages[i].duplicate(true))

	return result

## Сжатие ранней истории: если сообщений > max_messages, берет ранние сообщения
## (кроме последних 10), сжимает их в краткую текстовую сводку и заменяет их
## одним сводным системным сообщением {"role": "system", "content": "Сводка раннего контекста диалога: ...", "timestamp": ...} в начале массива.
func summarize_if_needed() -> void:
	if messages.size() <= max_messages:
		return

	# Для max_messages > 10 сохраняем ровно 10 последних сообщений (1 сводка + 10 = 11 <= max_messages)
	# Для max_messages <= 10 сохраняем max_messages - 1 последних сообщений (1 сводка + keep_recent <= max_messages)
	var keep_recent: int = mini(10, maxi(0, max_messages - 1))
	var split_idx := messages.size() - keep_recent
	if split_idx <= 0:
		return

	var early_messages := messages.slice(0, split_idx)
	var recent_messages := messages.slice(split_idx)

	var summary_lines: PackedStringArray = []
	summary_lines.append("Сводка раннего контекста диалога:")
	for msg in early_messages:
		var role: String = msg.get("role", "")
		var content: String = str(msg.get("content", ""))
		var meta: Dictionary = msg.get("metadata", {})

		# 1. Ошибки и контекст самовосстановления (проверяем в первую очередь, даже если role == "user")
		if meta.get("is_error", false) or meta.has("error"):
			var err_text: String = str(meta.get("error", "")).strip_edges()
			if err_text.is_empty():
				err_text = content.strip_edges()
			if err_text.length() > 80:
				err_text = err_text.substr(0, 77) + "..."
			summary_lines.append("- Ошибка/Самовосстановление: " + err_text)
		# 2. Системные сводки предыдущих циклов компрессии
		elif role == "system":
			var cleaned := content.replace("Сводка раннего контекста диалога:", "").strip_edges()
			if not cleaned.is_empty():
				for line in cleaned.split("\n"):
					var trimmed_line := line.strip_edges()
					if not trimmed_line.is_empty():
						summary_lines.append(trimmed_line)
		# 3. Ответы ассистента со сгенерированными модулями
		elif role == "assistant":
			var mod_id: String = meta.get("module_id", "")
			if not mod_id.is_empty():
				summary_lines.append("- Ассистент: сгенерирован модуль '%s'" % mod_id)
			else:
				var text := content.strip_edges()
				if text.length() > 80:
					text = text.substr(0, 77) + "..."
				summary_lines.append("- Ответ ассистента: " + text)
		# 4. Запросы пользователя
		elif role == "user":
			var text := content.strip_edges()
			if text.length() > 80:
				text = text.substr(0, 77) + "..."
			summary_lines.append("- Запрос пользователя: " + text)
		else:
			var text := content.strip_edges()
			if text.length() > 80:
				text = text.substr(0, 77) + "..."
			summary_lines.append("- %s: %s" % [role, text])

	var summary_content: String = "\n".join(summary_lines)
	var summary_msg: Dictionary = {
		"role": "system",
		"content": summary_content,
		"timestamp": Time.get_unix_time_from_system(),
		"metadata": {
			"is_summary": true,
			"compressed_count": early_messages.size()
		}
	}

	var new_messages: Array[Dictionary] = [summary_msg]
	for msg in recent_messages:
		new_messages.append(msg)
	messages = new_messages

## Сохранение истории сообщений на диск в формате JSON
func save_to_disk(path: String = DEFAULT_STORAGE_PATH) -> bool:
	var dir_path := path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_warning("[ConversationMemory] Failed to open %s for write (error: %d)" % [path, FileAccess.get_open_error()])
		return false

	var data: Dictionary = {
		"version": 1,
		"max_messages": max_messages,
		"updated_at": Time.get_unix_time_from_system(),
		"messages": messages
	}
	var json_str := JSON.stringify(data, "\t")
	file.store_string(json_str)
	file.close()
	return true

## Загрузка истории сообщений с диска
func load_from_disk(path: String = DEFAULT_STORAGE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[ConversationMemory] Failed to open %s for read (error: %d)" % [path, FileAccess.get_open_error()])
		return false

	var content := file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		return false

	var json := JSON.new()
	var err := json.parse(content)
	if err != OK:
		push_warning("[ConversationMemory] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return false

	var data = json.data
	var loaded_messages: Array[Dictionary] = []

	if data is Dictionary:
		if data.has("max_messages") and (data["max_messages"] is int or data["max_messages"] is float):
			var parsed_max := int(data["max_messages"])
			if parsed_max > 0:
				max_messages = parsed_max
		if data.has("messages") and data["messages"] is Array:
			for item in data["messages"]:
				if item is Dictionary:
					var dict_item: Dictionary = item.duplicate(true)
					_normalize_message(dict_item)
					loaded_messages.append(dict_item)
		else:
			return false
	elif data is Array:
		for item in data:
			if item is Dictionary:
				var dict_item: Dictionary = item.duplicate(true)
				_normalize_message(dict_item)
				loaded_messages.append(dict_item)
	else:
		return false

	messages = loaded_messages
	return true

## Очищает массив сообщений и удаляет файл user://conversation_history.json
func clear(path: String = DEFAULT_STORAGE_PATH) -> void:
	messages.clear()
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err != OK and path.begins_with("user://"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## Возвращает форматированную строку описания загруженных модулей в пространстве для системного промпта
func get_active_modules_context(module_manager = null) -> String:
	if module_manager == null:
		return "Currently Active Modules in Scene: None."

	var active_ids: Array = []
	if module_manager is Dictionary:
		active_ids = module_manager.keys()
	elif module_manager is Array:
		active_ids = module_manager
	elif module_manager is Object and module_manager.has_method("get_active_module_ids"):
		active_ids = module_manager.get_active_module_ids()
	else:
		return "Currently Active Modules in Scene: None."

	if active_ids.is_empty():
		return "Currently Active Modules in Scene: None."

	var lines: PackedStringArray = ["Currently Active Modules in Scene:"]
	for mod_id in active_ids:
		var inst = null
		if module_manager is Dictionary:
			inst = module_manager.get(mod_id, null)
		elif module_manager is Object and module_manager.has_method("get_module"):
			inst = module_manager.get_module(mod_id)

		var mod_name := str(mod_id)
		if inst != null and is_instance_valid(inst) and inst.has_method("get_module_name"):
			var n = inst.get_module_name()
			if n is String and not n.is_empty():
				mod_name = n
		lines.append("- [%s] %s" % [mod_id, mod_name])

	return "\n".join(lines)

## Вспомогательные методы
func get_messages() -> Array[Dictionary]:
	return messages.duplicate(true)

func get_last_user_message() -> String:
	for i in range(messages.size() - 1, -1, -1):
		var msg = messages[i]
		if msg.get("role") == "user" and not msg.get("metadata", {}).get("is_error", false):
			return msg.get("content", "")
	return ""

func get_message_count() -> int:
	return messages.size()

func is_empty() -> bool:
	return messages.is_empty()

func _normalize_message(msg: Dictionary) -> void:
	var role = str(msg.get("role", "user")).to_lower()
	if role == "human":
		role = "user"
	elif role in ["bot", "ai", "model"]:
		role = "assistant"
	elif not (role in ["user", "assistant", "system"]):
		role = "user"
	msg["role"] = role

	msg["content"] = str(msg.get("content", ""))

	var ts = msg.get("timestamp", null)
	if ts is float or ts is int:
		msg["timestamp"] = float(ts)
	else:
		msg["timestamp"] = Time.get_unix_time_from_system()

	var meta = msg.get("metadata", null)
	if meta is Dictionary:
		msg["metadata"] = meta.duplicate(true)
	else:
		msg["metadata"] = {}

	if msg.has("module_id") and not msg["metadata"].has("module_id"):
		msg["metadata"]["module_id"] = str(msg["module_id"])
	if msg.has("error") and not msg["metadata"].has("error"):
		msg["metadata"]["error"] = str(msg["error"])
	if msg.has("failed_code") and not msg["metadata"].has("failed_code"):
		msg["metadata"]["failed_code"] = str(msg["failed_code"])
